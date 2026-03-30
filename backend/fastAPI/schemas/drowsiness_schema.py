from typing import Optional
from pydantic import BaseModel


class StartDrowsinessRequest(BaseModel):
    driver_name: str


class StartDrowsinessResponse(BaseModel):
    success: bool
    message: str
    active: bool
    driver_name: Optional[str] = None


class StopDrowsinessResponse(BaseModel):
    success: bool
    message: str
    active: bool


class DrowsinessStatusResponse(BaseModel):
    active: bool
    driver_name: Optional[str] = None
    ear: Optional[float] = None
    mar: Optional[float] = None
    yawn_status: Optional[str] = None
    yawn_total: int = 0
    yawns_in_window: int = 0
    eye_score: float = 0.0
    yawn_score: float = 0.0
    ear_ratio: Optional[float] = None
    score: float = 0.0
    alert_active: bool = False
    calibrating: bool = False
    calib_remaining: float = 0.0
    status: str = "inactive"
    face_position: Optional[str] = None