import argparse
import json
import sys
from pathlib import Path

import cv2
import numpy as np

ROOT_DIR = Path(__file__).resolve().parents[2]
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from backend.faceid.config import DATASET_DIR
from backend.faceid.sface_model import SFaceEngine


def collect_embeddings(dataset_dir: Path) -> dict[str, list[np.ndarray]]:
    engine = SFaceEngine()
    identities = {}
    for folder in sorted(path for path in dataset_dir.iterdir() if path.is_dir()):
        vectors = []
        for image_path in sorted(folder.glob("*.jpg")):
            image = cv2.imread(str(image_path), cv2.IMREAD_COLOR)
            if image is None:
                continue
            observation = engine.observe(image, require_quality=False, min_face_px=40)
            if observation is not None:
                vectors.append(observation.embedding)
        if vectors:
            identities[folder.name] = vectors
    return identities


def evaluate(identities: dict[str, list[np.ndarray]]) -> dict:
    genuine = []
    impostor = []
    names = sorted(identities)
    for name in names:
        vectors = identities[name]
        for index, left in enumerate(vectors):
            for right in vectors[index + 1 :]:
                genuine.append(float(np.dot(left, right)))
    for left_index, left_name in enumerate(names):
        for right_name in names[left_index + 1 :]:
            for left in identities[left_name]:
                for right in identities[right_name]:
                    impostor.append(float(np.dot(left, right)))

    result = {
        "identities": {name: len(vectors) for name, vectors in identities.items()},
        "genuine_pairs": len(genuine),
        "impostor_pairs": len(impostor),
    }
    if genuine:
        result["genuine"] = {
            "min": float(np.min(genuine)),
            "p05": float(np.percentile(genuine, 5)),
            "median": float(np.median(genuine)),
            "max": float(np.max(genuine)),
        }
    if impostor:
        result["impostor"] = {
            "min": float(np.min(impostor)),
            "p99": float(np.percentile(impostor, 99)),
            "max": float(np.max(impostor)),
        }
    if genuine and impostor:
        genuine_floor = float(np.percentile(genuine, 5))
        impostor_ceiling = float(np.percentile(impostor, 99))
        result["recommended_threshold"] = (genuine_floor + impostor_ceiling) / 2
        result["separation"] = genuine_floor - impostor_ceiling
    else:
        result["warning"] = (
            "At least two identities and varied probe sessions are required "
            "for a safe threshold recommendation."
        )
    return result


def main():
    parser = argparse.ArgumentParser(description="Calibrate SFace on local drivers")
    parser.add_argument("--dataset", type=Path, default=DATASET_DIR)
    parser.add_argument("--json-out", type=Path)
    args = parser.parse_args()
    report = evaluate(collect_embeddings(args.dataset))
    output = json.dumps(report, indent=2)
    print(output)
    if args.json_out is not None:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(output + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
