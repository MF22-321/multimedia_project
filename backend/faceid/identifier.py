import json
from typing import Optional, Tuple
from .config import LABELS_PATH, CONF_THRESHOLD, MIN_FACE_PX
from .landmarker_bbox import LandmarkerFaceCropper
from .lbph_model import load_lbph, lbph_conf_from_dist
from .stabilizer import VoteStabilizer

class FaceID:
    def __init__(self,
                 conf_threshold: float = CONF_THRESHOLD,
                 min_face_px: int = MIN_FACE_PX,
                 vote_window_sec: float = 1.5,
                 vote_min_ratio: float = 0.6,
                 vote_min_samples: int = 6):
        labels_map = json.loads(LABELS_PATH.read_text(encoding="utf-8"))
        self.id_to_name = {int(v): k for k, v in labels_map.items()}

        self.cropper = LandmarkerFaceCropper()
        self.rec = load_lbph()

        self.conf_threshold = conf_threshold
        self.min_face_px = min_face_px

        self.voter = VoteStabilizer(vote_window_sec, vote_min_ratio, vote_min_samples)

        self.last_raw_name = None
        self.last_raw_conf = 0.0
        self.last_bbox = None

    def close(self):
        self.cropper.close()

    def step(self, frame_bgr) -> Tuple[Optional[str], float, Optional[tuple]]:
        roi, bbox = self.cropper.crop(frame_bgr, min_face_px=self.min_face_px)
        self.last_bbox = bbox

        if roi is None:
            self.last_raw_name = None
            self.last_raw_conf = 0.0
            self.voter.push(None)
            stable, ratio, _ = self.voter.stable()
            return stable, ratio, bbox

        label, dist = self.rec.predict(roi)
        conf = lbph_conf_from_dist(dist)
        name = self.id_to_name.get(int(label), None)

        if name is None or conf < self.conf_threshold:
            name = None

        self.last_raw_name = name
        self.last_raw_conf = conf

        self.voter.push(name)
        stable, ratio, _ = self.voter.stable()
        return stable, ratio, bbox