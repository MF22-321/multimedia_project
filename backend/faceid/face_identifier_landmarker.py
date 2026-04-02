import cv2
import json
import time
import numpy as np
from pathlib import Path
from typing import Optional, Tuple, Deque, List
from collections import deque, Counter
import mediapipe as mp

MODELS_DIR = Path("models")
MODEL_PATH = MODELS_DIR / "lbph_model.yml"
LABELS_PATH = MODELS_DIR / "labels.json"
LANDMARKER_PATH = MODELS_DIR / "face_landmarker.task"

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

class FaceIdentifierLandmarker:
    """
    FaceID with:
      - Face bbox from MediaPipe Face Landmarker
      - Identity from LBPH
      - Voting window stabilizer for automotive-friendly output
    """

    def __init__(
        self,
        conf_threshold: float = 0.50,         # you found 0.30 works; ok for prototype
        min_face_px: int = 120,
        vote_window_sec: float = 1.5,         # duration of history used for voting
        vote_min_ratio: float = 0.60,         # winner must occupy >= 60% votes
        vote_min_samples: int = 6             # need enough samples before deciding
    ):
        if not MODEL_PATH.exists():
            raise FileNotFoundError(f"LBPH model not found: {MODEL_PATH}")
        if not LABELS_PATH.exists():
            raise FileNotFoundError(f"Labels not found: {LABELS_PATH}")
        if not LANDMARKER_PATH.exists():
            raise FileNotFoundError(f"Landmarker not found: {LANDMARKER_PATH}")

        labels_map = json.loads(LABELS_PATH.read_text(encoding="utf-8"))  # driver_id -> int
        self.id_to_name = {int(v): k for k, v in labels_map.items()}

        self.recognizer = cv2.face.LBPHFaceRecognizer_create()
        self.recognizer.read(str(MODEL_PATH))

        # MediaPipe Face Landmarker
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

        # params
        self.conf_threshold = conf_threshold
        self.min_face_px = min_face_px

        # voting
        self.vote_window_sec = vote_window_sec
        self.vote_min_ratio = vote_min_ratio
        self.vote_min_samples = vote_min_samples
        self._history: Deque[Tuple[float, Optional[str]]] = deque()  # (timestamp, name/None)

        # last outputs
        self.last_raw_name: Optional[str] = None
        self.last_raw_conf: float = 0.0
        self.last_bbox: Optional[Tuple[int, int, int, int]] = None

    def close(self):
        if self._landmarker:
            self._landmarker.close()
            self._landmarker = None

    def _raw_identify(self, frame_bgr) -> Tuple[Optional[str], float, Optional[Tuple[int,int,int,int]]]:
        h, w = frame_bgr.shape[:2]
        rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)

        ts_ms = int((time.time() - self._start_time) * 1000)
        result = self._landmarker.detect_for_video(mp_image, ts_ms)

        have_face = result.face_landmarks and len(result.face_landmarks) > 0
        if not have_face:
            return None, 0.0, None

        face_lms = result.face_landmarks[0]
        x, y, bw, bh = landmarks_to_bbox(face_lms, w, h, pad=0.20)
        if bw <= 0 or bh <= 0:
            return None, 0.0, None

        bbox = (x, y, bw, bh)

        if bw < self.min_face_px:
            return None, 0.0, bbox

        crop = frame_bgr[y:y+bh, x:x+bw]
        gray = cv2.cvtColor(crop, cv2.COLOR_BGR2GRAY)
        roi = cv2.resize(gray, (200, 200))

        label, dist = self.recognizer.predict(roi)

        # heuristic: dist kecil -> confidence tinggi
        conf = float(np.exp(-dist / 50.0))
        name = self.id_to_name.get(int(label), None)

        if name is None or conf < self.conf_threshold:
            return None, conf, bbox

        return name, conf, bbox

    def _update_history(self, now: float, name: Optional[str]):
        self._history.append((now, name))
        # purge older than window
        cutoff = now - self.vote_window_sec
        while self._history and self._history[0][0] < cutoff:
            self._history.popleft()

    def get_stable_driver(self) -> Tuple[Optional[str], float, int]:
        """
        Returns (stable_name or None, win_ratio, total_samples_in_window)
        """
        if len(self._history) < self.vote_min_samples:
            return None, 0.0, len(self._history)

        names: List[Optional[str]] = [n for _, n in self._history if n is not None]
        if not names:
            return None, 0.0, len(self._history)

        c = Counter(names)
        winner, win_count = c.most_common(1)[0]
        total = len(self._history)
        ratio = win_count / max(1, total)

        if ratio >= self.vote_min_ratio:
            return winner, ratio, total
        return None, ratio, total

    def step(self, frame_bgr) -> Tuple[Optional[str], float, Optional[Tuple[int,int,int,int]]]:
        """
        Call this each frame.
        Returns:
          stable_driver_id (or None), stable_ratio, bbox
        Also updates last_raw_name/last_raw_conf.
        """
        raw_name, raw_conf, bbox = self._raw_identify(frame_bgr)

        self.last_raw_name = raw_name
        self.last_raw_conf = raw_conf
        self.last_bbox = bbox

        now = time.time()
        self._update_history(now, raw_name)

        stable_name, ratio, _n = self.get_stable_driver()
        return stable_name, ratio, bbox