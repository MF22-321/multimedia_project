from dataclasses import dataclass
import logging
import os
from typing import Optional

import numpy as np

logger = logging.getLogger(__name__)


def clamp01(value):
    return max(0.0, min(1.0, float(value)))


@dataclass(frozen=True)
class MoodConfig:
    confirm_seconds: float = float(os.getenv("MOOD_HAPPY_CONFIRM_SEC", "3.0"))
    sad_confirm_seconds: float = float(os.getenv("MOOD_SAD_CONFIRM_SEC", "3.0"))
    neutral_confirm_seconds: float = float(os.getenv("MOOD_NEUTRAL_CONFIRM_SEC", "3.0"))
    high_conf_confirm_seconds: float = float(os.getenv("MOOD_HIGH_CONF_CONFIRM_SEC", "3.0"))
    smoothing_alpha: float = float(os.getenv("MOOD_SMOOTHING_ALPHA", "0.35"))


def extract_mood_from_landmarks(points):
    """
    Estimate raw mood from MediaPipe face landmarks.

    This is a lightweight heuristic, not an emotion ML model. It detects
    happy/sad mainly from mouth-corner curvature and normalizes the value by
    face width so the thresholds are less sensitive to camera distance.
    """
    if points is None or len(points) < 455:
        return {
            "mood": "unknown",
            "mood_confidence": 0.0,
            "smile_score": 0.0,
            "sadness_score": 0.0,
        }

    try:
        left_corner = points[61]
        right_corner = points[291]
        upper_lip = points[13]
        lower_lip = points[14]
        left_face = points[234]
        right_face = points[454]
        nose_tip = points[1]
        chin = points[152]

        face_width = float(np.linalg.norm(right_face - left_face))
        face_height = float(np.linalg.norm(chin - nose_tip))
        if face_width <= 0:
            raise ValueError("face width is zero")

        mouth_center_y = float((upper_lip[1] + lower_lip[1]) / 2.0)
        corner_y = float((left_corner[1] + right_corner[1]) / 2.0)
        mouth_open = float(np.linalg.norm(lower_lip - upper_lip) / face_width)
        mouth_width = float(np.linalg.norm(right_corner - left_corner) / face_width)

        # MediaPipe image coordinates grow downward on the y axis.
        mouth_curve = (mouth_center_y - corner_y) / face_width
        vertical_curve = mouth_curve
        if face_height > 0:
            vertical_curve = (mouth_center_y - corner_y) / face_height

        width_smile = clamp01((mouth_width - 0.34) / 0.18)
        curve_smile = clamp01((mouth_curve - 0.004) / 0.034)
        open_penalty = clamp01((mouth_open - 0.090) / 0.090)
        smile_score = clamp01((0.70 * curve_smile + 0.30 * width_smile) * (1.0 - 0.35 * open_penalty))

        curve_sad = clamp01((-mouth_curve - 0.004) / 0.028)
        vertical_sad = clamp01((-vertical_curve - 0.006) / 0.032)
        narrow_mouth = clamp01((0.38 - mouth_width) / 0.16)
        sadness_score = clamp01(
            0.68 * curve_sad + 0.20 * vertical_sad + 0.12 * narrow_mouth
        )

        if smile_score >= 0.36 and smile_score >= sadness_score + 0.08:
            mood = "happy"
            confidence = smile_score
        else:
            # sad mood disabled — treated as neutral
            mood = "neutral"
            confidence = 1.0 - max(smile_score, sadness_score)

        return {
            "mood": mood,
            "mood_confidence": float(confidence),
            "smile_score": float(smile_score),
            "sadness_score": float(sadness_score),
        }
    except Exception as exc:
        logger.exception("[MOOD] extraction error: %s", exc)
        return {
            "mood": "unknown",
            "mood_confidence": 0.0,
            "smile_score": 0.0,
            "sadness_score": 0.0,
        }


class MoodTracker:
    def __init__(self, config: Optional[MoodConfig] = None):
        self.config = config or MoodConfig()
        self.reset()

    def reset(self):
        self.confirmed_mood = "unknown"
        self.confirmed_confidence = 0.0
        self.candidate = "unknown"
        self.candidate_since = None
        self.smile_ema = 0.0
        self.sadness_ema = 0.0

    def step(self, points, now):
        raw = extract_mood_from_landmarks(points)
        alpha = self.config.smoothing_alpha
        self.smile_ema = (1.0 - alpha) * self.smile_ema + alpha * raw["smile_score"]
        self.sadness_ema = (
            (1.0 - alpha) * self.sadness_ema + alpha * raw["sadness_score"]
        )

        raw_mood = raw["mood"]
        raw_confidence = raw["mood_confidence"]

        if self.smile_ema >= 0.36 and self.smile_ema >= self.sadness_ema + 0.08:
            raw_mood = "happy"
            raw_confidence = self.smile_ema
        # sad mood disabled — EMA branch removed

        if raw_mood in ("neutral", "unknown"):
            required_sec = self.config.neutral_confirm_seconds
        else:
            required_sec = self.config.confirm_seconds

        if raw_mood != self.candidate:
            self.candidate = raw_mood
            self.candidate_since = now

        candidate_since = self.candidate_since or now
        elapsed = max(0.0, now - candidate_since)

        if raw_confidence >= 0.75 and raw_mood == "happy":
            required_sec = min(required_sec, self.config.high_conf_confirm_seconds)

        if elapsed >= required_sec:
            self.confirmed_mood = raw_mood
            self.confirmed_confidence = raw_confidence

        return {
            "mood": self.confirmed_mood,
            "mood_confidence": float(self.confirmed_confidence),
            "raw_mood": raw_mood,
            "mood_candidate": self.candidate,
            "mood_candidate_elapsed": float(elapsed),
            "mood_required_sec": float(required_sec),
            "smile_score": float(self.smile_ema),
            "sadness_score": float(self.sadness_ema),
        }
