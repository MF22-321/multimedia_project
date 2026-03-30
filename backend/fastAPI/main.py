import threading
import time

import cv2
import numpy as np
from fastapi import FastAPI, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse, Response

from backend.faceid import FaceID
from backend.faceid.config import DATASET_DIR
from backend.faceid.labels_store import load_labels, ensure_label
from backend.faceid.lbph_model import train_lbph
from backend.fastAPI.routes.drowsiness_routes import router as drowsiness_router

from backend.engine.camera_stream import (
    camera_loop,
    get_latest_frame,
    get_driver_status,
    reload_recognizer,
)

app = FastAPI(title="FaceID Backend")
app.include_router(drowsiness_router)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

DATASET_DIR.mkdir(parents=True, exist_ok=True)

faceid = None


def get_faceid():
    global faceid
    if faceid is None:
        faceid = FaceID(
            conf_threshold=0.50,
            vote_window_sec=1.5,
            vote_min_ratio=0.60,
            vote_min_samples=6,
        )
        print("[API] recognizer initialized")
    return faceid


def reload_faceid():
    global faceid

    try:
        if faceid is not None:
            faceid.close()
    except Exception:
        pass

    faceid = FaceID(
        conf_threshold=0.5,
        vote_window_sec=1.5,
        vote_min_ratio=0.60,
        vote_min_samples=6,
    )
    print("[API] recognizer reloaded")


def decode_image(file_bytes: bytes):
    np_arr = np.frombuffer(file_bytes, np.uint8)
    img = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
    return img


def save_face_samples_from_live_camera(
    driver_name: str,
    duration_sec: float = 5.0,
    target_samples: int = 40,
    interval_sec: float = 0.12,
):
    """
    Capture multiple face crops directly from live camera for a certain duration.
    Saves only valid detected face ROIs.
    """
    recognizer = get_faceid()

    out_dir = DATASET_DIR / driver_name
    out_dir.mkdir(parents=True, exist_ok=True)

    start_idx = len(list(out_dir.glob("*.jpg")))
    saved_paths = []

    start_time = time.time()
    last_save_time = 0.0
    sample_idx = start_idx

    while (time.time() - start_time) < duration_sec and len(saved_paths) < target_samples:
        now = time.time()

        if now - last_save_time < interval_sec:
            time.sleep(0.01)
            continue

        frame = get_latest_frame()
        if frame is None:
            time.sleep(0.01)
            continue

        roi, bbox = recognizer.cropper.crop(frame)

        if roi is None:
            time.sleep(0.01)
            continue

        h, w = roi.shape[:2]
        if h < 80 or w < 80:
            time.sleep(0.01)
            continue

        out_path = out_dir / f"{sample_idx:04d}.jpg"
        ok = cv2.imwrite(str(out_path), roi)

        if ok:
            saved_paths.append(str(out_path))
            sample_idx += 1
            last_save_time = now
            print(f"[BURST] saved {out_path}")

        time.sleep(0.01)

    return saved_paths


@app.on_event("startup")
def start_camera():
    print("[SYSTEM] Starting camera thread...")
    thread = threading.Thread(target=camera_loop, daemon=True)
    thread.start()


@app.get("/")
def root():
    return {"message": "FaceID backend is running"}


def generate_frames():
    while True:
        frame = get_latest_frame()

        ret, buffer = cv2.imencode(".jpg", frame)
        if not ret:
            time.sleep(0.03)
            continue

        frame_bytes = buffer.tobytes()

        yield (
            b"--frame\r\n"
            b"Content-Type: image/jpeg\r\n\r\n" + frame_bytes + b"\r\n"
        )

        time.sleep(0.03)


@app.get("/camera_feed")
def camera_feed():
    return StreamingResponse(
        generate_frames(),
        media_type="multipart/x-mixed-replace; boundary=frame",
        headers={
            "Cache-Control": "no-cache, no-store, must-revalidate",
            "Pragma": "no-cache",
            "Expires": "0",
        },
    )


@app.get("/capture_face")
def capture_face():
    frame = get_latest_frame()

    ret, buffer = cv2.imencode(".jpg", frame)
    if not ret:
        return {"success": False, "message": "Failed to encode frame"}

    return Response(buffer.tobytes(), media_type="image/jpeg")


@app.get("/driver_status")
def driver_status():
    return get_driver_status()


@app.post("/recognize")
async def recognize(image: UploadFile = File(...)):
    contents = await image.read()
    frame = decode_image(contents)

    if frame is None:
        return {"success": False, "message": "Invalid image"}

    recognizer = get_faceid()

    stable_name, stable_ratio, bbox = recognizer.step(frame)

    raw_name = recognizer.last_raw_name
    raw_conf = recognizer.last_raw_conf
    last_bbox = recognizer.last_bbox

    if raw_name is not None:
        print(f"[/recognize] registered: {raw_name} ({raw_conf})")
        return {
            "success": True,
            "status": "registered",
            "driver_name": raw_name,
            "confidence": raw_conf,
            "stable_ratio": stable_ratio,
            "bbox": last_bbox,
        }

    print("[/recognize] unknown")
    return {
        "success": True,
        "status": "unknown",
        "driver_name": None,
        "confidence": raw_conf,
        "stable_ratio": stable_ratio,
        "bbox": last_bbox,
    }


@app.post("/enroll")
async def enroll(
    driver_name: str = Form(...),
    image: UploadFile = File(...),
):
    driver_name = driver_name.strip()

    if not driver_name:
        return {"success": False, "message": "Driver name is required"}

    contents = await image.read()
    frame = decode_image(contents)

    if frame is None:
        return {"success": False, "message": "Invalid image"}

    recognizer = get_faceid()

    roi, bbox = recognizer.cropper.crop(frame)

    if roi is None:
        return {"success": False, "message": "No face detected"}

    labels = load_labels()
    label_id = ensure_label(labels, driver_name)

    out_dir = DATASET_DIR / driver_name
    out_dir.mkdir(parents=True, exist_ok=True)

    count = len(list(out_dir.glob("*.jpg")))
    out_path = out_dir / f"{count:04d}.jpg"
    cv2.imwrite(str(out_path), roi)

    rec = train_lbph(labels)
    if rec is None:
        return {
            "success": False,
            "message": "Training failed (dataset not enough)",
            "saved_path": str(out_path),
        }

    reload_faceid()
    reload_recognizer()

    print(f"[/enroll] success: {driver_name} -> {out_path}")

    return {
        "success": True,
        "message": "Driver enrolled successfully",
        "driver_name": driver_name,
        "label_id": label_id,
        "saved_path": str(out_path),
    }


@app.post("/enroll_live_burst")
async def enroll_live_burst(
    driver_name: str = Form(...),
    duration_sec: float = Form(8.0),
    target_samples: int = Form(60),
):
    try:
        driver_name = driver_name.strip()

        if not driver_name:
            return {
                "success": False,
                "message": "Driver name is required",
            }

        labels = load_labels()
        label_id = ensure_label(labels, driver_name)

        print(
            f"[/enroll_live_burst] start | "
            f"name={driver_name}, duration={duration_sec}, target={target_samples}"
        )

        saved_paths = save_face_samples_from_live_camera(
            driver_name=driver_name,
            duration_sec=duration_sec,
            target_samples=target_samples,
            interval_sec=0.12,
        )

        print(f"[/enroll_live_burst] saved_paths count = {len(saved_paths)}")

        if len(saved_paths) == 0:
            return {
                "success": False,
                "message": "No face samples captured from live camera",
                "driver_name": driver_name,
                "saved_count": 0,
            }

        rec = train_lbph(labels)
        print(f"[/enroll_live_burst] train_lbph result = {rec}")

        if rec is None:
            return {
                "success": False,
                "message": "Training failed after burst capture",
                "driver_name": driver_name,
                "saved_count": len(saved_paths),
                "saved_paths": saved_paths,
            }

        reload_faceid()
        reload_recognizer()

        print(
            f"[/enroll_live_burst] success | "
            f"name={driver_name}, saved_count={len(saved_paths)}"
        )

        return {
            "success": True,
            "message": "Driver enrolled from live burst successfully",
            "driver_name": driver_name,
            "label_id": label_id,
            "saved_count": len(saved_paths),
            "saved_paths": saved_paths,
        }

    except Exception as e:
        import traceback
        traceback.print_exc()
        return {
            "success": False,
            "message": f"Burst enroll exception: {str(e)}"
        }