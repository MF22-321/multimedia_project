from typing import Optional, Tuple

from .config import (
    CONF_THRESHOLD,
    MIN_FACE_PX,
    RECOGNIZER_MODE,
    REQUIRE_LIVENESS,
)
from .embedding_model import EmbeddingRecognizer
from .landmarker_bbox import LandmarkerFaceCropper
from .lbph_model import lbph_conf_from_dist, load_lbph
from .labels_store import load_labels
from .sface_model import FaceObservation, SFaceRecognizer, TemporalLiveness
from .stabilizer import VoteStabilizer


class FaceID:
    def __init__(
        self,
        conf_threshold: float = CONF_THRESHOLD,
        min_face_px: int = MIN_FACE_PX,
        vote_window_sec: float = 1.5,
        vote_min_ratio: float = 0.6,
        vote_min_samples: int = 6,
        recognizer_mode: str = RECOGNIZER_MODE,
        require_liveness: bool = REQUIRE_LIVENESS,
    ):
        labels_map = load_labels()
        self.id_to_name = {int(value): name for name, value in labels_map.items()}
        self.cropper = LandmarkerFaceCropper()
        self.recognizer_mode = recognizer_mode.strip().lower()
        self.require_liveness = bool(require_liveness)
        self.rec = None
        self.embedding_rec = None
        self.sface_rec = None

        if self.recognizer_mode == "sface":
            try:
                self.sface_rec = SFaceRecognizer()
            except FileNotFoundError:
                self.sface_rec = None
        elif self.recognizer_mode == "arcface":
            try:
                self.embedding_rec = EmbeddingRecognizer()
            except FileNotFoundError:
                self.embedding_rec = None
            try:
                self.rec = load_lbph()
            except FileNotFoundError:
                self.rec = None
        else:
            self.recognizer_mode = "lbph"
            try:
                self.rec = load_lbph()
            except FileNotFoundError:
                self.rec = None

        self.conf_threshold = conf_threshold
        self.min_face_px = min_face_px
        self.voter = VoteStabilizer(
            vote_window_sec,
            vote_min_ratio,
            vote_min_samples,
        )
        self.liveness = TemporalLiveness()

        self.last_raw_name = None
        self.last_raw_conf = 0.0
        self.last_bbox = None
        self.last_diagnostics = {
            "model": self.recognizer_mode,
            "reason": "initializing",
            "quality": None,
            "liveness_passed": False,
            "liveness_score": 0.0,
            "second_score": -1.0,
            "score_margin": 0.0,
            "adaptive_update_available": False,
        }
        self._adaptive_candidate: Optional[tuple[str, FaceObservation, float]] = None

    def close(self):
        self.cropper.close()

    def capture_observation(self, frame_bgr) -> Optional[FaceObservation]:
        if self.sface_rec is None:
            return None
        return self.sface_rec.engine.observe(
            frame_bgr,
            require_quality=True,
            min_face_px=self.min_face_px,
        )

    def adaptive_status(self) -> dict:
        if self._adaptive_candidate is None:
            return {"available": False}
        name, observation, confidence = self._adaptive_candidate
        return {
            "available": True,
            "driver_name": name,
            "confidence": confidence,
            "condition": observation.quality.condition,
            "quality": observation.quality.to_dict(),
        }

    def approve_adaptive_update(self) -> dict:
        if self._adaptive_candidate is None or self.sface_rec is None:
            return {"success": False, "message": "No adaptive update candidate"}
        name, observation, confidence = self._adaptive_candidate
        added = self.sface_rec.store.add_template(
            name,
            observation.embedding,
            observation.quality.condition,
            observation.quality.to_dict(),
            adaptive=True,
        )
        if added:
            self.sface_rec.store.save()
        self._adaptive_candidate = None
        return {
            "success": added,
            "message": "Face template updated" if added else "Template already covered",
            "driver_name": name,
            "confidence": confidence,
        }

    def reject_adaptive_update(self) -> dict:
        available = self._adaptive_candidate is not None
        self._adaptive_candidate = None
        return {"success": available, "message": "Adaptive candidate discarded"}

    def _set_result(
        self,
        name: Optional[str],
        confidence: float,
        bbox: Optional[tuple],
        reason: str,
        *,
        quality=None,
        liveness_passed: bool = False,
        liveness_score: float = 0.0,
        second_score: float = -1.0,
        score_margin: float = 0.0,
    ) -> Tuple[Optional[str], float, Optional[tuple]]:
        self.last_raw_name = name
        self.last_raw_conf = float(confidence)
        self.last_bbox = bbox
        self.voter.push(name)
        stable, ratio, _ = self.voter.stable()
        self.last_diagnostics = {
            "model": self.recognizer_mode,
            "reason": reason,
            "quality": quality,
            "liveness_passed": liveness_passed,
            "liveness_score": float(liveness_score),
            "second_score": float(second_score),
            "score_margin": float(score_margin),
            "adaptive_update_available": self._adaptive_candidate is not None,
        }
        return stable, ratio, bbox

    def _step_sface(self, frame_bgr):
        if self.sface_rec is None:
            return self._set_result(None, 0.0, None, "model_unavailable")

        observation, match = self.sface_rec.predict_frame(frame_bgr)
        bbox = observation.bbox if observation is not None else None
        quality = observation.quality.to_dict() if observation is not None else None
        live, live_score = self.liveness.update(observation)
        name = match.name
        reason = match.reason
        if name is not None and self.require_liveness and not live:
            name = None
            reason = "liveness_pending"

        if (
            name is not None
            and observation is not None
            and live
            and self.sface_rec.adaptive_candidate(name, observation, match.score)
        ):
            self._adaptive_candidate = (name, observation, match.score)

        return self._set_result(
            name,
            match.score,
            bbox,
            reason,
            quality=quality,
            liveness_passed=live,
            liveness_score=live_score,
            second_score=match.second_score,
            score_margin=match.margin,
        )

    def _step_legacy(self, frame_bgr):
        roi, bbox = self.cropper.crop(frame_bgr, min_face_px=self.min_face_px)
        if roi is None:
            return self._set_result(None, 0.0, bbox, "no_face")
        if self.embedding_rec is None and (self.rec is None or not self.id_to_name):
            return self._set_result(None, 0.0, bbox, "model_unavailable")

        name = None
        confidence = 0.0
        if self.embedding_rec is not None:
            crop_bgr, _ = self.cropper.crop_color(
                frame_bgr,
                min_face_px=self.min_face_px,
            )
            if crop_bgr is not None:
                name, confidence = self.embedding_rec.predict(crop_bgr)

        # ArcFace fallback is retained only in explicit `arcface` rollback mode.
        if name is None and self.rec is not None and self.id_to_name:
            label, distance = self.rec.predict(roi)
            confidence = lbph_conf_from_dist(distance)
            name = self.id_to_name.get(int(label))
        if name is None or confidence < self.conf_threshold:
            name = None
        return self._set_result(
            name,
            confidence,
            bbox,
            "matched" if name is not None else "below_threshold",
        )

    def step(self, frame_bgr) -> Tuple[Optional[str], float, Optional[tuple]]:
        if self.recognizer_mode == "sface":
            return self._step_sface(frame_bgr)
        return self._step_legacy(frame_bgr)
