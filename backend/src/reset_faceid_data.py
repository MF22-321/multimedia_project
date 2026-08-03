from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]  # project root (Drowsiness_detection)

DATASET_DIR = ROOT / "dataset"
PROFILES_DIR = ROOT / "profiles"

MODELS_DIR = ROOT / "models"
LBPH_MODEL = MODELS_DIR / "lbph_model.yml"
LABELS_JSON = MODELS_DIR / "labels.json"
EMBEDDINGS_JSON = MODELS_DIR / "face_embeddings.json"

def rm(path: Path):
    if path.is_dir():
        shutil.rmtree(path, ignore_errors=True)
        print("Removed folder:", path)
    elif path.exists():
        path.unlink()
        print("Removed file:", path)

def main():
    print("=== RESET FaceID Data ===")
    rm(DATASET_DIR)
    rm(PROFILES_DIR)
    rm(LBPH_MODEL)
    rm(LABELS_JSON)
    rm(EMBEDDINGS_JSON)

    # recreate empty dirs
    DATASET_DIR.mkdir(exist_ok=True)
    PROFILES_DIR.mkdir(exist_ok=True)

    print("Done. FaceID dataset/model/labels/profiles reset to empty.")

if __name__ == "__main__":
    main()
