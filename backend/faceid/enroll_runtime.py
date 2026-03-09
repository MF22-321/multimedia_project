import time
import cv2
from pathlib import Path
from typing import Optional

from .config import DATASET_DIR, FACE_SIZE, MIN_FACE_PX
from .landmarker_bbox import LandmarkerFaceCropper
from .labels_store import load_labels, ensure_label
from .lbph_model import train_lbph

class RuntimeEnroller:
    """
    Enrollment runtime:
    - capture face ROI otomatis selama N detik (interval sekian)
    - save ke dataset/<driver_id>/*.jpg
    - update labels.json
    - retrain LBPH model
    """

    def __init__(
        self,
        capture_seconds: float = 8.0,
        capture_interval: float = 0.25,
        min_face_px: int = MIN_FACE_PX,
    ):
        self.capture_seconds = float(capture_seconds)
        self.capture_interval = float(capture_interval)
        self.min_face_px = int(min_face_px)

        self.cropper = LandmarkerFaceCropper()

        self.active = False
        self.driver_id: Optional[str] = None
        self.label_id: Optional[int] = None

        self.out_dir: Optional[Path] = None
        self._end_time = 0.0
        self._last_save = 0.0
        self._count_saved = 0

        self._labels = None

    def close(self):
        self.cropper.close()

    def start(self, driver_id: str) -> bool:
        driver_id = driver_id.strip()
        if not driver_id:
            return False

        DATASET_DIR.mkdir(parents=True, exist_ok=True)

        labels = load_labels()
        label_id = ensure_label(labels, driver_id)

        out_dir = DATASET_DIR / driver_id
        out_dir.mkdir(parents=True, exist_ok=True)

        # start counting from existing files (avoid overwrite)
        existing = sorted(out_dir.glob("*.jpg"))
        start_idx = len(existing)

        self.active = True
        self.driver_id = driver_id
        self.label_id = label_id
        self.out_dir = out_dir

        self._end_time = time.time() + self.capture_seconds
        self._last_save = 0.0
        self._count_saved = start_idx
        self._labels = labels
        return True

    def update(self, frame_bgr):
        """
        Call every frame during enrollment.
        Returns: (bbox, roi_ok, seconds_left, saved_count)
        """
        if not self.active:
            return None, False, 0.0, 0

        now = time.time()
        secs_left = max(0.0, self._end_time - now)

        roi, bbox = self.cropper.crop(frame_bgr, min_face_px=self.min_face_px)
        roi_ok = roi is not None

        if roi_ok and (now - self._last_save) >= self.capture_interval:
            assert self.out_dir is not None
            out_path = self.out_dir / f"{self._count_saved:04d}.jpg"
            cv2.imwrite(str(out_path), roi)  # roi already grayscale 200x200
            self._count_saved += 1
            self._last_save = now

        # auto stop when time ends
        if now >= self._end_time:
            self.active = False

        return bbox, roi_ok, secs_left, self._count_saved

    def finish_and_train(self) -> bool:
        """
        Call after enrollment ends.
        Retrain LBPH model using all dataset.
        """
        if self._labels is None:
            self._labels = load_labels()

        rec = train_lbph(self._labels)
        return rec is not None