import json
from .config import LABELS_PATH

def load_labels() -> dict:
    if LABELS_PATH.exists():
        return json.loads(LABELS_PATH.read_text(encoding="utf-8"))
    return {}

def save_labels(labels: dict) -> None:
    LABELS_PATH.parent.mkdir(parents=True, exist_ok=True)
    LABELS_PATH.write_text(json.dumps(labels, indent=2), encoding="utf-8")

def ensure_label(labels: dict, driver_id: str) -> int:
    """
    labels: { "Raihan": 0, "Reiner": 1, ... }
    returns label int for driver_id, creating a new one if missing.
    """
    if driver_id in labels:
        return int(labels[driver_id])

    used = set(int(v) for v in labels.values()) if labels else set()
    new_label = 0
    while new_label in used:
        new_label += 1

    labels[driver_id] = int(new_label)
    save_labels(labels)
    return int(new_label)