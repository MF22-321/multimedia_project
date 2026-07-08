import json
import logging
from pathlib import Path
from typing import Optional, Tuple

import cv2
import numpy as np

from .config import (
    DATASET_DIR,
    EMBEDDING_INPUT_SIZE,
    EMBEDDING_MARGIN,
    EMBEDDING_MODEL_PATH,
    EMBEDDING_THRESHOLD,
    EMBEDDINGS_PATH,
    USE_EMBEDDINGS,
)

logger = logging.getLogger(__name__)


def _normalize(vector: np.ndarray) -> np.ndarray:
    norm = np.linalg.norm(vector)
    if norm <= 1e-8:
        return vector.astype(np.float32)
    return (vector / norm).astype(np.float32)


class FaceEmbeddingModel:
    def __init__(self, model_path: Path = EMBEDDING_MODEL_PATH):
        if not model_path.exists():
            raise FileNotFoundError(f"Embedding model not found: {model_path}")

        self.model_path = model_path
        self.net = cv2.dnn.readNetFromONNX(str(model_path))

    def embed(self, face_bgr) -> np.ndarray:
        size = (EMBEDDING_INPUT_SIZE, EMBEDDING_INPUT_SIZE)
        face = cv2.resize(face_bgr, size)

        if len(face.shape) == 2:
            face = cv2.cvtColor(face, cv2.COLOR_GRAY2BGR)

        face = cv2.cvtColor(face, cv2.COLOR_BGR2RGB)
        blob = cv2.dnn.blobFromImage(
            face,
            scalefactor=1.0 / 128.0,
            size=size,
            mean=(127.5, 127.5, 127.5),
            swapRB=False,
            crop=False,
        )

        self.net.setInput(blob)
        embedding = self.net.forward().reshape(-1)
        return _normalize(embedding)


def build_embeddings(labels_map: dict) -> bool:
    if not USE_EMBEDDINGS:
        return False
    if not EMBEDDING_MODEL_PATH.exists():
        logger.info("[FaceEmbed] model missing, skip embedding build")
        return False

    model = FaceEmbeddingModel()
    data = {}

    for driver_id in labels_map.keys():
        folder = DATASET_DIR / driver_id
        if not folder.exists():
            continue

        vectors = []
        for img_path in sorted(folder.glob("*.jpg")):
            img = cv2.imread(str(img_path), cv2.IMREAD_COLOR)
            if img is None:
                continue

            try:
                vectors.append(model.embed(img).tolist())
            except Exception as exc:
                logger.warning("[FaceEmbed] skip %s: %s", img_path, exc)

        if vectors:
            data[driver_id] = vectors

    EMBEDDINGS_PATH.parent.mkdir(parents=True, exist_ok=True)
    EMBEDDINGS_PATH.write_text(json.dumps(data), encoding="utf-8")
    logger.info("[FaceEmbed] embeddings saved: %s drivers", len(data))
    return bool(data)


class EmbeddingRecognizer:
    def __init__(
        self,
        threshold: float = EMBEDDING_THRESHOLD,
        margin: float = EMBEDDING_MARGIN,
    ):
        if not USE_EMBEDDINGS:
            raise FileNotFoundError("Embedding recognizer disabled")
        if not EMBEDDING_MODEL_PATH.exists():
            raise FileNotFoundError(f"Embedding model not found: {EMBEDDING_MODEL_PATH}")
        if not EMBEDDINGS_PATH.exists():
            raise FileNotFoundError(f"Embeddings not found: {EMBEDDINGS_PATH}")

        self.model = FaceEmbeddingModel()
        self.threshold = threshold
        self.margin = margin
        self.database = self._load_database()

    def _load_database(self) -> dict[str, list[np.ndarray]]:
        raw = json.loads(EMBEDDINGS_PATH.read_text(encoding="utf-8"))
        database = {}
        for name, vectors in raw.items():
            database[name] = [_normalize(np.array(v, dtype=np.float32)) for v in vectors]
        return database

    def predict(self, face_bgr) -> Tuple[Optional[str], float]:
        if not self.database:
            return None, 0.0

        query = self.model.embed(face_bgr)
        scores = []

        for name, vectors in self.database.items():
            if not vectors:
                continue
            sims = [float(np.dot(query, vector)) for vector in vectors]
            scores.append((name, max(sims)))

        if not scores:
            return None, 0.0

        scores.sort(key=lambda item: item[1], reverse=True)
        best_name, best_score = scores[0]
        second_score = scores[1][1] if len(scores) > 1 else -1.0

        if best_score < self.threshold:
            return None, best_score
        if second_score >= 0 and (best_score - second_score) < self.margin:
            return None, best_score

        return best_name, best_score
