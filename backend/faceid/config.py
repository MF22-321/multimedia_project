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
YUNET_MODEL_PATH = Path(
    os.getenv(
        "FACEID_YUNET_MODEL_PATH",
        str(MODELS_DIR / "face_detection_yunet_2023mar.onnx"),
    )
)
SFACE_MODEL_PATH = Path(
    os.getenv(
        "FACEID_SFACE_MODEL_PATH",
        str(MODELS_DIR / "face_recognition_sface_2021dec.onnx"),
    )
)
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
ENROLL_MIN_SAMPLES = int(os.getenv("FACEID_ENROLL_MIN_SAMPLES", "12"))
ENROLL_TEMPLATE_LIMIT_PER_CONDITION = int(
    os.getenv("FACEID_TEMPLATE_LIMIT_PER_CONDITION", "8")
)

# Primary recognizer. `lbph` is retained only as an explicit rollback mode.
RECOGNIZER_MODE = os.getenv("FACEID_RECOGNIZER", "sface").strip().lower()
SFACE_THRESHOLD = float(os.getenv("FACEID_SFACE_THRESHOLD", "0.40"))
SFACE_MARGIN = float(os.getenv("FACEID_SFACE_MARGIN", "0.06"))
SFACE_TOP_K = max(1, int(os.getenv("FACEID_SFACE_TOP_K", "3")))
SFACE_DETECT_THRESHOLD = float(os.getenv("FACEID_DETECT_THRESHOLD", "0.75"))
SFACE_DNN_TARGET = os.getenv("FACEID_DNN_TARGET", "cpu").strip().lower()

# Capture quality. Values are intentionally configurable because cabin cameras
# differ in exposure, focus and installation distance.
QUALITY_MIN_BRIGHTNESS = float(os.getenv("FACEID_MIN_BRIGHTNESS", "35"))
QUALITY_MAX_BRIGHTNESS = float(os.getenv("FACEID_MAX_BRIGHTNESS", "225"))
QUALITY_MIN_SHARPNESS = float(os.getenv("FACEID_MIN_SHARPNESS", "35"))
QUALITY_MAX_ABS_YAW = float(os.getenv("FACEID_MAX_ABS_YAW", "0.65"))
TEMPLATE_DUPLICATE_SIMILARITY = float(
    os.getenv("FACEID_TEMPLATE_DUPLICATE_SIMILARITY", "0.995")
)

# Lightweight temporal motion liveness. This blocks fully static images but is
# not presented as certified presentation-attack detection.
REQUIRE_LIVENESS = os.getenv("FACEID_REQUIRE_LIVENESS", "1").lower() in {
    "1",
    "true",
    "yes",
    "on",
}
LIVENESS_WINDOW_SEC = float(os.getenv("FACEID_LIVENESS_WINDOW_SEC", "2.0"))
LIVENESS_MIN_SAMPLES = int(os.getenv("FACEID_LIVENESS_MIN_SAMPLES", "3"))
LIVENESS_MIN_MOTION = float(os.getenv("FACEID_LIVENESS_MIN_MOTION", "0.003"))
ADAPTIVE_MIN_CONFIDENCE = float(os.getenv("FACEID_ADAPTIVE_MIN_CONFIDENCE", "0.58"))

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
