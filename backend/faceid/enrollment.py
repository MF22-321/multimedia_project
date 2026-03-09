import cv2
import time
from pathlib import Path
from .config import (
    DATASET_DIR, FACE_SIZE,
    AUTO_CAPTURE_SEC, CAPTURE_INTERVAL_SEC, MIN_FACE_PX
)
from .labels_store import load_labels, ensure_label
from .lbph_model import train_lbph
from .landmarker_bbox import LandmarkerFaceCropper

def enroll_driver(driver_id: str, camera_index: int = 1):
    labels = load_labels()
    label_id = ensure_label(labels, driver_id)

    out_dir: Path = DATASET_DIR / driver_id
    out_dir.mkdir(parents=True, exist_ok=True)
    count = len(list(out_dir.glob("*.jpg")))

    cap = cv2.VideoCapture(camera_index, cv2.CAP_DSHOW)
    if not cap.isOpened():
        print("Kamera tidak bisa dibuka.")
        return

    cropper = LandmarkerFaceCropper()

    auto_mode = False
    auto_end_time = 0.0
    last_save_time = 0.0

    print("Instruksi:")
    print(" - Tekan 'a' untuk AUTO capture")
    print(" - Tekan 's' untuk simpan manual 1 foto")
    print(" - Tekan 'q' untuk selesai & training")

    try:
        while True:
            ret, frame = cap.read()
            if not ret:
                break

            frame = cv2.flip(frame, 1)

            roi, bbox = cropper.crop(frame, min_face_px=MIN_FACE_PX)
            now = time.time()

            # auto capture
            if auto_mode:
                if now >= auto_end_time:
                    auto_mode = False
                    print("✅ Auto-capture selesai.")
                else:
                    if roi is not None and (now - last_save_time) >= CAPTURE_INTERVAL_SEC:
                        out_path = out_dir / f"{count:04d}.jpg"
                        cv2.imwrite(str(out_path), roi)
                        count += 1
                        last_save_time = now
                        print("Auto saved:", out_path)

            # overlay
            mode_txt = "AUTO" if auto_mode else "MANUAL"
            cv2.putText(frame, f"Driver: {driver_id} (label {label_id}) | Saved: {count}", (20, 40),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 255, 255), 2)
            cv2.putText(frame, f"Mode: {mode_txt} | 'a' auto {AUTO_CAPTURE_SEC:.0f}s", (20, 80),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.8, (180, 180, 180), 2)
            cv2.putText(frame, "'s' save manual | 'q' quit & train", (20, 110),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.8, (180, 180, 180), 2)

            if bbox is not None:
                x, y, w, h = bbox
                cv2.rectangle(frame, (x, y), (x+w, y+h), (0, 255, 0), 2)
            else:
                cv2.putText(frame, "No face", (20, 150),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 0, 255), 2)

            cv2.imshow("Enroll Driver (SRP)", frame)

            key = cv2.waitKey(1) & 0xFF

            if key == ord("q"):
                break

            if key == ord("a"):
                auto_mode = True
                auto_end_time = time.time() + AUTO_CAPTURE_SEC
                last_save_time = 0.0
                print(f"▶ Auto-capture mulai ({AUTO_CAPTURE_SEC}s). Gerakkan kepala pelan...")

            if key == ord("s"):
                if roi is None:
                    print("Wajah belum terdeteksi.")
                else:
                    out_path = out_dir / f"{count:04d}.jpg"
                    cv2.imwrite(str(out_path), roi)
                    count += 1
                    print("Saved:", out_path)

    finally:
        cropper.close()
        cap.release()
        cv2.destroyAllWindows()

    # Train model after enrollment
    print("Training model...")
    recognizer = train_lbph(load_labels())
    if recognizer is None:
        print("❌ Training gagal: dataset kurang.")
    else:
        print("✅ Training sukses.")