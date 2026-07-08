import os
from dataclasses import dataclass, field

@dataclass
class CameraConfig:
    index: int = int(os.getenv("CAMERA_INDEX", "0"))
    width: int = int(os.getenv("CAMERA_WIDTH", "640"))
    height: int = int(os.getenv("CAMERA_HEIGHT", "480"))
    fps: int = int(os.getenv("CAMERA_FPS", "15"))
    use_dshow: bool = False

@dataclass
class FaceIDConfig:
    enable: bool = True
    conf_threshold: float = float(os.getenv("FACEID_CONF_THRESHOLD", "0.42"))
    vote_window_sec: float = float(os.getenv("FACEID_VOTE_WINDOW_SEC", "1.8"))
    vote_min_ratio: float = float(os.getenv("FACEID_VOTE_MIN_RATIO", "0.65"))
    vote_min_samples: int = int(os.getenv("FACEID_VOTE_MIN_SAMPLES", "4"))
    every_n_frames: int = 2

    unknown_prompt_sec: float = 2.0
    guest_suppress_sec: float = 60.0

    unlock_no_face_sec: float = 0.7
    unlock_unknown_sec: float = 1.0

@dataclass
class EnrollConfig:
    capture_seconds: float = 8.0
    capture_interval: float = 0.25

@dataclass
class DrowsyConfig:
    calib_seconds: float = 5.0
    min_baseline: float = 0.08
    thresh_ratio_display: float = 0.75

    mar_threshold: float = float(os.getenv("DROWSY_MAR_THRESHOLD", "0.32"))
    consec_frames_yawn: int = int(os.getenv("DROWSY_CONSEC_FRAMES_YAWN", "4"))
    yawn_cooldown_sec: float = float(os.getenv("DROWSY_YAWN_COOLDOWN_SEC", "4.0"))
    yawn_window_sec: float = float(os.getenv("DROWSY_YAWN_WINDOW_SEC", "60.0"))
    yawn_alert_count: int = 3

    use_score: bool = True
    eye_low_ratio: float = float(os.getenv("DROWSY_EYE_LOW_RATIO", "0.78"))
    eye_full_close_ratio: float = float(os.getenv("DROWSY_EYE_FULL_CLOSE_RATIO", "0.58"))
    closed_eye_ratio: float = float(os.getenv("DROWSY_CLOSED_EYE_RATIO", "0.70"))
    closed_eye_ear: float = float(os.getenv("DROWSY_CLOSED_EYE_EAR", "0.22"))
    closed_eye_alert_sec: float = float(os.getenv("DROWSY_CLOSED_EYE_ALERT_SEC", "3.0"))
    w_eye: float = 0.55
    w_yawn: float = 0.45
    score_alpha: float = 0.20
    score_alert_th: float = 0.85
    alert_hold_sec: float = float(os.getenv("DROWSY_ALERT_HOLD_SEC", "4.0"))
    alert_cooldown_sec: float = float(os.getenv("DROWSY_ALERT_COOLDOWN_SEC", "5.0"))

    yawn_points_per_event: float = 0.35
    yawn_points_max: float = 1.0
    yawn_decay_per_sec: float = 0.02

@dataclass
class ModelPaths:
    face_landmarker_task: str = "models/face_landmarker.task"

@dataclass
class AppConfig:
    camera: CameraConfig = field(default_factory=CameraConfig)
    faceid: FaceIDConfig = field(default_factory=FaceIDConfig)
    enroll: EnrollConfig = field(default_factory=EnrollConfig)
    drowsy: DrowsyConfig = field(default_factory=DrowsyConfig)
    paths: ModelPaths = field(default_factory=ModelPaths)
