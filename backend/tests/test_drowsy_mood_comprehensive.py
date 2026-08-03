import unittest
from types import SimpleNamespace
from unittest.mock import patch

import numpy as np

from backend.engine import mood
from backend.engine.mood import MoodConfig, MoodTracker, extract_mood_from_landmarks
from backend.src.drowsy.engine import DrowsinessEngine
from backend.src.drowsy.metrics import clamp, euclidean
from backend.tests.test_backend import drowsy_config


def mood_points(curve=0.03, mouth_width=0.5, mouth_open=0.02):
    points = np.zeros((455, 2), dtype=np.float32)
    points[234] = [0.0, 0.0]
    points[454] = [1.0, 0.0]
    points[1] = [0.5, 0.0]
    points[152] = [0.5, 1.0]
    center_y = 0.5
    points[13] = [0.5, center_y - mouth_open / 2]
    points[14] = [0.5, center_y + mouth_open / 2]
    corner_y = center_y - curve
    points[61] = [0.5 - mouth_width / 2, corner_y]
    points[291] = [0.5 + mouth_width / 2, corner_y]
    return points


class MoodExtractionTests(unittest.TestCase):
    def test_clamp_and_unknown_inputs(self):
        self.assertEqual(mood.clamp01(-1), 0.0)
        self.assertEqual(mood.clamp01(2), 1.0)
        self.assertEqual(mood.clamp01(0.4), 0.4)
        for points in (None, np.zeros((20, 2))):
            result = extract_mood_from_landmarks(points)
            self.assertEqual(result["mood"], "unknown")

    def test_happy_neutral_and_extraction_exception(self):
        happy = extract_mood_from_landmarks(mood_points(curve=0.04, mouth_width=0.55))
        self.assertEqual(happy["mood"], "happy")
        self.assertGreater(happy["mood_confidence"], 0.36)

        neutral = extract_mood_from_landmarks(
            mood_points(curve=-0.03, mouth_width=0.25)
        )
        self.assertEqual(neutral["mood"], "neutral")
        self.assertGreater(neutral["sadness_score"], 0)

        broken = mood_points()
        broken[454] = broken[234]
        self.assertEqual(extract_mood_from_landmarks(broken)["mood"], "unknown")


class MoodTrackerComprehensiveTests(unittest.TestCase):
    def config(self, **overrides):
        values = dict(
            confirm_seconds=2.0,
            sad_confirm_seconds=3.0,
            neutral_confirm_seconds=1.0,
            high_conf_confirm_seconds=0.5,
            smoothing_alpha=1.0,
        )
        values.update(overrides)
        return MoodConfig(**values)

    def test_candidate_switch_high_conf_neutral_confirmation_and_reset(self):
        tracker = MoodTracker(self.config())
        happy = {
            "mood": "happy",
            "mood_confidence": 0.9,
            "smile_score": 0.9,
            "sadness_score": 0.0,
        }
        neutral = {
            "mood": "neutral",
            "mood_confidence": 0.6,
            "smile_score": 0.0,
            "sadness_score": 0.1,
        }
        with patch.object(mood, "extract_mood_from_landmarks", side_effect=[happy, happy, neutral, neutral]):
            first = tracker.step(None, 10.0)
            confirmed = tracker.step(None, 10.6)
            switched = tracker.step(None, 11.0)
            neutral_confirmed = tracker.step(None, 12.1)
        self.assertEqual(first["mood_required_sec"], 0.5)
        self.assertEqual(confirmed["mood"], "happy")
        self.assertEqual(switched["mood_candidate"], "neutral")
        self.assertEqual(neutral_confirmed["mood"], "neutral")
        tracker.reset()
        self.assertEqual(tracker.confirmed_mood, "unknown")
        self.assertIsNone(tracker.candidate_since)

    def test_ema_can_promote_raw_unknown_to_happy_and_negative_elapsed_clamps(self):
        tracker = MoodTracker(self.config(smoothing_alpha=0.5))
        raw = {
            "mood": "unknown",
            "mood_confidence": 0.0,
            "smile_score": 1.0,
            "sadness_score": 0.0,
        }
        with patch.object(mood, "extract_mood_from_landmarks", return_value=raw):
            result = tracker.step(None, 5.0)
            tracker.candidate_since = 10.0
            result = tracker.step(None, 6.0)
        self.assertEqual(result["raw_mood"], "happy")
        self.assertEqual(result["mood_candidate_elapsed"], 0.0)


class DrowsinessComprehensiveTests(unittest.TestCase):
    def test_calibration_median_restart_and_start_calibration(self):
        engine = DrowsinessEngine(drowsy_config())
        start = engine.calib_start
        for i in range(10):
            engine.step(0.30 + i * 0.001, 0.1, start + i * 0.05)
        engine.step(0.31, 0.1, start + 1.1)
        self.assertFalse(engine.calibrating)
        self.assertGreater(engine.baseline_ear, 0.30)

        engine.start_calibration("RETRY")
        retry_start = engine.calib_start
        result = engine.step(None, None, retry_start + 2.0)
        self.assertTrue(engine.calibrating)
        self.assertEqual(engine.calib_start, retry_start + 2.0)
        self.assertEqual(result.calib_remaining, 0.0)

        result = engine.step(0.01, None, engine.calib_start + 2.0)
        self.assertTrue(result.calibrating)
        self.assertIsNone(engine.baseline_ear)

    def test_score_interpolation_decay_cooldown_and_expiry(self):
        cfg = drowsy_config(
            score_alert_th=0.2,
            alert_cooldown_sec=10.0,
            alert_hold_sec=1.0,
            closed_eye_alert_sec=99.0,
            yawn_points_per_event=1.0,
            yawn_decay_per_sec=0.1,
        )
        engine = DrowsinessEngine(cfg)
        engine.set_profile_baseline(0.30, "PROFILE")

        open_result = engine.step(0.30, None, 1.0)
        self.assertEqual(open_result.eye_score, 0.0)
        mid = engine.step(0.195, 0.1, 2.0)
        self.assertGreater(mid.eye_score, 0.0)
        self.assertLess(mid.eye_score, 1.0)

        engine.step(0.30, 0.6, 3.0)
        alert = engine.step(0.30, 0.6, 3.1)
        self.assertTrue(alert.alert_active)
        self.assertEqual(alert.alert_reason, "score")
        points_before = engine.yawn_points
        held = engine.step(0.30, 0.1, 3.5)
        self.assertLess(engine.yawn_points, points_before)
        self.assertTrue(held.alert_active)
        expired = engine.step(0.30, 0.1, 5.0)
        self.assertFalse(expired.alert_active)
        self.assertIsNone(expired.alert_reason)

        engine.eye_closed_since = None
        first_closed = engine.step(0.1, 0.1, 6.0)
        self.assertEqual(first_closed.eye_closed_elapsed, 0.0)
        cooldown = engine.step(0.1, 0.1, 106.0)
        self.assertTrue(cooldown.alert_active)

    def test_score_disabled_absolute_closed_eye_and_helpers(self):
        engine = DrowsinessEngine(
            drowsy_config(use_score=False, closed_eye_alert_sec=1.0)
        )
        engine.set_profile_baseline(0.30, "PROFILE")
        engine.step(0.19, None, 1.0)
        result = engine.step(0.19, None, 2.1)
        self.assertTrue(result.alert_active)
        self.assertEqual(result.score, 0.0)
        self.assertEqual(clamp(-2), 0.0)
        self.assertEqual(clamp(2), 1.0)
        self.assertAlmostEqual(euclidean(np.array([0, 0]), np.array([3, 4])), 5.0)


if __name__ == "__main__":
    unittest.main()
