import cv2
import logging
import os
import time
import threading
import numpy as np
import mediapipe as mp

from backend.faceid import FaceID
from backend.src.drowsy.engine import DrowsinessEngine
from backend.src.drowsy.metrics import eye_aspect_ratio, mouth_aspect_ratio
from backend.src.config import CameraConfig
from backend.engine.mood import MoodConfig, MoodTracker

logger = logging.getLogger(__name__)
DEBUG_CAMERA_STREAM = os.getenv("BACKEND_DEBUG_CAMERA", "").lower() in {
    "1",
    "true",
    "yes",
    "on",
}


def log_debug(message, *args):
    if DEBUG_CAMERA_STREAM:
        logger.info(message, *args)


# =========================================================
# GLOBAL OBJECTS
# =========================================================
camera = None
last_frame = None
frame_lock = threading.Lock()

recognizer = None
drowsy_engine = None
face_mesh = None
mood_tracker = MoodTracker()


# =========================================================
# GLOBAL STATES
# =========================================================
driver_status = {
    "driver": None,
    "recognized": False,
    "confidence": 0.0,
    "bbox": None,
}

drowsiness_status = {
    "active": False,
    "driver_name": None,
    "recognized_driver": None,
    "driver_match": False,
    "ear": None,
    "mar": None,
    "mood": "unknown",
    "mood_confidence": 0.0,
    "raw_mood": "unknown",
    "mood_candidate": "unknown",
    "mood_candidate_elapsed": 0.0,
    "mood_required_sec": 7.0,
    "smile_score": 0.0,
    "sadness_score": 0.0,
    "yawn_status": "NO",
    "yawn_total": 0,
    "yawns_in_window": 0,
    "eye_score": 0.0,
    "yawn_score": 0.0,
    "ear_ratio": None,
    "score": 0.0,
    "alert_active": False,
    "calibrating": False,
    "calib_remaining": 0.0,
    "status": "inactive",
    "face_position": "not_frontal",
}


# =========================================================
# DROWSINESS CONFIG
# =========================================================

class DrowsyConfig:
    calib_seconds = 5.0
    min_baseline = 0.15

    mar_threshold = 0.23
    consec_frames_yawn = 6
    yawn_cooldown_sec = 3.0
    yawn_window_sec = 20.0
    yawn_alert_count = 5

    use_score = True
    eye_low_ratio = 0.75
    eye_full_close_ratio = 0.55
    yawn_points_max = 1.0
    yawn_points_per_event = 0.35
    yawn_decay_per_sec = 0.02

    w_eye = 0.7
    w_yawn = 0.3
    score_alpha = 0.20
    score_alert_th = 0.65
    alert_hold_sec = 3.0


# =========================================================
# INIT FUNCTIONS
# =========================================================
def is_frontal_face(face_landmarks, yaw_threshold=0.06):
    left_eye = face_landmarks.landmark[33]
    right_eye = face_landmarks.landmark[263]
    nose_tip = face_landmarks.landmark[1]

    eye_center_x = (left_eye.x + right_eye.x) / 2.0
    yaw_offset = abs(nose_tip.x - eye_center_x)

    log_debug("[POSE] yaw_offset=%.4f, threshold=%.4f", yaw_offset, yaw_threshold)

    return yaw_offset < yaw_threshold


# def init_camera():
#     global camera

#     if camera is None:
#         cfg = CameraConfig()
#         camera = cv2.VideoCapture(cfg.index, cv2.CAP_DSHOW)
#         camera.set(cv2.CAP_PROP_FRAME_WIDTH, cfg.width)
#         camera.set(cv2.CAP_PROP_FRAME_HEIGHT, cfg.height)
#         camera.set(cv2.CAP_PROP_FPS, 30)

#         if not camera.isOpened():
#             raise RuntimeError("Cannot open webcam")

#         print("[INIT] Webcam opened successfully")


def init_camera():
    global camera

    if camera is None:
        cfg = CameraConfig()

        # coba beberapa cara buka kamera
        backends = [
            (cfg.index, None),
            (cfg.index, cv2.CAP_V4L2),
            ("/dev/video0", None),
            ("/dev/video1", None),
        ]

        for source, backend in backends:
            logger.info("[INIT] Trying camera: %s backend=%s", source, backend)

            if backend is None:
                cam = cv2.VideoCapture(source)
            else:
                cam = cv2.VideoCapture(source, backend)

            if cam.isOpened():
                camera = cam
                break

        if camera is None or not camera.isOpened():
            raise RuntimeError("Cannot open webcam")

        camera.set(cv2.CAP_PROP_FRAME_WIDTH, cfg.width)
        camera.set(cv2.CAP_PROP_FRAME_HEIGHT, cfg.height)
        camera.set(cv2.CAP_PROP_FPS, 30)

        logger.info("[INIT] Webcam opened successfully")

        
def init_recognizer():
    global recognizer

    if recognizer is None:
        recognizer = FaceID(
            conf_threshold=0.30,
            vote_window_sec=1.5,
            vote_min_ratio=0.60,
            vote_min_samples=6,
        )
        logger.info("[INIT] Recognizer initialized")


def init_drowsiness_engine():
    global drowsy_engine

    if drowsy_engine is None:
        drowsy_engine = DrowsinessEngine(DrowsyConfig())
        logger.info("[INIT] Drowsiness engine initialized")


def init_face_mesh():
    global face_mesh

    if face_mesh is None:
        face_mesh_module = mp.solutions.face_mesh

        face_mesh = face_mesh_module.FaceMesh(
            static_image_mode=False,
            max_num_faces=1,
            refine_landmarks=True,
            min_detection_confidence=0.5,
            min_tracking_confidence=0.5,
        )
        logger.info("[INIT] Face mesh initialized")


def reload_recognizer():
    global recognizer

    try:
        if recognizer is not None:
            recognizer.close()
    except Exception:
        pass

    recognizer = FaceID(
        conf_threshold=0.30,
        vote_window_sec=1.5,
        vote_min_ratio=0.60,
        vote_min_samples=6,
    )
    logger.info("[INIT] Recognizer reloaded")


# =========================================================
# RESET / START / STOP
# =========================================================
def reset_drowsiness_status(driver_name=None):
    global drowsiness_status

    is_active = driver_name is not None
    mood_tracker.reset()

    drowsiness_status = {
        "active": is_active,
        "driver_name": driver_name,
        "recognized_driver": None,
        "driver_match": False,
        "ear": None,
        "mar": None,
        "mood": "unknown",
        "mood_confidence": 0.0,
        "raw_mood": "unknown",
        "mood_candidate": "unknown",
        "mood_candidate_elapsed": 0.0,
        "mood_required_sec": MoodConfig.confirm_seconds,
        "smile_score": 0.0,
        "sadness_score": 0.0,
        "yawn_status": "NO",
        "yawn_total": 0,
        "yawns_in_window": 0,
        "eye_score": 0.0,
        "yawn_score": 0.0,
        "ear_ratio": None,
        "score": 0.0,
        "alert_active": False,
        "calibrating": is_active,
        "calib_remaining": 3.0 if is_active else 0.0,
        "status": "calibrating" if is_active else "inactive",
        "face_position": "not_frontal",
    }

    logger.info(
        "[RESET] active=%s driver=%s status=%s",
        drowsiness_status["active"],
        drowsiness_status["driver_name"],
        drowsiness_status["status"],
    )


def start_drowsiness_monitoring(driver_name: str):
    global drowsy_engine

    if not driver_name or not driver_name.strip():
        raise ValueError("driver_name is required")

    driver_name = driver_name.strip()

    init_drowsiness_engine()
    drowsy_engine.reset_all()
    reset_drowsiness_status(driver_name=driver_name)

    logger.info("[START_DROWSINESS] started for %s", driver_name)


def stop_drowsiness_monitoring():
    global drowsy_engine

    if drowsy_engine is not None:
        try:
            drowsy_engine.reset_all()
        except Exception:
            pass

    reset_drowsiness_status(driver_name=None)
    logger.info("[STOP_DROWSINESS] stopped")


def get_drowsiness_status():
    return dict(drowsiness_status)


def get_driver_status():
    return dict(driver_status)


# =========================================================
# DROWSINESS UPDATE
# =========================================================
def reset_mood_values():
    mood_tracker.reset()

    drowsiness_status["mood"] = "unknown"
    drowsiness_status["mood_confidence"] = 0.0
    drowsiness_status["raw_mood"] = "unknown"
    drowsiness_status["mood_candidate"] = "unknown"
    drowsiness_status["mood_candidate_elapsed"] = 0.0
    drowsiness_status["mood_required_sec"] = MoodConfig.confirm_seconds
    drowsiness_status["smile_score"] = 0.0
    drowsiness_status["sadness_score"] = 0.0


def reset_detection_values(status="waiting_driver"):
    drowsiness_status["ear"] = None
    drowsiness_status["mar"] = None
    reset_mood_values()
    drowsiness_status["eye_score"] = 0.0
    drowsiness_status["yawn_score"] = 0.0
    drowsiness_status["ear_ratio"] = None
    drowsiness_status["score"] = 0.0
    drowsiness_status["alert_active"] = False
    drowsiness_status["status"] = status


def update_driver_match_status():
    target_driver = drowsiness_status.get("driver_name")
    recognized_driver = driver_status.get("driver")

    driver_match = bool(
        drowsiness_status.get("active")
        and target_driver
        and recognized_driver
        and recognized_driver == target_driver
    )

    drowsiness_status["recognized_driver"] = recognized_driver
    drowsiness_status["driver_match"] = driver_match

    return driver_match


def update_drowsiness_from_metrics(ear, mar, now):
    global drowsiness_status

    if not drowsiness_status["active"]:
        log_debug("[DROWSY UPDATE] skipped because inactive")
        return

    if drowsy_engine is None:
        init_drowsiness_engine()

    log_debug(
        "[DROWSY INPUT] active=%s driver=%s ear=%s mar=%s",
        drowsiness_status["active"],
        drowsiness_status["driver_name"],
        ear,
        mar,
    )

    out = drowsy_engine.step(ear=ear, mar=mar, now=now)

    log_debug(
        "[DROWSY OUT] calibrating=%s calib_remaining=%.2f "
        "eye_score=%.3f yawn_score=%.3f score=%.3f alert=%s",
        out.calibrating,
        out.calib_remaining,
        out.eye_score,
        out.yawn_score,
        out.score,
        out.alert_active,
    )

    drowsiness_status["ear"] = None if out.ear is None else float(out.ear)
    drowsiness_status["mar"] = None if out.mar is None else float(out.mar)
    drowsiness_status["yawn_status"] = out.yawn_status
    drowsiness_status["yawn_total"] = int(out.yawn_total)
    drowsiness_status["yawns_in_window"] = int(out.yawns_in_window)
    drowsiness_status["eye_score"] = float(out.eye_score)
    drowsiness_status["yawn_score"] = float(out.yawn_score)
    drowsiness_status["ear_ratio"] = None if out.ear_ratio is None else float(out.ear_ratio)
    drowsiness_status["score"] = float(out.score)
    drowsiness_status["alert_active"] = bool(out.alert_active)
    drowsiness_status["calibrating"] = bool(out.calibrating)
    drowsiness_status["calib_remaining"] = float(out.calib_remaining)

    if out.calibrating:
        drowsiness_status["status"] = "calibrating"
    elif out.alert_active:
        drowsiness_status["status"] = "drowsy"
    else:
        drowsiness_status["status"] = "normal"

    log_debug("[DROWSY STATUS] %s", drowsiness_status)


def update_mood_from_landmarks(pts, now=None):
    if now is None:
        now = time.time()

    mood_out = mood_tracker.step(pts, now)
    drowsiness_status["mood"] = mood_out["mood"]
    drowsiness_status["mood_confidence"] = mood_out["mood_confidence"]
    drowsiness_status["raw_mood"] = mood_out["raw_mood"]
    drowsiness_status["mood_candidate"] = mood_out["mood_candidate"]
    drowsiness_status["mood_candidate_elapsed"] = mood_out["mood_candidate_elapsed"]
    drowsiness_status["mood_required_sec"] = mood_out["mood_required_sec"]
    drowsiness_status["smile_score"] = mood_out["smile_score"]
    drowsiness_status["sadness_score"] = mood_out["sadness_score"]

    log_debug(
        "[MOOD] raw=%s confirmed=%s elapsed=%.2f/%.2fs confidence=%.3f smile=%.3f sad=%.3f",
        mood_out["raw_mood"],
        drowsiness_status["mood"],
        mood_out["mood_candidate_elapsed"],
        mood_out["mood_required_sec"],
        mood_out["mood_confidence"],
        mood_out["smile_score"],
        mood_out["sadness_score"],
    )


# =========================================================
# EAR / MAR EXTRACTION
# =========================================================
def extract_ear_mar(frame):
    global face_mesh

    if face_mesh is None:
        init_face_mesh()

    h, w = frame.shape[:2]
    rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    result = face_mesh.process(rgb)

    if not result.multi_face_landmarks:
        log_debug("[EAR/MAR] no face landmarks")
        return None, None, None, False

    face_landmarks = result.multi_face_landmarks[0]

    # NEW: frontal face check
    frontal = is_frontal_face(face_landmarks, yaw_threshold=0.035)
    if not frontal:
        log_debug("[POSE] face not frontal -> skip EAR/MAR update")
        return None, None, None, False

    pts = []
    for lm in face_landmarks.landmark:
        pts.append([lm.x * w, lm.y * h])

    pts = np.array(pts, dtype=np.float32)

    left_eye_idx = [33, 160, 158, 133, 153, 144]
    right_eye_idx = [362, 385, 387, 263, 373, 380]
    mouth_idx = [61, 13, 14, 291, 17, 0]

    try:
        left_eye = pts[left_eye_idx]
        right_eye = pts[right_eye_idx]
        mouth = pts[mouth_idx]

        left_ear = eye_aspect_ratio(left_eye)
        right_ear = eye_aspect_ratio(right_eye)
        ear = (left_ear + right_ear) / 2.0

        mar = mouth_aspect_ratio(mouth)

        if np.isnan(ear) or np.isnan(mar):
            logger.warning("[EAR/MAR] nan detected")
            return None, None, pts, False

        log_debug("[EAR/MAR] ear=%.4f, mar=%.4f, frontal=%s", ear, mar, frontal)
        return float(ear), float(mar), pts, True

    except Exception as e:
        logger.exception("[EAR/MAR] extraction error: %s", e)
        return None, None, None, False


# =========================================================
# OVERLAY
# =========================================================
def draw_drowsiness_overlay(preview):
    if not drowsiness_status["active"]:
        return

    ear_text = drowsiness_status["ear"]
    mar_text = drowsiness_status["mar"]
    status_text = drowsiness_status["status"]
    score_text = drowsiness_status["score"]
    mood_text = drowsiness_status["mood"]
    mood_confidence = drowsiness_status["mood_confidence"]
    raw_mood_text = drowsiness_status["raw_mood"]
    mood_elapsed = drowsiness_status["mood_candidate_elapsed"]
    mood_required = drowsiness_status["mood_required_sec"]

    cv2.putText(
        preview,
        f"Drowsy: {status_text}",
        (20, 60),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.75,
        (255, 255, 0),
        2,
        cv2.LINE_AA,
    )

    cv2.putText(
        preview,
        f"EAR: {ear_text:.3f}" if ear_text is not None else "EAR: -",
        (20, 90),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.65,
        (255, 255, 255),
        2,
        cv2.LINE_AA,
    )

    cv2.putText(
        preview,
        f"MAR: {mar_text:.3f}" if mar_text is not None else "MAR: -",
        (20, 120),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.65,
        (255, 255, 255),
        2,
        cv2.LINE_AA,
    )

    cv2.putText(
        preview,
        f"Score: {score_text:.3f}",
        (20, 150),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.65,
        (255, 255, 255),
        2,
        cv2.LINE_AA,
    )

    cv2.putText(
        preview,
        f"Mood: {mood_text} ({mood_confidence:.2f}) raw={raw_mood_text}",
        (20, 180),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.65,
        (255, 255, 255),
        2,
        cv2.LINE_AA,
    )

    cv2.putText(
        preview,
        f"Mood hold: {mood_elapsed:.1f}/{mood_required:.1f}s",
        (20, 210),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.65,
        (255, 255, 255),
        2,
        cv2.LINE_AA,
    )


# =========================================================
# PLACEHOLDER
# =========================================================
def make_placeholder_frame(text="Waiting for camera..."):
    frame = np.zeros((480, 640, 3), dtype=np.uint8)
    frame[:] = (30, 30, 30)

    cv2.putText(
        frame,
        text,
        (40, 240),
        cv2.FONT_HERSHEY_SIMPLEX,
        1,
        (255, 255, 255),
        2,
        cv2.LINE_AA,
    )
    return frame


# =========================================================
# CAMERA LOOP
# =========================================================
def camera_loop():
    global last_frame

    logger.info("[SYSTEM] Camera thread started")

    init_camera()
    init_recognizer()
    init_drowsiness_engine()

    try:
        init_face_mesh()
    except Exception as e:
        logger.exception("[SYSTEM] Face mesh init failed: %s", e)

    logger.info(
        "[SYSTEM] loop module=%s engine_id=%s",
        __name__,
        id(drowsy_engine),
    )

    while True:
        try:
            ret, frame = camera.read()

            if not ret or frame is None:
                logger.warning("[SYSTEM] Camera read failed")
                with frame_lock:
                    last_frame = make_placeholder_frame("Camera read failed")
                time.sleep(0.1)
                continue

            # =================================================
            # FACE RECOGNITION
            # =================================================
            stable_name, stable_ratio, bbox = recognizer.step(frame)
            raw_name = recognizer.last_raw_name
            raw_conf = recognizer.last_raw_conf

            preview = frame.copy()

            if bbox is not None:
                x, y, w, h = bbox
                cv2.rectangle(preview, (x, y), (x + w, y + h), (0, 255, 0), 2)

            if raw_name:
                driver_status["driver"] = raw_name
                driver_status["recognized"] = True
                driver_status["confidence"] = raw_conf
                driver_status["bbox"] = bbox

                cv2.putText(
                    preview,
                    f"{raw_name} | {raw_conf:.2f}",
                    (20, 30),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.8,
                    (0, 255, 0),
                    2,
                    cv2.LINE_AA,
                )
            else:
                driver_status["driver"] = None
                driver_status["recognized"] = False
                driver_status["confidence"] = raw_conf
                driver_status["bbox"] = bbox

                unknown_text = "Unknown"
                if bbox is not None:
                    unknown_text = f"Unknown | {raw_conf:.2f}"

                cv2.putText(
                    preview,
                    unknown_text,
                    (20, 30),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.8,
                    (0, 0, 255),
                    2,
                    cv2.LINE_AA,
                )

            # =================================================
            # DROWSINESS
            # =================================================
            log_debug(
                "[LOOP] active=%s driver=%s status=%s",
                drowsiness_status["active"],
                drowsiness_status["driver_name"],
                drowsiness_status["status"],
            )

            frontal = False
            ear = None
            mar = None
            pts = None

            if drowsiness_status["active"]:
                driver_match = update_driver_match_status()

                if not driver_match:
                    drowsiness_status["face_position"] = "not_target_driver"
                    reset_detection_values(status="waiting_driver")
                    log_debug(
                        "[DROWSINESS] skipped because recognized driver %s "
                        "does not match target %s",
                        drowsiness_status["recognized_driver"],
                        drowsiness_status["driver_name"],
                    )
                    draw_drowsiness_overlay(preview)

                    with frame_lock:
                        last_frame = preview

                    time.sleep(0.03)
                    continue

                ear, mar, pts, frontal = extract_ear_mar(frame)

                drowsiness_status["face_position"] = "frontal" if frontal else "not_frontal"

                log_debug("[LOOP DEBUG] frontal=%s ear=%s mar=%s", frontal, ear, mar)

                if frontal and ear is not None and mar is not None:
                    now = time.time()
                    update_drowsiness_from_metrics(ear, mar, now)
                    update_mood_from_landmarks(pts, now)
                else:
                    reset_mood_values()
                    log_debug(
                        "[DROWSINESS] skipped update because face is not frontal "
                        "or metrics invalid"
                    )
            else:
                drowsiness_status["face_position"] = "not_frontal"
                drowsiness_status["recognized_driver"] = driver_status.get("driver")
                drowsiness_status["driver_match"] = False

            draw_drowsiness_overlay(preview)

            with frame_lock:
                last_frame = preview

            time.sleep(0.03)

        except Exception as e:
            logger.exception("[SYSTEM] camera_loop error: %s", e)
            with frame_lock:
                last_frame = make_placeholder_frame(f"Error: {str(e)[:30]}")
            time.sleep(0.1)


# =========================================================
# FRAME ACCESS
# =========================================================
def get_latest_frame():
    with frame_lock:
        if last_frame is None:
            return make_placeholder_frame()
        return last_frame.copy()
