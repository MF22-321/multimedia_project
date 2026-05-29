import cv2
import numpy as np
from pathlib import Path
from .config import LBPH_MODEL_PATH, FACE_SIZE, DATASET_DIR

def load_lbph():
    if not LBPH_MODEL_PATH.exists():
        raise FileNotFoundError(f"LBPH model not found: {LBPH_MODEL_PATH}")
    rec = cv2.face.LBPHFaceRecognizer_create()
    rec.read(str(LBPH_MODEL_PATH))
    return rec

def lbph_conf_from_dist(dist: float) -> float:
    # heuristic mapping: dist kecil => conf tinggi
    return float(np.exp(-dist / 50.0))

def train_lbph(labels_map: dict):
    """
    Train LBPH using ALL images under dataset/<driver_id>/*.jpg
    labels_map: {driver_id: label_int}
    """
    DATASET_DIR.mkdir(parents=True, exist_ok=True)
    LBPH_MODEL_PATH.parent.mkdir(parents=True, exist_ok=True)

    recognizer = cv2.face.LBPHFaceRecognizer_create()
    faces = []
    ids = []

    for driver_id, label in labels_map.items():
        folder = DATASET_DIR / driver_id
        if not folder.exists():
            continue
        for img_path in folder.glob("*.jpg"):
            img = cv2.imread(str(img_path), cv2.IMREAD_GRAYSCALE)
            if img is None:
                continue
            img = cv2.resize(img, FACE_SIZE)
            img = cv2.equalizeHist(img)
            faces.append(img)
            ids.append(int(label))

    if len(faces) < 2:
        return None

    labels_np = np.array(ids, dtype=np.int32).reshape(-1, 1)
    recognizer.train(faces, labels_np)
    recognizer.save(str(LBPH_MODEL_PATH))
    return recognizer
