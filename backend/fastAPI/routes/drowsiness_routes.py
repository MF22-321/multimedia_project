from fastapi import APIRouter, HTTPException

from backend.fastAPI.schemas.drowsiness_schema import (
    StartDrowsinessRequest,
    StartDrowsinessResponse,
    StopDrowsinessResponse,
    DrowsinessStatusResponse,
)

from backend.engine.camera_stream import (
    start_drowsiness_monitoring,
    stop_drowsiness_monitoring,
    get_drowsiness_status,
)
from backend.fastAPI.validation import validate_driver_name

router = APIRouter(prefix="", tags=["Drowsiness"])


@router.post("/start_drowsiness", response_model=StartDrowsinessResponse)
def start_drowsiness(payload: StartDrowsinessRequest):
    driver_name = validate_driver_name(payload.driver_name)

    try:
        start_drowsiness_monitoring(driver_name)
        status = get_drowsiness_status()

        return StartDrowsinessResponse(
            success=True,
            message=f"Drowsiness monitoring started for {driver_name}",
            active=status.get("active", False),
            driver_name=status.get("driver_name"),
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/stop_drowsiness", response_model=StopDrowsinessResponse)
def stop_drowsiness():
    try:
        stop_drowsiness_monitoring()
        status = get_drowsiness_status()

        return StopDrowsinessResponse(
            success=True,
            message="Drowsiness monitoring stopped",
            active=status.get("active", False),
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/drowsiness_status", response_model=DrowsinessStatusResponse)
def read_drowsiness_status():
    try:
        status = get_drowsiness_status()
        return DrowsinessStatusResponse(**status)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
