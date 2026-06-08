from dataclasses import dataclass
import logging
from typing import Optional

import numpy as np

logger = logging.getLogger(__name__)


def clamp01(value):
    return max(0.0, min(1.0, float(value)))


@dataclass(frozen=True)
class MoodConfig:
    confirm_seconds: float = 7.0
    sad_confirm_seconds: float = 10.0
    neutral_confirm_seconds: float = 2.0


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

        face_width = float(np.linalg.norm(right_face - left_face))
        if face_width <= 0:
            raise ValueError("face width is zero")

        mouth_center_y = float((upper_lip[1] + lower_lip[1]) / 2.0)
        corner_y = float((left_corner[1] + right_corner[1]) / 2.0)
        mouth_open = float(np.linalg.norm(lower_lip - upper_lip) / face_width)

        # MediaPipe image coordinates grow downward on the y axis.
        mouth_curve = (mouth_center_y - corner_y) / face_width

        smile_score = clamp01((mouth_curve - 0.010) / 0.040)
        sadness_score = clamp01((-mouth_curve - 0.014) / 0.036)

        if smile_score >= 0.45 and smile_score >= sadness_score:
            mood = "happy"
            confidence = smile_score
        elif mouth_open < 0.055 and sadness_score >= 0.55:
            mood = "sad"
            confidence = sadness_score
        else:
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

    def step(self, points, now):
        raw = extract_mood_from_landmarks(points)
        raw_mood = raw["mood"]
        if raw_mood == "sad":
            required_sec = self.config.sad_confirm_seconds
        elif raw_mood in ("neutral", "unknown"):
            required_sec = self.config.neutral_confirm_seconds
        else:
            required_sec = self.config.confirm_seconds

        if raw_mood != self.candidate:
            self.candidate = raw_mood
            self.candidate_since = now

        candidate_since = self.candidate_since or now
        elapsed = max(0.0, now - candidate_since)

        if elapsed >= required_sec:
            self.confirmed_mood = raw_mood
            self.confirmed_confidence = raw["mood_confidence"]

        return {
            "mood": self.confirmed_mood,
            "mood_confidence": float(self.confirmed_confidence),
            "raw_mood": raw_mood,
            "mood_candidate": self.candidate,
            "mood_candidate_elapsed": float(elapsed),
            "mood_required_sec": float(required_sec),
            "smile_score": raw["smile_score"],
            "sadness_score": raw["sadness_score"],
        }
