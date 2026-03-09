import json
import time
from pathlib import Path
from typing import Optional, Dict, Any

PROFILES_DIR = Path("profiles")
PROFILES_DIR.mkdir(parents=True, exist_ok=True)

def profile_path(driver_id: str) -> Path:
    return PROFILES_DIR / f"{driver_id}.json"

def load_profile(driver_id: str) -> Optional[Dict[str, Any]]:
    p = profile_path(driver_id)
    if not p.exists():
        return None
    return json.loads(p.read_text(encoding="utf-8"))

def save_profile(driver_id: str, data: Dict[str, Any]) -> None:
    data["updated_at"] = time.strftime("%Y-%m-%d %H:%M:%S")
    p = profile_path(driver_id)
    p.write_text(json.dumps(data, indent=2), encoding="utf-8")

def get_or_create_profile(driver_id: str) -> Dict[str, Any]:
    prof = load_profile(driver_id)
    if prof is None:
        prof = {
            "driver_id": driver_id,
            "created_at": time.strftime("%Y-%m-%d %H:%M:%S"),
            "updated_at": time.strftime("%Y-%m-%d %H:%M:%S"),
            "baseline_ear": None
        }
        save_profile(driver_id, prof)
    return prof