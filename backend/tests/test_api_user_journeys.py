import asyncio
import tempfile
import unittest
from contextlib import ExitStack
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock, call, patch

import numpy as np
from fastapi import BackgroundTasks, HTTPException

from backend.fastAPI import main
from backend.fastAPI.routes import drowsiness_routes
from backend.fastAPI.schemas.drowsiness_schema import StartDrowsinessRequest


class FakeUpload:
    def __init__(self, data=b"jpeg-data"):
        self.filename = "capture.jpg"
        self.data = data

    async def read(self):
        return self.data


def upload(data=b"jpeg-data"):
    return FakeUpload(data)


def recognizer(*, raw_name=None, raw_conf=0.0, bbox=None, roi=None):
    cropper = SimpleNamespace(crop_color=Mock(return_value=(roi, bbox)))
    return SimpleNamespace(
        cropper=cropper,
        capture_observation=Mock(return_value=None),
        last_raw_name=raw_name,
        last_raw_conf=raw_conf,
        last_bbox=bbox,
        last_diagnostics={"model": "test", "reason": "test"},
        step=Mock(return_value=(raw_name, 0.8, bbox)),
    )


class TemporaryPathTestCase(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.temp_path = Path(self.temporary_directory.name)

    def tearDown(self):
        self.temporary_directory.cleanup()


class DriverDirectoryJourneyTests(TemporaryPathTestCase):
    def test_backend_health_check(self):
        self.assertEqual(
            main.root(),
            {"message": "FaceID backend is running"},
        )

    def test_registered_drivers_are_listed(self):
        (self.temp_path / "Alya").mkdir()
        (self.temp_path / "Budi").mkdir()
        (self.temp_path / "not-a-driver.txt").write_text(
            "ignored", encoding="utf-8"
        )

        with patch.object(main, "DATASET_DIR", self.temp_path):
            result = main.get_drivers()

        self.assertEqual(sorted(result["drivers"]), ["Alya", "Budi"])

    def test_delete_unknown_driver_is_safe(self):
        with (
            patch.object(main, "DATASET_DIR", self.temp_path),
            patch.object(main, "PROFILES_DIR", self.temp_path / "profiles"),
            patch.object(main, "load_labels", return_value={}),
        ):
            result = main.delete_driver("Nobody", BackgroundTasks())

        self.assertEqual(
            result,
            {"success": False, "message": "Driver not found"},
        )

    def test_delete_driver_removes_all_identity_artifacts(self):
        dataset = self.temp_path / "dataset"
        profiles = self.temp_path / "profiles"
        dataset.mkdir()
        profiles.mkdir()
        driver_dir = dataset / "Alya"
        driver_dir.mkdir()
        (driver_dir / "0000.jpg").write_bytes(b"face")
        profile = profiles / "Alya.json"
        profile.write_text("{}", encoding="utf-8")
        labels = {"Alya": 7, "Budi": 8}
        remove_label = Mock(
            side_effect=lambda values, name: values.pop(name, None) is not None
        )

        patches = (
            patch.object(main, "DATASET_DIR", dataset),
            patch.object(main, "PROFILES_DIR", profiles),
            patch.object(main, "load_labels", return_value=labels),
            patch.object(main, "remove_label", remove_label),
            patch.object(main, "train_lbph", return_value=object()),
            patch.object(main, "reload_faceid"),
            patch.object(main, "reload_recognizer"),
            patch.object(main, "clear_driver_status"),
            patch.object(main, "stop_drowsiness_monitoring"),
        )
        with ExitStack() as stack:
            for context in patches:
                stack.enter_context(context)
            tasks = BackgroundTasks()
            result = main.delete_driver("alya", tasks)

        self.assertTrue(result["success"])
        self.assertEqual(result["driver_name"], "Alya")
        self.assertFalse(driver_dir.exists())
        self.assertFalse(profile.exists())
        self.assertNotIn("Alya", labels)
        self.assertEqual(len(tasks.tasks), 1)


class FaceRegistrationJourneyTests(TemporaryPathTestCase):
    def test_single_photo_enrollment_succeeds(self):
        roi = np.ones((100, 100, 3), dtype=np.uint8)
        face_recognizer = recognizer(roi=roi, bbox=(1, 2, 100, 100))
        labels = {}
        write_image = Mock(return_value=True)
        ensure = Mock(side_effect=lambda values, name: values.setdefault(name, 11))

        patches = (
            patch.object(main, "DATASET_DIR", self.temp_path),
            patch.object(main, "decode_image", return_value=roi),
            patch.object(main, "get_faceid", return_value=face_recognizer),
            patch.object(main.cv2, "imwrite", write_image),
            patch.object(main, "load_labels", return_value=labels),
            patch.object(main, "ensure_label", ensure),
            patch.object(main, "train_lbph", return_value=object()),
            patch.object(main, "build_sface_templates", return_value=True),
            patch.object(main, "reload_faceid"),
            patch.object(main, "reload_recognizer"),
        )
        with ExitStack() as stack:
            for context in patches:
                stack.enter_context(context)
            tasks = BackgroundTasks()
            result = asyncio.run(main.enroll(tasks, "  Alya  ", upload()))

        self.assertTrue(result["success"])
        self.assertEqual(result["driver_name"], "Alya")
        self.assertEqual(result["label_id"], 11)
        self.assertFalse(result["embeddings_building"])
        self.assertTrue(write_image.call_args.args[0].endswith("Alya/0000.jpg"))
        self.assertEqual(len(tasks.tasks), 0)

    def test_single_photo_enrollment_rejects_bad_input(self):
        cases = (
            (None, None, True, "Invalid image"),
            (np.zeros((2, 2, 3)), None, True, "No face detected"),
            (
                np.zeros((2, 2, 3)),
                np.ones((100, 100, 3)),
                False,
                "Failed to save",
            ),
        )
        for frame, roi, write_ok, expected in cases:
            with self.subTest(expected=expected):
                patches = (
                    patch.object(main, "DATASET_DIR", self.temp_path),
                    patch.object(main, "decode_image", return_value=frame),
                    patch.object(main, "get_faceid", return_value=recognizer(roi=roi)),
                    patch.object(main.cv2, "imwrite", return_value=write_ok),
                )
                with ExitStack() as stack:
                    for context in patches:
                        stack.enter_context(context)
                    result = asyncio.run(
                        main.enroll(BackgroundTasks(), "Alya", upload())
                    )

                self.assertFalse(result["success"])
                self.assertIn(expected, result["message"])

    def test_enrollment_reports_training_failure(self):
        roi = np.ones((100, 100, 3), dtype=np.uint8)
        patches = (
            patch.object(main, "DATASET_DIR", self.temp_path),
            patch.object(main, "decode_image", return_value=roi),
            patch.object(main, "get_faceid", return_value=recognizer(roi=roi)),
            patch.object(main.cv2, "imwrite", return_value=True),
            patch.object(main, "load_labels", return_value={}),
            patch.object(main, "ensure_label", return_value=1),
            patch.object(main, "train_lbph", return_value=None),
            patch.object(main, "build_sface_templates", return_value=False),
        )
        with ExitStack() as stack:
            for context in patches:
                stack.enter_context(context)
            result = asyncio.run(
                main.enroll(BackgroundTasks(), "Alya", upload())
            )

        self.assertFalse(result["success"])
        self.assertIn("SFace template build failed", result["message"])

    def test_live_burst_enrollment_succeeds_and_restores_camera_mode(self):
        active = Mock()
        labels = {}
        patches = (
            patch.object(main, "set_enrollment_active", active),
            patch.object(
                main,
                "save_face_samples_from_live_camera",
                return_value=[f"Alya/{index:04d}.jpg" for index in range(12)],
            ),
            patch.object(main, "load_labels", return_value=labels),
            patch.object(
                main,
                "ensure_label",
                side_effect=lambda values, name: values.setdefault(name, 4),
            ),
            patch.object(main, "train_lbph", return_value=object()),
            patch.object(main, "build_sface_templates", return_value=True),
            patch.object(main, "reload_faceid"),
            patch.object(main, "reload_recognizer"),
        )
        with ExitStack() as stack:
            for context in patches:
                stack.enter_context(context)
            tasks = BackgroundTasks()
            result = asyncio.run(main.enroll_live_burst(tasks, "Alya", 1.0, 2))

        self.assertTrue(result["success"])
        self.assertEqual(result["saved_count"], 12)
        self.assertEqual(len(tasks.tasks), 0)
        self.assertEqual(active.call_args_list, [call(True), call(False)])

    def test_live_burst_without_face_fails_and_restores_camera_mode(self):
        active = Mock()
        with (
            patch.object(main, "set_enrollment_active", active),
            patch.object(main, "load_labels", return_value={}),
            patch.object(
                main, "save_face_samples_from_live_camera", return_value=[]
            ),
        ):
            result = asyncio.run(
                main.enroll_live_burst(BackgroundTasks(), "Alya", 1.0, 2)
            )

        self.assertFalse(result["success"])
        self.assertEqual(result["saved_count"], 0)
        self.assertEqual(active.call_args_list, [call(True), call(False)])


class FaceLoginJourneyTests(unittest.TestCase):
    def test_enrollment_and_adaptive_status_endpoints(self):
        candidate = SimpleNamespace(
            adaptive_status=Mock(return_value={"available": True}),
            approve_adaptive_update=Mock(return_value={"success": True}),
            reject_adaptive_update=Mock(return_value={"success": True}),
        )
        reload_runtime = Mock()
        with patch.object(main, "get_faceid", return_value=candidate), patch.object(
            main, "reload_recognizer", reload_runtime
        ):
            self.assertIn("active", main.enrollment_status())
            self.assertTrue(main.adaptive_candidate_status()["available"])
            self.assertTrue(main.approve_adaptive_candidate()["success"])
            self.assertTrue(main.reject_adaptive_candidate()["success"])
        reload_runtime.assert_called_once()

    def test_failed_adaptive_approval_does_not_reload_runtime(self):
        candidate = SimpleNamespace(
            approve_adaptive_update=Mock(return_value={"success": False})
        )
        reload_runtime = Mock()
        with patch.object(main, "get_faceid", return_value=candidate), patch.object(
            main, "reload_recognizer", reload_runtime
        ):
            self.assertFalse(main.approve_adaptive_candidate()["success"])
        reload_runtime.assert_not_called()

    def test_recognized_face_returns_registered_driver(self):
        frame = np.zeros((10, 10, 3), dtype=np.uint8)
        face_recognizer = recognizer(
            raw_name="Alya",
            raw_conf=0.94,
            bbox=(1, 2, 3, 4),
        )
        with (
            patch.object(main, "decode_image", return_value=frame),
            patch.object(main, "get_faceid", return_value=face_recognizer),
        ):
            result = asyncio.run(main.recognize(upload()))

        self.assertTrue(result["success"])
        self.assertEqual(result["status"], "registered")
        self.assertEqual(result["driver_name"], "Alya")
        self.assertEqual(result["confidence"], 0.94)

    def test_unknown_face_cannot_become_registered_user(self):
        frame = np.zeros((10, 10, 3), dtype=np.uint8)
        with (
            patch.object(main, "decode_image", return_value=frame),
            patch.object(
                main,
                "get_faceid",
                return_value=recognizer(raw_name=None, raw_conf=0.2),
            ),
        ):
            result = asyncio.run(main.recognize(upload()))

        self.assertTrue(result["success"])
        self.assertEqual(result["status"], "unknown")
        self.assertIsNone(result["driver_name"])

    def test_invalid_photo_cannot_login(self):
        with patch.object(main, "decode_image", return_value=None):
            result = asyncio.run(main.recognize(upload(b"not-an-image")))

        self.assertEqual(result, {"success": False, "message": "Invalid image"})


class DrowsinessApiJourneyTests(unittest.TestCase):
    def test_start_status_stop_happy_path(self):
        state = {"active": False, "driver_name": None, "status": "inactive"}

        def start(name):
            state.update(active=True, driver_name=name, status="calibrating")

        def stop():
            state.update(active=False, driver_name=None, status="inactive")

        with (
            patch.object(drowsiness_routes, "start_drowsiness_monitoring", start),
            patch.object(drowsiness_routes, "stop_drowsiness_monitoring", stop),
            patch.object(
                drowsiness_routes,
                "get_drowsiness_status",
                side_effect=lambda: dict(state),
            ),
        ):
            started = drowsiness_routes.start_drowsiness(
                StartDrowsinessRequest(driver_name=" Alya ")
            )
            status = drowsiness_routes.read_drowsiness_status()
            stopped = drowsiness_routes.stop_drowsiness()

        self.assertTrue(started.success)
        self.assertEqual(started.driver_name, "Alya")
        self.assertTrue(status.active)
        self.assertEqual(status.status, "calibrating")
        self.assertTrue(stopped.success)
        self.assertFalse(stopped.active)

    def test_runtime_failures_become_http_500(self):
        cases = (
            (
                "start_drowsiness",
                StartDrowsinessRequest(driver_name="Alya"),
            ),
            ("stop_drowsiness", None),
            ("read_drowsiness_status", None),
        )
        for function_name, argument in cases:
            with self.subTest(function=function_name):
                patches = (
                    patch.object(
                        drowsiness_routes,
                        "start_drowsiness_monitoring",
                        side_effect=RuntimeError("camera failure"),
                    ),
                    patch.object(
                        drowsiness_routes,
                        "stop_drowsiness_monitoring",
                        side_effect=RuntimeError("camera failure"),
                    ),
                    patch.object(
                        drowsiness_routes,
                        "get_drowsiness_status",
                        side_effect=RuntimeError("camera failure"),
                    ),
                )
                with ExitStack() as stack:
                    for context in patches:
                        stack.enter_context(context)
                    function = getattr(drowsiness_routes, function_name)
                    with self.assertRaises(HTTPException) as raised:
                        function(argument) if argument is not None else function()

                self.assertEqual(raised.exception.status_code, 500)
                self.assertIn("camera failure", raised.exception.detail)


if __name__ == "__main__":
    unittest.main()
