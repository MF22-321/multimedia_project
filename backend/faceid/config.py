from pathlib import Path

DATASET_DIR = Path("dataset")
MODELS_DIR = Path("models")

LABELS_PATH = MODELS_DIR / "labels.json"
LBPH_MODEL_PATH = MODELS_DIR / "lbph_model.yml"
LANDMARKER_PATH = MODELS_DIR / "face_landmarker.task"

FACE_SIZE = (200, 200)

# enrollment
AUTO_CAPTURE_SEC = 8.0
CAPTURE_INTERVAL_SEC = 0.25
MIN_FACE_PX = 120

# identify defaults
CONF_THRESHOLD = 0.35

# stabilizer (voting)
VOTE_WINDOW_SEC = 1.5
VOTE_MIN_RATIO = 0.60
VOTE_MIN_SAMPLES = 6