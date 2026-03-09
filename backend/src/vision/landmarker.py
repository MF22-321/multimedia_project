import time
import numpy as np
import mediapipe as mp
from dataclasses import dataclass

from src.drowsy.metrics import eye_aspect_ratio, mouth_aspect_ratio

LEFT_EYE_IDX  = [33, 160, 158, 133, 153, 144]
RIGHT_EYE_IDX = [362, 385, 387, 263, 373, 380]
MOUTH_IDX     = [61, 13, 0, 291, 17, 14]

@dataclass
class FaceSignals:
    have_face: bool
    ear: float | None
    mar: float | None
    left_eye: np.ndarray | None
    right_eye: np.ndarray | None
    mouth: np.ndarray | None

class FaceLandmarkerWrapper:
    def __init__(self, model_path: str):
        BaseOptions = mp.tasks.BaseOptions
        FaceLandmarker = mp.tasks.vision.FaceLandmarker
        FaceLandmarkerOptions = mp.tasks.vision.FaceLandmarkerOptions
        VisionRunningMode = mp.tasks.vision.RunningMode

        self._FaceLandmarker = FaceLandmarker
        self._options = FaceLandmarkerOptions(
            base_options=BaseOptions(model_asset_path=model_path),
            running_mode=VisionRunningMode.VIDEO,
            num_faces=1,
            output_face_blendshapes=False,
            output_facial_transformation_matrixes=False,
        )
        self._start = time.time()
        self._landmarker = None

    def __enter__(self):
        self._landmarker = self._FaceLandmarker.create_from_options(self._options)
        return self

    def __exit__(self, exc_type, exc, tb):
        if self._landmarker is not None:
            self._landmarker.close()

    @staticmethod
    def _get_xy(face_lms, idx, w, h):
        lm = face_lms[idx]
        return np.array([lm.x * w, lm.y * h], dtype=np.float32)

    def step(self, frame_bgr) -> FaceSignals:
        h, w = frame_bgr.shape[:2]
        rgb = frame_bgr[:, :, ::-1]  # BGR->RGB
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
        ts_ms = int((time.time() - self._start) * 1000)

        result = self._landmarker.detect_for_video(mp_image, ts_ms)
        have_face = bool(result.face_landmarks and len(result.face_landmarks) > 0)

        if not have_face:
            return FaceSignals(False, None, None, None, None, None)

        face_lms = result.face_landmarks[0]
        left_eye = np.array([self._get_xy(face_lms, i, w, h) for i in LEFT_EYE_IDX], dtype=np.float32)
        right_eye = np.array([self._get_xy(face_lms, i, w, h) for i in RIGHT_EYE_IDX], dtype=np.float32)
        mouth = np.array([self._get_xy(face_lms, i, w, h) for i in MOUTH_IDX], dtype=np.float32)

        ear = (eye_aspect_ratio(left_eye) + eye_aspect_ratio(right_eye)) / 2.0
        mar = mouth_aspect_ratio(mouth)

        return FaceSignals(True, float(ear), float(mar), left_eye, right_eye, mouth)