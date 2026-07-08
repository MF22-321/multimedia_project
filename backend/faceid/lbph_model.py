import cv2
import numpy as np
from pathlib import Path
from .config import LBPH_MODEL_PATH, FACE_SIZE, DATASET_DIR


def preprocess_face(gray):
    gray = cv2.resize(gray, FACE_SIZE)
    gray = cv2.GaussianBlur(gray, (3, 3), 0)
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    return clahe.apply(gray)


def _adjust_brightness_contrast(gray, alpha=1.0, beta=0):
    return cv2.convertScaleAbs(gray, alpha=alpha, beta=beta)


def _rotate(gray, angle):
    h, w = gray.shape[:2]
    matrix = cv2.getRotationMatrix2D((w / 2, h / 2), angle, 1.0)
    return cv2.warpAffine(
        gray,
        matrix,
        (w, h),
        flags=cv2.INTER_LINEAR,
        borderMode=cv2.BORDER_REPLICATE,
    )


def augment_face(gray):
    base = preprocess_face(gray)
    variants = [
        base,
        _adjust_brightness_contrast(base, alpha=0.82, beta=-12),
        _adjust_brightness_contrast(base, alpha=1.18, beta=10),
        _adjust_brightness_contrast(base, alpha=1.08, beta=-18),
        _rotate(base, -5),
        _rotate(base, 5),
    ]
    return variants


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
            for face in augment_face(img):
                faces.append(face)
                ids.append(int(label))

    if len(faces) < 2:
        return None

    labels_np = np.array(ids, dtype=np.int32).reshape(-1, 1)
    recognizer.train(faces, labels_np)
    recognizer.save(str(LBPH_MODEL_PATH))
    return recognizer
