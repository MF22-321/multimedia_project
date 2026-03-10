import cv2
import time
import threading
import numpy as np
from faceid import FaceID

camera = None
last_frame = None
frame_lock = threading.Lock()

recognizer = None

driver_status = {
    "driver": None,
    "recognized": False,
    "confidence": 0,
    "bbox": None,
}


def init_camera():
    global camera

    if camera is None:
        camera = cv2.VideoCapture(0, cv2.CAP_DSHOW)
        camera.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
        camera.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
        camera.set(cv2.CAP_PROP_FPS, 30)

        if not camera.isOpened():
            raise RuntimeError("Cannot open webcam")

        print("Webcam opened successfully")


def init_recognizer():
    global recognizer

    if recognizer is None:
        recognizer = FaceID(
            conf_threshold=0.30,
            vote_window_sec=1.5,
            vote_min_ratio=0.60,
            vote_min_samples=6,
        )
        print("Recognizer initialized")


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
    print("Recognizer reloaded")


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
        cv2.LINE_AA
    )
    return frame


def camera_loop():
    global last_frame

    print("Camera thread started")

    init_camera()
    init_recognizer()

    while True:
        try:
            ret, frame = camera.read()

            if not ret or frame is None:
                print("Camera read failed")
                with frame_lock:
                    last_frame = make_placeholder_frame("Camera read failed")
                time.sleep(0.1)
                continue

            # FACE RECOGNITION DI SINI
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
                    cv2.LINE_AA
                )
            else:
                driver_status["driver"] = None
                driver_status["recognized"] = False
                driver_status["confidence"] = 0
                driver_status["bbox"] = bbox

                cv2.putText(
                    preview,
                    "Unknown",
                    (20, 30),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.8,
                    (0, 0, 255),
                    2,
                    cv2.LINE_AA
                )

            with frame_lock:
                last_frame = preview

            time.sleep(0.03)

        except Exception as e:
            print(f"camera_loop error: {e}")
            with frame_lock:
                last_frame = make_placeholder_frame(f"Error: {str(e)[:30]}")
            time.sleep(0.1)


def get_latest_frame():
    with frame_lock:
        if last_frame is None:
            return make_placeholder_frame()
        return last_frame.copy()