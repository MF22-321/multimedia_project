import re

from fastapi import HTTPException


_INVALID_DRIVER_CHARS = re.compile(r"[\\/\x00-\x1f\x7f]")


def validate_driver_name(value: str) -> str:
    """Return a safe, normalized driver directory name."""
    driver_name = value.strip()
    if not driver_name:
        raise HTTPException(status_code=400, detail="driver_name is required")
    if len(driver_name) > 80:
        raise HTTPException(status_code=400, detail="driver_name is too long")
    if driver_name in {".", ".."} or _INVALID_DRIVER_CHARS.search(driver_name):
        raise HTTPException(status_code=400, detail="driver_name contains invalid characters")
    return driver_name
