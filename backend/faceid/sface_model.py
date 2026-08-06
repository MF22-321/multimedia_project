import json
import logging
import time
from collections import deque
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Optional

import cv2
import numpy as np

from .config import (
    ADAPTIVE_MIN_CONFIDENCE,
    DATASET_DIR,
    EMBEDDINGS_PATH,
    ENROLL_TEMPLATE_LIMIT_PER_CONDITION,
    LIVENESS_MIN_MOTION,
    LIVENESS_MIN_SAMPLES,
    LIVENESS_WINDOW_SEC,
    MIN_FACE_PX,
    QUALITY_MAX_ABS_YAW,
    QUALITY_MAX_BRIGHTNESS,
    QUALITY_MIN_BRIGHTNESS,
    QUALITY_MIN_SHARPNESS,
    SFACE_DETECT_THRESHOLD,
    SFACE_DNN_TARGET,
    SFACE_MARGIN,
    SFACE_MODEL_PATH,
    SFACE_THRESHOLD,
    SFACE_TOP_K,
    TEMPLATE_DUPLICATE_SIMILARITY,
    YUNET_MODEL_PATH,
)

logger = logging.getLogger(__name__)


def normalize(vector: np.ndarray) -> np.ndarray:
    value = np.asarray(vector, dtype=np.float32).reshape(-1)
    norm = float(np.linalg.norm(value))
    if norm <= 1e-8:
        return value
    return value / norm


@dataclass
class FaceQuality:
    accepted: bool
    reason: str
    brightness: float
    sharpness: float
    face_size: int
    yaw: float
    condition: str
    detection_score: float

    def to_dict(self) -> dict:
        result = asdict(self)
        result["brightness"] = round(self.brightness, 2)
        result["sharpness"] = round(self.sharpness, 2)
        result["yaw"] = round(self.yaw, 4)
        result["detection_score"] = round(self.detection_score, 4)
        return result


@dataclass
class FaceObservation:
    bbox: tuple[int, int, int, int]
    landmarks: np.ndarray
    aligned_face: np.ndarray
    embedding: np.ndarray
    quality: FaceQuality


@dataclass
class MatchResult:
    name: Optional[str]
    score: float
    second_score: float
    margin: float
    reason: str


class SFaceEngine:
    """YuNet detection, five-point alignment and SFace feature extraction."""

    def __init__(
        self,
        detector_path: Path = YUNET_MODEL_PATH,
        recognizer_path: Path = SFACE_MODEL_PATH,
        detect_threshold: float = SFACE_DETECT_THRESHOLD,
        dnn_target: str = SFACE_DNN_TARGET,
    ):
        if not detector_path.exists():
            raise FileNotFoundError(f"YuNet model not found: {detector_path}")
        if not recognizer_path.exists():
            raise FileNotFoundError(f"SFace model not found: {recognizer_path}")

        self.detector_path = Path(detector_path)
        self.recognizer_path = Path(recognizer_path)
        self.detect_threshold = float(detect_threshold)
        self.dnn_target = dnn_target
        backend, target = self._backend_target(dnn_target)
        try:
            self.detector = cv2.FaceDetectorYN.create(
                str(self.detector_path),
                "",
                (320, 320),
                self.detect_threshold,
                0.3,
                5000,
                backend,
                target,
            )
            self.recognizer = cv2.FaceRecognizerSF.create(
                str(self.recognizer_path), "", backend, target
            )
        except cv2.error:
            if dnn_target == "cpu":
                raise
            logger.exception(
                "[SFace] %s backend unavailable; falling back to CPU", dnn_target
            )
            self.dnn_target = "cpu"
            self.detector = cv2.FaceDetectorYN.create(
                str(self.detector_path),
                "",
                (320, 320),
                self.detect_threshold,
                0.3,
                5000,
            )
            self.recognizer = cv2.FaceRecognizerSF.create(
                str(self.recognizer_path), ""
            )

    @staticmethod
    def _backend_target(name: str) -> tuple[int, int]:
        if name == "cuda":
            return cv2.dnn.DNN_BACKEND_CUDA, cv2.dnn.DNN_TARGET_CUDA
        if name in {"cuda_fp16", "cuda-fp16"}:
            return cv2.dnn.DNN_BACKEND_CUDA, cv2.dnn.DNN_TARGET_CUDA_FP16
        return cv2.dnn.DNN_BACKEND_OPENCV, cv2.dnn.DNN_TARGET_CPU

    def detect(self, frame_bgr: np.ndarray) -> Optional[np.ndarray]:
        if frame_bgr is None or frame_bgr.size == 0:
            return None
        height, width = frame_bgr.shape[:2]
        self.detector.setInputSize((width, height))
        faces = self.detector.detect(frame_bgr)[1]
        if faces is None or len(faces) == 0:
            return None
        return max(faces, key=lambda face: float(face[2] * face[3] * face[-1]))

    @staticmethod
    def _pose_and_condition(face: np.ndarray, brightness: float) -> tuple[float, str]:
        right_eye_x = float(face[4])
        left_eye_x = float(face[6])
        nose_x = float(face[8])
        eye_distance = max(abs(left_eye_x - right_eye_x), 1.0)
        yaw = (nose_x - ((right_eye_x + left_eye_x) / 2.0)) / eye_distance
        if yaw <= -0.12:
            return yaw, "left"
        if yaw >= 0.12:
            return yaw, "right"
        if brightness < 85:
            return yaw, "frontal_dim"
        if brightness > 175:
            return yaw, "frontal_bright"
        return yaw, "frontal"

    def observe(
        self,
        frame_bgr: np.ndarray,
        *,
        require_quality: bool = True,
        min_face_px: int = MIN_FACE_PX,
    ) -> Optional[FaceObservation]:
        face = self.detect(frame_bgr)
        if face is None:
            return None

        x, y, width, height = (int(round(value)) for value in face[:4])
        bbox = (x, y, width, height)
        aligned = self.recognizer.alignCrop(frame_bgr, face)
        gray = cv2.cvtColor(aligned, cv2.COLOR_BGR2GRAY)
        brightness = float(gray.mean())
        sharpness = float(cv2.Laplacian(gray, cv2.CV_64F).var())
        yaw, condition = self._pose_and_condition(face, brightness)
        reason = "ok"
        if min(width, height) < int(min_face_px):
            reason = "move_closer"
        elif brightness < QUALITY_MIN_BRIGHTNESS:
            reason = "too_dark"
        elif brightness > QUALITY_MAX_BRIGHTNESS:
            reason = "too_bright"
        elif sharpness < QUALITY_MIN_SHARPNESS:
            reason = "hold_still"
        elif abs(yaw) > QUALITY_MAX_ABS_YAW:
            reason = "face_too_turned"

        quality = FaceQuality(
            accepted=(reason == "ok") or not require_quality,
            reason=reason,
            brightness=brightness,
            sharpness=sharpness,
            face_size=min(width, height),
            yaw=yaw,
            condition=condition,
            detection_score=float(face[-1]),
        )
        feature = self.recognizer.feature(aligned)
        embedding = normalize(feature)
        landmarks = np.asarray(face[4:14], dtype=np.float32).reshape(5, 2)
        return FaceObservation(bbox, landmarks, aligned, embedding, quality)


class SFaceTemplateStore:
    VERSION = 2

    def __init__(
        self,
        path: Path = EMBEDDINGS_PATH,
        threshold: float = SFACE_THRESHOLD,
        margin: float = SFACE_MARGIN,
        top_k: int = SFACE_TOP_K,
    ):
        self.path = Path(path)
        self.threshold = float(threshold)
        self.margin_threshold = float(margin)
        self.top_k = max(1, int(top_k))
        self.identities: dict[str, list[dict]] = {}
        self.load()

    def load(self) -> None:
        self.identities = {}
        if not self.path.exists():
            return
        raw = json.loads(self.path.read_text(encoding="utf-8"))
        if raw.get("version") == self.VERSION:
            source = raw.get("identities", {})
            for name, record in source.items():
                self.identities[name] = list(record.get("templates", []))
            return
        # Legacy ArcFace format: {name: [[vector], ...]}.
        for name, vectors in raw.items():
            if isinstance(vectors, list):
                self.identities[name] = [
                    {"vector": vector, "condition": "legacy", "quality": {}}
                    for vector in vectors
                ]

    def save(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "version": self.VERSION,
            "model": "opencv_sface_2021dec",
            "updated_at": int(time.time()),
            "identities": {
                name: {"templates": templates}
                for name, templates in sorted(self.identities.items())
            },
        }
        temporary = self.path.with_suffix(self.path.suffix + ".tmp")
        temporary.write_text(json.dumps(payload), encoding="utf-8")
        temporary.replace(self.path)

    def add_template(
        self,
        name: str,
        embedding: np.ndarray,
        condition: str,
        quality: Optional[dict] = None,
        *,
        adaptive: bool = False,
    ) -> bool:
        vector = normalize(embedding)
        templates = self.identities.setdefault(name, [])
        same_condition = [
            item for item in templates if item.get("condition") == condition
        ]
        for item in same_condition:
            similarity = float(np.dot(vector, normalize(item["vector"])))
            if similarity >= TEMPLATE_DUPLICATE_SIMILARITY:
                return False
        record = {
            "vector": vector.tolist(),
            "condition": condition,
            "quality": quality or {},
            "adaptive": bool(adaptive),
        }
        templates.append(record)
        matching_indices = [
            index
            for index, item in enumerate(templates)
            if item.get("condition") == condition
        ]
        if len(matching_indices) > ENROLL_TEMPLATE_LIMIT_PER_CONDITION:
            del templates[matching_indices[0]]
        return True

    def remove(self, name: str) -> bool:
        if name not in self.identities:
            return False
        self.identities.pop(name)
        self.save()
        return True

    def predict(self, embedding: np.ndarray) -> MatchResult:
        query = normalize(embedding)
        scores = []
        for name, templates in self.identities.items():
            similarities = sorted(
                (
                    float(np.dot(query, normalize(item["vector"])))
                    for item in templates
                ),
                reverse=True,
            )
            if similarities:
                selected = similarities[: self.top_k]
                scores.append((name, float(np.mean(selected))))
        if not scores:
            return MatchResult(None, 0.0, -1.0, 0.0, "empty_gallery")
        scores.sort(key=lambda item: item[1], reverse=True)
        best_name, best_score = scores[0]
        second_score = scores[1][1] if len(scores) > 1 else -1.0
        score_margin = best_score - second_score if second_score >= 0 else 1.0
        if best_score < self.threshold:
            return MatchResult(
                None, best_score, second_score, score_margin, "below_threshold"
            )
        if second_score >= 0 and score_margin < self.margin_threshold:
            return MatchResult(
                None, best_score, second_score, score_margin, "ambiguous_identity"
            )
        return MatchResult(
            best_name, best_score, second_score, score_margin, "matched"
        )

    def is_novel(self, name: str, embedding: np.ndarray) -> bool:
        templates = self.identities.get(name, [])
        if not templates:
            return True
        vector = normalize(embedding)
        best = max(
            float(np.dot(vector, normalize(item["vector"]))) for item in templates
        )
        return best < TEMPLATE_DUPLICATE_SIMILARITY


class TemporalLiveness:
    def __init__(
        self,
        window_sec: float = LIVENESS_WINDOW_SEC,
        min_samples: int = LIVENESS_MIN_SAMPLES,
        min_motion: float = LIVENESS_MIN_MOTION,
    ):
        self.window_sec = float(window_sec)
        self.min_samples = int(min_samples)
        self.min_motion = float(min_motion)
        self.history = deque()

    def reset(self) -> None:
        self.history.clear()

    def update(self, observation: Optional[FaceObservation]) -> tuple[bool, float]:
        now = time.time()
        cutoff = now - self.window_sec
        while self.history and self.history[0][0] < cutoff:
            self.history.popleft()
        if observation is None:
            return False, 0.0
        x, y, width, height = observation.bbox
        scale = np.array([max(width, 1), max(height, 1)], dtype=np.float32)
        origin = np.array([x, y], dtype=np.float32)
        normalized_landmarks = ((observation.landmarks - origin) / scale).reshape(-1)
        self.history.append((now, normalized_landmarks))
        if len(self.history) < self.min_samples:
            return False, 0.0
        base = self.history[0][1]
        motion = max(
            float(np.linalg.norm(item - base)) for _, item in self.history
        )
        score = min(1.0, motion / max(self.min_motion * 4.0, 1e-8))
        return motion >= self.min_motion, score


class SFaceRecognizer:
    def __init__(
        self,
        engine: Optional[SFaceEngine] = None,
        store: Optional[SFaceTemplateStore] = None,
    ):
        self.engine = engine or SFaceEngine()
        self.store = store or SFaceTemplateStore()

    def predict_frame(
        self, frame_bgr: np.ndarray
    ) -> tuple[Optional[FaceObservation], MatchResult]:
        observation = self.engine.observe(frame_bgr, require_quality=True)
        if observation is None:
            return None, MatchResult(None, 0.0, -1.0, 0.0, "no_face")
        if not observation.quality.accepted:
            return observation, MatchResult(
                None, 0.0, -1.0, 0.0, observation.quality.reason
            )
        return observation, self.store.predict(observation.embedding)

    def adaptive_candidate(
        self, name: str, observation: FaceObservation, confidence: float
    ) -> bool:
        return (
            confidence >= ADAPTIVE_MIN_CONFIDENCE
            and observation.quality.accepted
            and self.store.is_novel(name, observation.embedding)
        )


def build_sface_templates(
    labels_map: dict,
    *,
    dataset_dir: Path = DATASET_DIR,
    output_path: Path = EMBEDDINGS_PATH,
    engine: Optional[SFaceEngine] = None,
) -> bool:
    model = engine or SFaceEngine()
    store = SFaceTemplateStore(path=output_path)
    store.identities = {}
    for name in labels_map:
        folder = Path(dataset_dir) / name
        if not folder.exists():
            continue
        for image_path in sorted(folder.glob("*.jpg")):
            image = cv2.imread(str(image_path), cv2.IMREAD_COLOR)
            if image is None:
                continue
            try:
                observation = model.observe(
                    image, require_quality=False, min_face_px=40
                )
            except Exception as exc:
                logger.warning("[SFace] skip %s: %s", image_path, exc)
                continue
            if observation is None:
                continue
            captured_condition = observation.quality.condition
            for guided_condition in (
                "frontal",
                "left",
                "right",
                "up",
                "down",
                "natural",
            ):
                if image_path.stem.lower().endswith(f"_{guided_condition}"):
                    captured_condition = guided_condition
                    break
            store.add_template(
                name,
                observation.embedding,
                captured_condition,
                observation.quality.to_dict(),
            )
    store.save()
    return any(store.identities.values())
