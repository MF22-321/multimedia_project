from dataclasses import dataclass, field

@dataclass
class CameraConfig:
    index: int = 2
    width: int = 1280
    height: int = 720
    use_dshow: bool = False

@dataclass
class FaceIDConfig:
    enable: bool = True
    conf_threshold: float = 0.38
    vote_window_sec: float = 1.5
    vote_min_ratio: float = 0.60
    vote_min_samples: int = 6
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

    mar_threshold: float = 0.45
    consec_frames_yawn: int = 6
    yawn_cooldown_sec: float = 2.0
    yawn_window_sec: float = 120.0
    yawn_alert_count: int = 3

    use_score: bool = True
    eye_low_ratio: float = 0.75
    eye_full_close_ratio: float = 0.55
    w_eye: float = 0.75
    w_yawn: float = 0.25
    score_alpha: float = 0.20
    score_alert_th: float = 0.70
    alert_hold_sec: float = 2.0

    yawn_points_per_event: float = 1.0
    yawn_points_max: float = 3.0
    yawn_decay_per_sec: float = 1.0 / 30.0

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