import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

from pathlib import Path
import threading
import time

import cv2
import numpy as np
from fastapi import FastAPI, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse, Response

from faceid import FaceID
from faceid.labels_store import load_labels, ensure_label
from faceid.lbph_model import train_lbph
from engine.camera_stream import (
    camera_loop,
    get_latest_frame,
    driver_status,
    reload_recognizer,
)

app = FastAPI(title="FaceID Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

DATASET_DIR = Path("dataset")
DATASET_DIR.mkdir(exist_ok=True)

faceid = None


def get_faceid():
    global faceid
    if faceid is None:
        faceid = FaceID(
            conf_threshold=0.45,
            vote_window_sec=1.5,
            vote_min_ratio=0.60,
            vote_min_samples=6,
        )
        print("API recognizer initialized")
    return faceid


def reload_faceid():
    global faceid

    try:
        if faceid is not None:
            faceid.close()
    except Exception:
        pass

    faceid = FaceID(
        conf_threshold=0.30,
        vote_window_sec=1.5,
        vote_min_ratio=0.60,
        vote_min_samples=6,
    )
    print("API recognizer reloaded")


def decode_image(file_bytes: bytes):
    np_arr = np.frombuffer(file_bytes, np.uint8)
    img = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
    return img


@app.on_event("startup")
def start_camera():
    print("Starting camera thread...")
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
def get_driver_status():
    return driver_status


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
        print(f"/recognize -> registered: {raw_name} ({raw_conf})")
        return {
            "success": True,
            "status": "registered",
            "driver_name": raw_name,
            "confidence": raw_conf,
            "stable_ratio": stable_ratio,
            "bbox": last_bbox,
        }

    print("/recognize -> unknown")
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

    # Reload recognizer untuk endpoint API
    reload_faceid()

    # Reload recognizer untuk live camera loop
    reload_recognizer()

    print(f"/enroll -> success: {driver_name}, saved to {out_path}")

    return {
        "success": True,
        "message": "Driver enrolled successfully",
        "driver_name": driver_name,
        "label_id": label_id,
        "saved_path": str(out_path),
    }