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

# stabilizer (voting)
VOTE_WINDOW_SEC = float(os.getenv("FACEID_VOTE_WINDOW_SEC", "1.8"))
VOTE_MIN_RATIO = float(os.getenv("FACEID_VOTE_MIN_RATIO", "0.65"))
VOTE_MIN_SAMPLES = int(os.getenv("FACEID_VOTE_MIN_SAMPLES", "4"))
