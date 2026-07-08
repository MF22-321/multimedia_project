import os
from pathlib import Path

# backend/faceid/config.py
# parent     = backend/faceid
# parent.parent = backend
BASE_DIR = Path(__file__).resolve().parent.parent

DATASET_DIR = BASE_DIR / "dataset"
MODELS_DIR = BASE_DIR / "models"
PROFILES_DIR = BASE_DIR / "profiles"

LABELS_PATH = MODELS_DIR / "labels.json"
LBPH_MODEL_PATH = MODELS_DIR / "lbph_model.yml"
EMBEDDING_MODEL_PATH = Path(
    os.getenv("FACEID_EMBEDDING_MODEL_PATH", str(MODELS_DIR / "arcface.onnx"))
)
EMBEDDINGS_PATH = MODELS_DIR / "face_embeddings.json"
LANDMARKER_PATH = MODELS_DIR / "face_landmarker.task"
BLAZE_FACE_PATH = MODELS_DIR / "blaze_face_short_range.tflite"

FACE_SIZE = (200, 200)

# enrollment
AUTO_CAPTURE_SEC = 8.0
CAPTURE_INTERVAL_SEC = 0.25
MIN_FACE_PX = 120

# identify defaults
#
# LBPH returns distance where lower is better; the app maps it into 0..1
# confidence. Keep the default strict enough to avoid different users being
# accepted as the closest registered label.
CONF_THRESHOLD = float(os.getenv("FACEID_CONF_THRESHOLD", "0.42"))

# Optional embedding recognizer. Put an ArcFace/MobileFaceNet ONNX model at
# backend/models/arcface.onnx and rebuild embeddings to enable this path.
USE_EMBEDDINGS = os.getenv("FACEID_USE_EMBEDDINGS", "1").lower() in {
    "1",
    "true",
    "yes",
    "on",
}
EMBEDDING_THRESHOLD = float(os.getenv("FACEID_EMBEDDING_THRESHOLD", "0.48"))
EMBEDDING_MARGIN = float(os.getenv("FACEID_EMBEDDING_MARGIN", "0.04"))
EMBEDDING_INPUT_SIZE = int(os.getenv("FACEID_EMBEDDING_INPUT_SIZE", "112"))

# stabilizer (voting)
VOTE_WINDOW_SEC = float(os.getenv("FACEID_VOTE_WINDOW_SEC", "1.8"))
VOTE_MIN_RATIO = float(os.getenv("FACEID_VOTE_MIN_RATIO", "0.65"))
VOTE_MIN_SAMPLES = int(os.getenv("FACEID_VOTE_MIN_SAMPLES", "4"))
