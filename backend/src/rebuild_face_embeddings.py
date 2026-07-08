import sys
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parents[2]
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from backend.faceid.embedding_model import build_embeddings
from backend.faceid.labels_store import load_labels


def main():
    labels = load_labels()
    ok = build_embeddings(labels)
    print(f"labels={len(labels)} embeddings_built={ok}")


if __name__ == "__main__":
    main()
