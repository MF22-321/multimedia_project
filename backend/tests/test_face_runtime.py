import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import numpy as np

from backend.faceid import enroll_runtime, enrollment, face_identifier_landmarker
from backend.faceid.enroll_runtime import RuntimeEnroller
from backend.faceid.face_identifier_landmarker import FaceIdentifierLandmarker


def lms(x1=0.25, y1=0.25, x2=0.75, y2=0.75):
    return [SimpleNamespace(x=x1, y=y1), SimpleNamespace(x=x2, y=y2)]


def mp_stub(detector):
    return SimpleNamespace(
        Image=lambda **kwargs: kwargs,
        ImageFormat=SimpleNamespace(SRGB="srgb"),
        tasks=SimpleNamespace(
            BaseOptions=lambda **kwargs: kwargs,
            vision=SimpleNamespace(
                FaceLandmarker=SimpleNamespace(
                    create_from_options=MagicMock(return_value=detector)
                ),
                FaceLandmarkerOptions=lambda **kwargs: kwargs,
                RunningMode=SimpleNamespace(VIDEO="video"),
            ),
        ),
    )


class RuntimeEnrollerTests(unittest.TestCase):
    def test_start_update_finish_and_close(self):
        cropper = MagicMock()
        with tempfile.TemporaryDirectory() as tmp, patch.object(
            enroll_runtime, "DATASET_DIR", Path(tmp)
        ), patch.object(
            enroll_runtime, "LandmarkerFaceCropper", return_value=cropper
        ), patch.object(
            enroll_runtime, "load_labels", return_value={"Old": 0}
        ), patch.object(
            enroll_runtime, "ensure_label", return_value=1
        ), patch.object(
            enroll_runtime.time, "time", side_effect=[10.0, 10.5, 12.5]
        ), patch.object(
            enroll_runtime.cv2, "imwrite", return_value=True
        ) as imwrite, patch.object(
            enroll_runtime, "train_lbph", return_value=MagicMock()
        ):
            enroller = RuntimeEnroller(capture_seconds=2, capture_interval=0.2)
            self.assertFalse(enroller.start("  "))
            existing = Path(tmp) / "Driver" / "0000.jpg"
            existing.parent.mkdir()
            existing.touch()
            self.assertTrue(enroller.start(" Driver "))
            self.assertEqual(enroller.driver_id, "Driver")

            cropper.crop.return_value = (np.ones((4, 4)), (1, 2, 3, 4))
            bbox, roi_ok, left, saved = enroller.update(np.zeros((2, 2, 3)))
            self.assertEqual(bbox, (1, 2, 3, 4))
            self.assertTrue(roi_ok)
            self.assertGreater(left, 0)
            self.assertEqual(saved, 2)
            imwrite.assert_called_once()

            cropper.crop.return_value = (None, None)
            _, roi_ok, left, saved = enroller.update(None)
            self.assertFalse(roi_ok)
            self.assertEqual(left, 0)
            self.assertFalse(enroller.active)
            self.assertEqual(saved, 2)
            self.assertTrue(enroller.finish_and_train())
            enroller.close()
            cropper.close.assert_called_once()

    @patch.object(enroll_runtime, "LandmarkerFaceCropper")
    def test_inactive_update_and_finish_loads_labels(self, cropper_cls):
        enroller = RuntimeEnroller()
        self.assertEqual(enroller.update(None), (None, False, 0.0, 0))
        with patch.object(enroll_runtime, "load_labels", return_value={}), patch.object(
            enroll_runtime, "train_lbph", return_value=None
        ):
            self.assertFalse(enroller.finish_and_train())


class InteractiveEnrollmentTests(unittest.TestCase):
    def test_camera_open_failure(self):
        cap = MagicMock()
        cap.isOpened.return_value = False
        with patch.object(enrollment, "load_labels", return_value={}), patch.object(
            enrollment, "ensure_label", return_value=0
        ), patch.object(enrollment.cv2, "VideoCapture", return_value=cap), tempfile.TemporaryDirectory() as tmp, patch.object(
            enrollment, "DATASET_DIR", Path(tmp)
        ):
            self.assertIsNone(enrollment.enroll_driver("Driver"))

    def test_auto_manual_capture_cleanup_and_training(self):
        cap = MagicMock()
        cap.isOpened.return_value = True
        frame = np.zeros((100, 100, 3), dtype=np.uint8)
        cap.read.side_effect = [(True, frame), (True, frame), (True, frame)]
        cropper = MagicMock()
        cropper.crop.return_value = (np.ones((10, 10)), (10, 10, 50, 50))
        with tempfile.TemporaryDirectory() as tmp, patch.object(
            enrollment, "DATASET_DIR", Path(tmp)
        ), patch.object(enrollment, "load_labels", return_value={"Driver": 1}), patch.object(
            enrollment, "ensure_label", return_value=1
        ), patch.object(enrollment.cv2, "VideoCapture", return_value=cap), patch.object(
            enrollment, "LandmarkerFaceCropper", return_value=cropper
        ), patch.object(
            enrollment.time, "time", side_effect=[1.0, 1.0, 2.0, 20.0]
        ), patch.object(
            enrollment.cv2, "waitKey", side_effect=[ord("a"), ord("s"), ord("q")]
        ), patch.object(enrollment.cv2, "flip", side_effect=lambda value, _: value), patch.object(
            enrollment.cv2, "imwrite", return_value=True
        ) as imwrite, patch.object(enrollment.cv2, "putText"), patch.object(
            enrollment.cv2, "rectangle"
        ), patch.object(enrollment.cv2, "imshow"), patch.object(
            enrollment.cv2, "destroyAllWindows"
        ) as destroy, patch.object(
            enrollment, "train_lbph", return_value=MagicMock()
        ):
            enrollment.enroll_driver("Driver", camera_index=0)
        self.assertGreaterEqual(imwrite.call_count, 2)
        cropper.close.assert_called_once()
        cap.release.assert_called_once()
        destroy.assert_called_once()

    def test_no_face_manual_read_failure_and_training_failure(self):
        cap = MagicMock()
        cap.isOpened.return_value = True
        frame = np.zeros((10, 10, 3), dtype=np.uint8)
        cap.read.side_effect = [(True, frame), (False, None)]
        cropper = MagicMock()
        cropper.crop.return_value = (None, None)
        with tempfile.TemporaryDirectory() as tmp, patch.object(
            enrollment, "DATASET_DIR", Path(tmp)
        ), patch.object(enrollment, "load_labels", return_value={}), patch.object(
            enrollment, "ensure_label", return_value=0
        ), patch.object(enrollment.cv2, "VideoCapture", return_value=cap), patch.object(
            enrollment, "LandmarkerFaceCropper", return_value=cropper
        ), patch.object(enrollment.time, "time", return_value=1.0), patch.object(
            enrollment.cv2, "waitKey", return_value=ord("s")
        ), patch.object(enrollment.cv2, "flip", side_effect=lambda value, _: value), patch.object(
            enrollment.cv2, "putText"
        ), patch.object(enrollment.cv2, "imshow"), patch.object(
            enrollment.cv2, "destroyAllWindows"
        ), patch.object(enrollment, "train_lbph", return_value=None):
            enrollment.enroll_driver("Driver")


class LegacyLandmarkerIdentifierTests(unittest.TestCase):
    def test_bbox_init_close_raw_history_stable_and_step(self):
        module = face_identifier_landmarker
        self.assertEqual(module.landmarks_to_bbox(lms(), 200, 100, 0), (50, 25, 100, 50))

        detector = MagicMock()
        rec = MagicMock()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            model = root / "lbph.yml"
            labels = root / "labels.json"
            task = root / "face.task"
            for path in (model, task):
                path.touch()
            labels.write_text('{"Driver": 3}')
            with patch.object(module, "MODEL_PATH", model), patch.object(
                module, "LABELS_PATH", labels
            ), patch.object(module, "LANDMARKER_PATH", task), patch.object(
                module, "mp", mp_stub(detector)
            ), patch.object(
                module.cv2.face, "LBPHFaceRecognizer_create", return_value=rec
            ):
                obj = FaceIdentifierLandmarker(
                    min_face_px=20, vote_min_samples=2, vote_min_ratio=0.5
                )

        frame = np.zeros((100, 200, 3), dtype=np.uint8)
        with patch.object(module, "mp", mp_stub(detector)), patch.object(
            module, "preprocess_face", side_effect=lambda value: value
        ):
            detector.detect_for_video.return_value = SimpleNamespace(face_landmarks=[])
            self.assertEqual(obj._raw_identify(frame), (None, 0.0, None))
            detector.detect_for_video.return_value = SimpleNamespace(
                face_landmarks=[lms(0.5, 0.5, 0.5, 0.5)]
            )
            self.assertEqual(obj._raw_identify(frame), (None, 0.0, None))
            detector.detect_for_video.return_value = SimpleNamespace(
                face_landmarks=[lms(0.4, 0.4, 0.41, 0.41)]
            )
            self.assertIsNone(obj._raw_identify(frame)[0])
            detector.detect_for_video.return_value = SimpleNamespace(face_landmarks=[lms()])
            rec.predict.return_value = (99, 100.0)
            self.assertIsNone(obj._raw_identify(frame)[0])
            rec.predict.return_value = (3, 1.0)
            self.assertEqual(obj._raw_identify(frame)[0], "Driver")

            with patch.object(
                module.time, "time", side_effect=[10.0, 10.0, 10.1, 10.1]
            ):
                first = obj.step(frame)
                second = obj.step(frame)
            self.assertIsNone(first[0])
            self.assertEqual(second[0], "Driver")

        obj._history.clear()
        self.assertEqual(obj.get_stable_driver(), (None, 0.0, 0))
        obj._history.extend([(1.0, None), (1.1, None)])
        self.assertEqual(obj.get_stable_driver(), (None, 0.0, 2))
        obj._history.clear()
        obj._history.extend([(1.0, "A"), (1.1, "B"), (1.2, None)])
        obj.vote_min_ratio = 0.8
        self.assertIsNone(obj.get_stable_driver()[0])
        obj.vote_window_sec = 1.0
        obj._update_history(5.0, "A")
        self.assertEqual(len(obj._history), 1)
        obj.close()
        self.assertIsNone(obj._landmarker)
        obj.close()

    def test_init_missing_files(self):
        module = face_identifier_landmarker
        missing = MagicMock()
        missing.exists.return_value = False
        with patch.object(module, "MODEL_PATH", missing):
            with self.assertRaises(FileNotFoundError):
                FaceIdentifierLandmarker()
        present = MagicMock()
        present.exists.return_value = True
        with patch.object(module, "MODEL_PATH", present), patch.object(
            module, "LABELS_PATH", missing
        ):
            with self.assertRaises(FileNotFoundError):
                FaceIdentifierLandmarker()
        with patch.object(module, "MODEL_PATH", present), patch.object(
            module, "LABELS_PATH", present
        ), patch.object(module, "LANDMARKER_PATH", missing):
            with self.assertRaises(FileNotFoundError):
                FaceIdentifierLandmarker()


if __name__ == "__main__":
    unittest.main()
