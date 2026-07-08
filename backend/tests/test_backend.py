import unittest
from types import SimpleNamespace
from unittest.mock import patch

import numpy as np
from fastapi import HTTPException

from backend.engine.mood import MoodConfig, MoodTracker
from backend.fastAPI.schemas.drowsiness_schema import StartDrowsinessRequest
from backend.fastAPI.validation import validate_driver_name
from backend.src.drowsy.engine import DrowsinessEngine
from backend.src.drowsy.metrics import eye_aspect_ratio, mouth_aspect_ratio


def drowsy_config(**overrides):
    values = {
        "calib_seconds": 1.0,
        "min_baseline": 0.15,
        "mar_threshold": 0.5,
        "consec_frames_yawn": 2,
        "yawn_cooldown_sec": 0.0,
        "yawn_window_sec": 60.0,
        "yawn_alert_count": 2,
        "use_score": True,
        "eye_low_ratio": 0.8,
        "eye_full_close_ratio": 0.5,
        "closed_eye_ratio": 0.7,
        "closed_eye_ear": 0.2,
        "closed_eye_alert_sec": 2.0,
        "yawn_points_max": 1.0,
        "yawn_points_per_event": 0.5,
        "yawn_decay_per_sec": 0.0,
        "w_eye": 0.55,
        "w_yawn": 0.45,
        "score_alpha": 1.0,
        "score_alert_th": 0.85,
        "alert_hold_sec": 4.0,
        "alert_cooldown_sec": 0.0,
    }
    values.update(overrides)
    return SimpleNamespace(**values)


class DriverNameValidationTests(unittest.TestCase):
    def test_normalizes_valid_name(self):
        self.assertEqual(validate_driver_name("  Febrian Aziz  "), "Febrian Aziz")

    def test_rejects_blank_and_path_traversal(self):
        for value in ("   ", "..", "../outside", "folder/name", "folder\\name"):
            with self.subTest(value=value), self.assertRaises(HTTPException) as raised:
                validate_driver_name(value)
            self.assertEqual(raised.exception.status_code, 400)


class MetricTests(unittest.TestCase):
    def test_eye_and_mouth_aspect_ratio(self):
        points = np.array(
            [[0, 0], [1, 1], [3, 1], [4, 0], [3, -1], [1, -1]],
            dtype=np.float32,
        )
        self.assertAlmostEqual(eye_aspect_ratio(points), 0.5)
        self.assertAlmostEqual(mouth_aspect_ratio(points), 0.5)

    def test_zero_width_returns_zero(self):
        points = np.zeros((6, 2), dtype=np.float32)
        self.assertEqual(eye_aspect_ratio(points), 0.0)
        self.assertEqual(mouth_aspect_ratio(points), 0.0)


class DrowsinessEngineTests(unittest.TestCase):
    def test_calibration_uses_valid_ear_baseline(self):
        engine = DrowsinessEngine(drowsy_config())
        start = engine.calib_start
        engine.step(0.30, 0.1, start + 0.2)
        output = engine.step(0.32, 0.1, start + 1.1)

        self.assertTrue(output.calibrating)
        self.assertFalse(engine.calibrating)
        self.assertAlmostEqual(engine.baseline_ear, 0.31)

    def test_closed_eyes_trigger_and_hold_alert(self):
        engine = DrowsinessEngine(drowsy_config())
        engine.set_profile_baseline(0.30, "PROFILE")

        engine.step(0.10, 0.1, 10.0)
        output = engine.step(0.10, 0.1, 12.1)
        held = engine.step(0.30, 0.1, 13.0)

        self.assertTrue(output.alert_active)
        self.assertEqual(output.alert_reason, "closed_eye")
        self.assertTrue(held.alert_active)

    def test_two_yawns_trigger_alert_rule(self):
        engine = DrowsinessEngine(drowsy_config())
        engine.set_profile_baseline(0.30, "PROFILE")

        for now, mar in ((1.0, 0.6), (1.1, 0.6), (2.0, 0.1), (3.0, 0.6)):
            engine.step(0.30, mar, now)
        output = engine.step(0.30, 0.6, 3.1)

        self.assertTrue(output.alert_active)
        self.assertEqual(output.alert_reason, "yawn")
        self.assertEqual(output.yawn_total, 2)


class MoodTrackerTests(unittest.TestCase):
    def test_requires_stable_candidate_before_confirmation(self):
        tracker = MoodTracker(MoodConfig(
            confirm_seconds=2.0,
            sad_confirm_seconds=2.0,
            neutral_confirm_seconds=1.0,
            high_conf_confirm_seconds=2.0,
            smoothing_alpha=1.0,
        ))
        happy = {
            "mood": "happy",
            "mood_confidence": 0.8,
            "smile_score": 0.8,
            "sadness_score": 0.0,
        }

        with patch("backend.engine.mood.extract_mood_from_landmarks", return_value=happy):
            first = tracker.step(None, 100.0)
            confirmed = tracker.step(None, 102.1)

        self.assertEqual(first["mood"], "unknown")
        self.assertEqual(confirmed["mood"], "happy")


class DrowsinessRouteTests(unittest.TestCase):
    @patch("backend.fastAPI.routes.drowsiness_routes.get_drowsiness_status")
    @patch("backend.fastAPI.routes.drowsiness_routes.start_drowsiness_monitoring")
    def test_start_endpoint_normalizes_name(self, start, get_status):
        from backend.fastAPI.routes.drowsiness_routes import start_drowsiness

        get_status.return_value = {"active": True, "driver_name": "Febrian"}
        response = start_drowsiness(StartDrowsinessRequest(driver_name=" Febrian "))

        start.assert_called_once_with("Febrian")
        self.assertTrue(response.success)
        self.assertTrue(response.active)

    def test_start_endpoint_rejects_blank_name(self):
        from backend.fastAPI.routes.drowsiness_routes import start_drowsiness

        with self.assertRaises(HTTPException) as raised:
            start_drowsiness(StartDrowsinessRequest(driver_name=" "))
        self.assertEqual(raised.exception.status_code, 400)

    def test_initial_timing_matches_runtime_configuration(self):
        from backend.engine import camera_stream

        camera_stream.reset_drowsiness_status(driver_name="QC Driver")
        status = camera_stream.get_drowsiness_status()
        self.addCleanup(camera_stream.reset_drowsiness_status)

        self.assertEqual(status["calib_remaining"], camera_stream.DrowsyConfig.calib_seconds)
        self.assertEqual(status["mood_required_sec"], MoodConfig.confirm_seconds)


class CameraEndpointTests(unittest.TestCase):
    @patch("backend.fastAPI.main.get_latest_frame", return_value=None)
    def test_capture_returns_503_before_camera_is_ready(self, _get_frame):
        from backend.fastAPI.main import capture_face

        response = capture_face()
        self.assertEqual(response.status_code, 503)

    @patch("backend.fastAPI.main.time.sleep")
    @patch("backend.fastAPI.main.cv2.imencode")
    @patch("backend.fastAPI.main.get_latest_frame")
    def test_camera_stream_waits_for_first_frame(self, get_frame, imencode, _sleep):
        from backend.fastAPI.main import generate_frames

        frame = np.zeros((2, 2, 3), dtype=np.uint8)
        get_frame.side_effect = [None, frame]
        imencode.return_value = (True, np.array([1, 2, 3], dtype=np.uint8))

        chunk = next(generate_frames())

        self.assertTrue(chunk.startswith(b"--frame\r\n"))
        self.assertEqual(get_frame.call_count, 2)


if __name__ == "__main__":
    unittest.main()
