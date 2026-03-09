import cv2
import time
from typing import Optional, Tuple
import mediapipe as mp
from .config import LANDMARKER_PATH, FACE_SIZE

def landmarks_to_bbox(face_lms, w, h, pad=0.20):
    xs = [lm.x for lm in face_lms]
    ys = [lm.y for lm in face_lms]
    xmin = max(0.0, min(xs)); xmax = min(1.0, max(xs))
    ymin = max(0.0, min(ys)); ymax = min(1.0, max(ys))
    bw = xmax - xmin; bh = ymax - ymin
    xmin = max(0.0, xmin - pad * bw); ymin = max(0.0, ymin - pad * bh)
    xmax = min(1.0, xmax + pad * bw); ymax = min(1.0, ymax + pad * bh)
    x1 = int(xmin * w); y1 = int(ymin * h)
    x2 = int(xmax * w); y2 = int(ymax * h)
    return x1, y1, max(0, x2 - x1), max(0, y2 - y1)

class LandmarkerFaceCropper:
    def __init__(self):
        if not LANDMARKER_PATH.exists():
            raise FileNotFoundError(f"Landmarker not found: {LANDMARKER_PATH}")

        BaseOptions = mp.tasks.BaseOptions
        FaceLandmarker = mp.tasks.vision.FaceLandmarker
        FaceLandmarkerOptions = mp.tasks.vision.FaceLandmarkerOptions
        VisionRunningMode = mp.tasks.vision.RunningMode

        options = FaceLandmarkerOptions(
            base_options=BaseOptions(model_asset_path=str(LANDMARKER_PATH)),
            running_mode=VisionRunningMode.VIDEO,
            num_faces=1,
            output_face_blendshapes=False,
            output_facial_transformation_matrixes=False,
        )
        self._start_time = time.time()
        self._landmarker = FaceLandmarker.create_from_options(options)

    def close(self):
        if self._landmarker:
            self._landmarker.close()
            self._landmarker = None

    def crop(self, frame_bgr, min_face_px: int = 120
             ) -> Tuple[Optional[any], Optional[Tuple[int,int,int,int]]]:
        """
        Returns: (roi_gray_200x200 or None, bbox or None)
        """
        h, w = frame_bgr.shape[:2]
        rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)

        ts_ms = int((time.time() - self._start_time) * 1000)
        result = self._landmarker.detect_for_video(mp_image, ts_ms)

        if not (result.face_landmarks and len(result.face_landmarks) > 0):
            return None, None

        face_lms = result.face_landmarks[0]
        x, y, bw, bh = landmarks_to_bbox(face_lms, w, h, pad=0.20)
        bbox = (x, y, bw, bh)

        if bw <= 0 or bh <= 0 or bw < min_face_px:
            return None, bbox

        crop = frame_bgr[y:y+bh, x:x+bw]
        gray = cv2.cvtColor(crop, cv2.COLOR_BGR2GRAY)
        roi = cv2.resize(gray, FACE_SIZE)
        return roi, bbox