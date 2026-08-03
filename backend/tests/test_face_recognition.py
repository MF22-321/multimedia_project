import json
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

import numpy as np

from backend.faceid import embedding_model, labels_store, lbph_model, profile_manager
from backend.faceid.embedding_model import EmbeddingRecognizer, FaceEmbeddingModel
from backend.faceid.identifier import FaceID
from backend.faceid.landmarker_bbox import LandmarkerFaceCropper
from backend.faceid.stabilizer import VoteStabilizer


def landmarks(x1=0.25, y1=0.25, x2=0.75, y2=0.75):
    return [SimpleNamespace(x=x1, y=y1), SimpleNamespace(x=x2, y=y2)]


def fake_mediapipe(landmarker):
    face_landmarker = SimpleNamespace(
        create_from_options=MagicMock(return_value=landmarker),
    )
    return SimpleNamespace(
        Image=lambda **kwargs: kwargs,
        ImageFormat=SimpleNamespace(SRGB="srgb"),
        tasks=SimpleNamespace(
            BaseOptions=lambda **kwargs: kwargs,
            vision=SimpleNamespace(
                FaceLandmarker=face_landmarker,
                FaceLandmarkerOptions=lambda **kwargs: kwargs,
                RunningMode=SimpleNamespace(VIDEO="video"),
            ),
        ),
    )


class LabelsAndProfilesTests(unittest.TestCase):
    def test_labels_round_trip_remove_and_allocate_gap(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "models" / "labels.json"
            with patch.object(labels_store, "LABELS_PATH", path):
                self.assertEqual(labels_store.load_labels(), {})
                labels_store.save_labels({"A": 0, "C": 2})
                self.assertEqual(labels_store.load_labels(), {"A": 0, "C": 2})
                self.assertEqual(labels_store.ensure_label({"A": 0, "C": 2}, "B"), 1)
                labels = labels_store.load_labels()
                self.assertEqual(labels_store.ensure_label(labels, "A"), 0)
                self.assertFalse(labels_store.remove_label(labels, "missing"))
                self.assertTrue(labels_store.remove_label(labels, "A"))
                self.assertNotIn("A", labels_store.load_labels())

    def test_profile_create_load_save_and_missing(self):
        with tempfile.TemporaryDirectory() as tmp:
            with patch.object(profile_manager, "PROFILES_DIR", Path(tmp)), patch.object(
                profile_manager.time, "strftime", return_value="2026-08-03 00:00:00"
            ):
                self.assertIsNone(profile_manager.load_profile("Driver"))
                profile = profile_manager.get_or_create_profile("Driver")
                self.assertEqual(profile["driver_id"], "Driver")
                profile["baseline_ear"] = 0.31
                profile_manager.save_profile("Driver", profile)
                self.assertEqual(
                    profile_manager.load_profile("Driver")["baseline_ear"], 0.31
                )
                self.assertEqual(
                    profile_manager.get_or_create_profile("Driver")["driver_id"],
                    "Driver",
                )


class StabilizerTests(unittest.TestCase):
    @patch("backend.faceid.stabilizer.time.time", side_effect=[0.0, 0.2, 2.0, 2.1])
    def test_voting_insufficient_empty_winner_and_expiry(self, _time):
        voter = VoteStabilizer(window_sec=1.0, min_ratio=0.6, min_samples=2)
        voter.push(None)
        self.assertEqual(voter.stable(), (None, 0.0, 1))
        voter.push(None)
        self.assertEqual(voter.stable(), (None, 0.0, 2))
        voter.push("A")
        voter.push("A")
        self.assertEqual(voter.stable(), ("A", 1.0, 2))

    def test_vote_below_ratio(self):
        voter = VoteStabilizer(window_sec=10, min_ratio=0.8, min_samples=3)
        voter.hist.extend([(1, "A"), (1, "B"), (1, None)])
        name, ratio, count = voter.stable()
        self.assertIsNone(name)
        self.assertAlmostEqual(ratio, 1 / 3)
        self.assertEqual(count, 3)


class LbphModelTests(unittest.TestCase):
    def test_preprocess_augment_rotate_and_confidence(self):
        image = np.full((20, 20), 100, dtype=np.uint8)
        processed = lbph_model.preprocess_face(image)
        self.assertEqual(processed.shape, lbph_model.FACE_SIZE[::-1])
        self.assertEqual(len(lbph_model.augment_face(image)), 6)
        self.assertGreater(lbph_model.lbph_conf_from_dist(0), 0.99)

    def test_load_lbph_missing_and_success(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "model.yml"
            with patch.object(lbph_model, "LBPH_MODEL_PATH", path):
                with self.assertRaises(FileNotFoundError):
                    lbph_model.load_lbph()
                path.touch()
                rec = MagicMock()
                with patch.object(
                    lbph_model.cv2.face,
                    "LBPHFaceRecognizer_create",
                    return_value=rec,
                ):
                    self.assertIs(lbph_model.load_lbph(), rec)
                rec.read.assert_called_once_with(str(path))

    def test_train_skips_missing_and_invalid_then_trains(self):
        with tempfile.TemporaryDirectory() as tmp:
            dataset = Path(tmp) / "dataset"
            model_path = Path(tmp) / "models" / "lbph.yml"
            driver = dataset / "Driver"
            driver.mkdir(parents=True)
            image_path = driver / "0001.jpg"
            image_path.touch()
            rec = MagicMock()
            with patch.object(lbph_model, "DATASET_DIR", dataset), patch.object(
                lbph_model, "LBPH_MODEL_PATH", model_path
            ), patch.object(
                lbph_model.cv2.face,
                "LBPHFaceRecognizer_create",
                return_value=rec,
            ), patch.object(
                lbph_model.cv2,
                "imread",
                return_value=np.full((20, 20), 100, dtype=np.uint8),
            ):
                result = lbph_model.train_lbph({"Missing": 0, "Driver": 3})
                self.assertIs(result, rec)
                self.assertEqual(rec.train.call_args.args[1].shape, (6, 1))
                rec.save.assert_called_once_with(str(model_path))

                with patch.object(lbph_model.cv2, "imread", return_value=None):
                    self.assertIsNone(lbph_model.train_lbph({"Driver": 3}))


class EmbeddingModelTests(unittest.TestCase):
    def test_normalize_zero_and_nonzero(self):
        zero = embedding_model._normalize(np.zeros(2))
        vector = embedding_model._normalize(np.array([3.0, 4.0]))
        self.assertEqual(zero.dtype, np.float32)
        self.assertAlmostEqual(float(np.linalg.norm(vector)), 1.0)

    def test_model_init_and_embed_grayscale(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "model.onnx"
            with self.assertRaises(FileNotFoundError):
                FaceEmbeddingModel(path)
            path.touch()
            net = MagicMock()
            net.forward.return_value = np.array([[3.0, 4.0]], dtype=np.float32)
            with patch.object(
                embedding_model.cv2.dnn, "readNetFromONNX", return_value=net
            ):
                model = FaceEmbeddingModel(path)
                result = model.embed(np.ones((10, 10), dtype=np.uint8))
            self.assertAlmostEqual(float(np.linalg.norm(result)), 1.0)
            net.setInput.assert_called_once()

    def test_build_embeddings_disabled_missing_and_success(self):
        with patch.object(embedding_model, "USE_EMBEDDINGS", False):
            self.assertFalse(embedding_model.build_embeddings({"A": 0}))

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            missing = root / "missing.onnx"
            with patch.object(embedding_model, "USE_EMBEDDINGS", True), patch.object(
                embedding_model, "EMBEDDING_MODEL_PATH", missing
            ):
                self.assertFalse(embedding_model.build_embeddings({"A": 0}))

            model_path = root / "model.onnx"
            model_path.touch()
            dataset = root / "dataset"
            folder = dataset / "A"
            folder.mkdir(parents=True)
            for name in ("bad.jpg", "error.jpg", "ok.jpg"):
                (folder / name).touch()
            output = root / "models" / "embeddings.json"
            fake_model = MagicMock()
            fake_model.embed.side_effect = [RuntimeError("bad face"), np.array([1, 0])]
            images = [None, np.ones((2, 2, 3)), np.ones((2, 2, 3))]
            with patch.object(embedding_model, "USE_EMBEDDINGS", True), patch.object(
                embedding_model, "EMBEDDING_MODEL_PATH", model_path
            ), patch.object(embedding_model, "DATASET_DIR", dataset), patch.object(
                embedding_model, "EMBEDDINGS_PATH", output
            ), patch.object(
                embedding_model, "FaceEmbeddingModel", return_value=fake_model
            ), patch.object(embedding_model.cv2, "imread", side_effect=images):
                self.assertTrue(
                    embedding_model.build_embeddings({"Missing": 0, "A": 1})
                )
            self.assertEqual(json.loads(output.read_text()), {"A": [[1, 0]]})

    def test_recognizer_configuration_database_and_prediction_rules(self):
        with patch.object(embedding_model, "USE_EMBEDDINGS", False):
            with self.assertRaises(FileNotFoundError):
                EmbeddingRecognizer()

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            model_path = root / "model.onnx"
            embeddings_path = root / "embeddings.json"
            with patch.object(embedding_model, "USE_EMBEDDINGS", True), patch.object(
                embedding_model, "EMBEDDING_MODEL_PATH", model_path
            ), patch.object(embedding_model, "EMBEDDINGS_PATH", embeddings_path):
                with self.assertRaises(FileNotFoundError):
                    EmbeddingRecognizer()
                model_path.touch()
                with self.assertRaises(FileNotFoundError):
                    EmbeddingRecognizer()
                embeddings_path.write_text(json.dumps({"A": [[3, 4]]}))
                fake_model = MagicMock()
                with patch.object(
                    embedding_model, "FaceEmbeddingModel", return_value=fake_model
                ):
                    recognizer = EmbeddingRecognizer(threshold=0.8, margin=0.1)
                self.assertAlmostEqual(
                    float(np.linalg.norm(recognizer.database["A"][0])), 1.0
                )

        recognizer.model.embed.return_value = np.array([1.0, 0.0])
        recognizer.database = {}
        self.assertEqual(recognizer.predict(None), (None, 0.0))
        recognizer.database = {"empty": []}
        self.assertEqual(recognizer.predict(None), (None, 0.0))
        recognizer.database = {"A": [np.array([0.5, 0.0])]}
        self.assertEqual(recognizer.predict(None), (None, 0.5))
        recognizer.database = {
            "A": [np.array([0.95, 0.0])],
            "B": [np.array([0.90, 0.0])],
        }
        self.assertEqual(recognizer.predict(None), (None, 0.95))
        recognizer.database["B"] = [np.array([0.1, 0.0])]
        self.assertEqual(recognizer.predict(None), ("A", 0.95))


class LandmarkerCropperTests(unittest.TestCase):
    def test_bbox_init_close_and_crop_paths(self):
        from backend.faceid import landmarker_bbox

        box = landmarker_bbox.landmarks_to_bbox(landmarks(), 200, 100, pad=0)
        self.assertEqual(box, (50, 25, 100, 50))

        with tempfile.TemporaryDirectory() as tmp:
            model_path = Path(tmp) / "face.task"
            with patch.object(landmarker_bbox, "LANDMARKER_PATH", model_path):
                with self.assertRaises(FileNotFoundError):
                    LandmarkerFaceCropper()
                model_path.write_bytes(b"model")
                detector = MagicMock()
                with patch.object(landmarker_bbox, "mp", fake_mediapipe(detector)):
                    cropper = LandmarkerFaceCropper()
                self.assertIs(cropper._landmarker, detector)

        frame = np.zeros((100, 200, 3), dtype=np.uint8)
        cropper._start_time = 0
        cropper._landmarker.detect_for_video.return_value = SimpleNamespace(
            face_landmarks=[]
        )
        with patch.object(landmarker_bbox, "mp", fake_mediapipe(detector)):
            self.assertEqual(cropper.crop_color(frame), (None, None))
            self.assertEqual(cropper.crop(frame), (None, None))
            cropper._landmarker.detect_for_video.return_value = SimpleNamespace(
                face_landmarks=[landmarks(0.4, 0.4, 0.41, 0.41)]
            )
            roi, bbox = cropper.crop_color(frame, min_face_px=120)
            self.assertIsNone(roi)
            self.assertIsNotNone(bbox)
            cropper._landmarker.detect_for_video.return_value = SimpleNamespace(
                face_landmarks=[landmarks()]
            )
            color, bbox = cropper.crop_color(frame, min_face_px=20)
            self.assertEqual(color.ndim, 3)
            gray, same_bbox = cropper.crop(frame, min_face_px=20)
            self.assertEqual(gray.shape, landmarker_bbox.FACE_SIZE[::-1])
            self.assertEqual(bbox, same_bbox)
        cropper.close()
        self.assertIsNone(cropper._landmarker)
        cropper.close()


class FaceIdentifierTests(unittest.TestCase):
    def _make_faceid(self, labels=None, rec=None, embed=None):
        cropper = MagicMock()
        with patch("backend.faceid.identifier.load_labels", return_value=labels or {}), patch(
            "backend.faceid.identifier.LandmarkerFaceCropper", return_value=cropper
        ), patch("backend.faceid.identifier.load_lbph", return_value=rec), patch(
            "backend.faceid.identifier.EmbeddingRecognizer", return_value=embed
        ):
            faceid = FaceID(conf_threshold=0.6, vote_min_samples=1)
        return faceid, cropper

    def test_constructor_handles_missing_models_and_close(self):
        cropper = MagicMock()
        with patch("backend.faceid.identifier.load_labels", return_value={}), patch(
            "backend.faceid.identifier.LandmarkerFaceCropper", return_value=cropper
        ), patch(
            "backend.faceid.identifier.load_lbph", side_effect=FileNotFoundError
        ), patch(
            "backend.faceid.identifier.EmbeddingRecognizer",
            side_effect=FileNotFoundError,
        ):
            faceid = FaceID(vote_min_samples=1)
        self.assertIsNone(faceid.rec)
        self.assertIsNone(faceid.embedding_rec)
        faceid.close()
        cropper.close.assert_called_once()

    def test_no_face_no_models_embedding_lbph_and_threshold(self):
        rec = MagicMock()
        embed = MagicMock()
        faceid, cropper = self._make_faceid({"Driver": 7}, rec, embed)
        bbox = (1, 2, 20, 20)

        cropper.crop.return_value = (None, bbox)
        self.assertEqual(faceid.step(np.zeros((2, 2, 3)))[2], bbox)
        self.assertIsNone(faceid.last_raw_name)

        faceid.rec = None
        faceid.embedding_rec = None
        cropper.crop.return_value = (np.zeros((2, 2)), bbox)
        self.assertIsNone(faceid.step(None)[0])

        faceid.embedding_rec = embed
        cropper.crop_color.return_value = (np.zeros((2, 2, 3)), bbox)
        embed.predict.return_value = ("Driver", 0.9)
        faceid.voter.hist.clear()
        self.assertEqual(faceid.step(None)[0], "Driver")

        embed.predict.return_value = (None, 0.1)
        faceid.rec = rec
        rec.predict.return_value = (7, 5.0)
        faceid.voter.hist.clear()
        self.assertEqual(faceid.step(None)[0], "Driver")

        rec.predict.return_value = (999, 100.0)
        self.assertIsNone(faceid.step(None)[0])

        cropper.crop_color.return_value = (None, bbox)
        rec.predict.return_value = (7, 100.0)
        self.assertIsNone(faceid.step(None)[0])


if __name__ == "__main__":
    unittest.main()
