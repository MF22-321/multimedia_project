import argparse
import json
import statistics
import sys
import time
from pathlib import Path

import cv2

ROOT_DIR = Path(__file__).resolve().parents[2]
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from backend.faceid.config import DATASET_DIR
from backend.faceid.sface_model import SFaceEngine


def main():
    parser = argparse.ArgumentParser(description="Benchmark YuNet + SFace")
    parser.add_argument("--iterations", type=int, default=100)
    parser.add_argument("--image", type=Path)
    args = parser.parse_args()
    image_path = args.image
    if image_path is None:
        image_path = next(DATASET_DIR.glob("*/*.jpg"), None)
    if image_path is None:
        raise SystemExit("No benchmark image found")
    image = cv2.imread(str(image_path), cv2.IMREAD_COLOR)
    if image is None:
        raise SystemExit(f"Cannot read {image_path}")

    engine = SFaceEngine()
    for _ in range(5):
        engine.observe(image, require_quality=False, min_face_px=40)
    timings = []
    detected = 0
    for _ in range(max(1, args.iterations)):
        started = time.perf_counter()
        observation = engine.observe(image, require_quality=False, min_face_px=40)
        timings.append((time.perf_counter() - started) * 1000.0)
        detected += observation is not None
    report = {
        "backend": engine.dnn_target,
        "iterations": len(timings),
        "detected": detected,
        "median_ms": round(statistics.median(timings), 3),
        "p95_ms": round(sorted(timings)[int(0.95 * (len(timings) - 1))], 3),
        "fps": round(1000.0 / statistics.mean(timings), 2),
    }
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
