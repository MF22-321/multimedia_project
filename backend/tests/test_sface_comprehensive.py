import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

import cv2
import numpy as np

from backend.faceid.identifier import FaceID
from backend.faceid.sface_model import (
    FaceObservation,
    FaceQuality,
    MatchResult,
    SFaceEngine,
    SFaceRecognizer,
    SFaceTemplateStore,
    TemporalLiveness,
    build_sface_templates,
    normalize,
)


def face_row(*, width=120, height=120, nose_x=70, score=0.95):
    return np.array(
        [
            10,
            20,
            width,
            height,
            50,
            60,
            90,
            60,
            nose_x,
            80,
            55,
            105,
            85,
            105,
            score,
        ],
        dtype=np.float32,
    )


def quality(*, accepted=True, reason="ok", condition="frontal"):
    return FaceQuality(
        accepted=accepted,
        reason=reason,
        brightness=100.126,
        sharpness=80.789,
        face_size=120,
        yaw=0.012345,
        condition=condition,
        detection_score=0.95678,
    )


def observation(vector=(1.0, 0.0), *, accepted=True, condition="frontal"):
    return FaceObservation(
        bbox=(10, 20, 120, 120),
        landmarks=np.array(
            [[50, 60], [90, 60], [70, 80], [55, 105], [85, 105]],
            dtype=np.float32,
        ),
        aligned_face=np.ones((112, 112, 3), dtype=np.uint8),
        embedding=normalize(np.asarray(vector, dtype=np.float32)),
        quality=quality(
            accepted=accepted,
            reason="ok" if accepted else "hold_still",
            condition=condition,
        ),
    )


class SFaceEngineTests(unittest.TestCase):
    def test_normalize_quality_and_backend_targets(self):
        self.assertTrue(np.array_equal(normalize(np.zeros(2)), np.zeros(2)))
        self.assertAlmostEqual(float(np.linalg.norm(normalize([3, 4]))), 1.0)
        result = quality().to_dict()
        self.assertEqual(result["brightness"], 100.13)
        self.assertEqual(result["sharpness"], 80.79)
        self.assertEqual(result["detection_score"], 0.9568)
        self.assertEqual(
            SFaceEngine._backend_target("cuda"),
            (cv2.dnn.DNN_BACKEND_CUDA, cv2.dnn.DNN_TARGET_CUDA),
        )
        self.assertEqual(
            SFaceEngine._backend_target("cuda-fp16"),
            (cv2.dnn.DNN_BACKEND_CUDA, cv2.dnn.DNN_TARGET_CUDA_FP16),
        )
        self.assertEqual(
            SFaceEngine._backend_target("other"),
            (cv2.dnn.DNN_BACKEND_OPENCV, cv2.dnn.DNN_TARGET_CPU),
        )

    def test_constructor_missing_models_success_and_cuda_fallback(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            detector_path = root / "detector.onnx"
            recognizer_path = root / "recognizer.onnx"
            with self.assertRaises(FileNotFoundError):
                SFaceEngine(detector_path, recognizer_path)
            detector_path.touch()
            with self.assertRaises(FileNotFoundError):
                SFaceEngine(detector_path, recognizer_path)
            recognizer_path.touch()

            detector = MagicMock()
            recognizer = MagicMock()
            with patch.object(
                cv2.FaceDetectorYN, "create", return_value=detector
            ) as detector_create, patch.object(
                cv2.FaceRecognizerSF, "create", return_value=recognizer
            ):
                engine = SFaceEngine(detector_path, recognizer_path)
            self.assertIs(engine.detector, detector)
            self.assertEqual(engine.dnn_target, "cpu")
            self.assertEqual(detector_create.call_args.args[2], (320, 320))

            with patch.object(
                cv2.FaceDetectorYN,
                "create",
                side_effect=[cv2.error("no cuda"), detector],
            ), patch.object(
                cv2.FaceRecognizerSF, "create", return_value=recognizer
            ):
                engine = SFaceEngine(
                    detector_path, recognizer_path, dnn_target="cuda"
                )
            self.assertEqual(engine.dnn_target, "cpu")
            with patch.object(
                cv2.FaceDetectorYN, "create", side_effect=cv2.error("bad model")
            ):
                with self.assertRaises(cv2.error):
                    SFaceEngine(detector_path, recognizer_path, dnn_target="cpu")

    def test_detect_and_pose_conditions(self):
        engine = object.__new__(SFaceEngine)
        engine.detector = MagicMock()
        self.assertIsNone(engine.detect(None))
        self.assertIsNone(engine.detect(np.empty((0, 0, 3), dtype=np.uint8)))
        engine.detector.detect.return_value = (None, None)
        self.assertIsNone(engine.detect(np.zeros((10, 20, 3), dtype=np.uint8)))
        small = face_row(width=20, height=20, score=0.99)
        large = face_row(width=50, height=60, score=0.8)
        engine.detector.detect.return_value = (None, np.vstack([small, large]))
        np.testing.assert_array_equal(
            engine.detect(np.zeros((40, 80, 3), dtype=np.uint8)), large
        )
        engine.detector.setInputSize.assert_called_with((80, 40))

        self.assertEqual(SFaceEngine._pose_and_condition(face_row(nose_x=60), 100)[1], "left")
        self.assertEqual(SFaceEngine._pose_and_condition(face_row(nose_x=80), 100)[1], "right")
        self.assertEqual(SFaceEngine._pose_and_condition(face_row(), 60)[1], "frontal_dim")
        self.assertEqual(SFaceEngine._pose_and_condition(face_row(), 190)[1], "frontal_bright")
        self.assertEqual(SFaceEngine._pose_and_condition(face_row(), 100)[1], "frontal")

    def test_observe_quality_gates_and_embedding(self):
        engine = object.__new__(SFaceEngine)
        engine.detect = MagicMock(return_value=face_row())
        engine.recognizer = MagicMock()
        engine.recognizer.feature.return_value = np.array([[3.0, 4.0]])
        checker = np.indices((112, 112)).sum(axis=0) % 2
        aligned = np.repeat((checker * 100 + 50)[:, :, None], 3, axis=2).astype(
            np.uint8
        )
        engine.recognizer.alignCrop.return_value = aligned
        result = engine.observe(np.ones((240, 320, 3), dtype=np.uint8))
        self.assertTrue(result.quality.accepted)
        self.assertEqual(result.bbox, (10, 20, 120, 120))
        self.assertEqual(result.landmarks.shape, (5, 2))
        self.assertAlmostEqual(float(np.linalg.norm(result.embedding)), 1.0)

        cases = (
            (face_row(width=20, height=20), aligned, "move_closer"),
            (face_row(), np.zeros_like(aligned), "too_dark"),
            (face_row(), np.full_like(aligned, 255), "too_bright"),
            (face_row(), np.full_like(aligned, 100), "hold_still"),
            (face_row(nose_x=100), aligned, "face_too_turned"),
        )
        for detected_face, crop, expected in cases:
            with self.subTest(expected=expected):
                engine.detect.return_value = detected_face
                engine.recognizer.alignCrop.return_value = crop
                result = engine.observe(np.ones((240, 320, 3), dtype=np.uint8))
                self.assertFalse(result.quality.accepted)
                self.assertEqual(result.quality.reason, expected)
                allowed = engine.observe(
                    np.ones((240, 320, 3), dtype=np.uint8),
                    require_quality=False,
                )
                self.assertTrue(allowed.quality.accepted)
        engine.detect.return_value = None
        self.assertIsNone(engine.observe(np.ones((10, 10, 3))))


class TemplateStoreTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.path = Path(self.temporary_directory.name) / "templates.json"

    def tearDown(self):
        self.temporary_directory.cleanup()

    def test_save_load_legacy_remove_duplicate_and_limit(self):
        store = SFaceTemplateStore(self.path, threshold=0.5, margin=0.1, top_k=2)
        self.assertEqual(store.identities, {})
        self.assertTrue(store.add_template("Alya", [1, 0], "frontal"))
        self.assertFalse(store.add_template("Alya", [1, 0], "frontal"))
        for index in range(12):
            angle = 0.2 * index
            vector = [np.cos(angle), np.sin(angle)]
            store.add_template("Alya", vector, "left", adaptive=True)
        left = [x for x in store.identities["Alya"] if x["condition"] == "left"]
        self.assertLessEqual(len(left), 8)
        store.save()
        payload = json.loads(self.path.read_text(encoding="utf-8"))
        self.assertEqual(payload["version"], 2)
        loaded = SFaceTemplateStore(self.path)
        self.assertIn("Alya", loaded.identities)
        self.assertFalse(loaded.remove("Nobody"))
        self.assertTrue(loaded.remove("Alya"))

        self.path.write_text(json.dumps({"Budi": [[0, 1]]}), encoding="utf-8")
        legacy = SFaceTemplateStore(self.path)
        self.assertEqual(legacy.identities["Budi"][0]["condition"], "legacy")

    def test_prediction_rules_and_novelty(self):
        store = SFaceTemplateStore(self.path, threshold=0.8, margin=0.1, top_k=2)
        self.assertEqual(store.predict([1, 0]).reason, "empty_gallery")
        store.identities = {
            "Alya": [{"vector": [1, 0]}],
            "Budi": [{"vector": [0, 1]}],
        }
        matched = store.predict([1, 0])
        self.assertEqual((matched.name, matched.reason), ("Alya", "matched"))
        self.assertEqual(store.predict([0.7, 0.7]).reason, "below_threshold")
        store.threshold = 0.5
        self.assertEqual(store.predict([0.7, 0.7]).reason, "ambiguous_identity")
        self.assertFalse(store.is_novel("Alya", [1, 0]))
        self.assertTrue(store.is_novel("Alya", [0, 1]))
        self.assertTrue(store.is_novel("Nobody", [1, 0]))


class LivenessRecognizerTests(unittest.TestCase):
    def test_temporal_liveness_history_motion_expiry_and_reset(self):
        liveness = TemporalLiveness(window_sec=1, min_samples=2, min_motion=0.01)
        with patch(
            "backend.faceid.sface_model.time.time", side_effect=[0.0, 0.1, 0.2]
        ):
            self.assertEqual(liveness.update(None), (False, 0.0))
            first = observation()
            self.assertEqual(liveness.update(first), (False, 0.0))
            moved = observation()
            moved.landmarks = moved.landmarks + 10
            passed, score = liveness.update(moved)
        self.assertTrue(passed)
        self.assertGreater(score, 0)
        liveness.reset()
        self.assertEqual(len(liveness.history), 0)
        liveness.history.append((0.0, np.zeros(10)))
        with patch("backend.faceid.sface_model.time.time", return_value=5.0):
            self.assertEqual(liveness.update(None), (False, 0.0))
        self.assertEqual(len(liveness.history), 0)

    def test_recognizer_prediction_and_adaptive_rules(self):
        engine = MagicMock()
        store = MagicMock()
        recognizer = SFaceRecognizer(engine=engine, store=store)
        engine.observe.return_value = None
        found, match = recognizer.predict_frame(np.zeros((1, 1, 3)))
        self.assertIsNone(found)
        self.assertEqual(match.reason, "no_face")

        rejected = observation(accepted=False)
        engine.observe.return_value = rejected
        self.assertEqual(recognizer.predict_frame(None)[1].reason, "hold_still")
        accepted = observation()
        engine.observe.return_value = accepted
        store.predict.return_value = MatchResult("Alya", 0.9, 0.1, 0.8, "matched")
        self.assertEqual(recognizer.predict_frame(None)[1].name, "Alya")
        store.is_novel.return_value = True
        self.assertTrue(recognizer.adaptive_candidate("Alya", accepted, 0.9))
        self.assertFalse(recognizer.adaptive_candidate("Alya", rejected, 0.9))
        self.assertFalse(recognizer.adaptive_candidate("Alya", accepted, 0.1))

    def test_faceid_sface_liveness_adaptive_approve_and_reject(self):
        sface = MagicMock()
        cropper = MagicMock()
        obs = observation(condition="left")
        match = MatchResult("Alya", 0.95, 0.1, 0.85, "matched")
        sface.predict_frame.return_value = (obs, match)
        sface.adaptive_candidate.return_value = True
        sface.store.add_template.return_value = True
        with patch("backend.faceid.identifier.load_labels", return_value={"Alya": 1}), patch(
            "backend.faceid.identifier.LandmarkerFaceCropper", return_value=cropper
        ), patch("backend.faceid.identifier.SFaceRecognizer", return_value=sface):
            faceid = FaceID(
                vote_min_samples=1,
                recognizer_mode="sface",
                require_liveness=True,
            )
        faceid.liveness.update = MagicMock(return_value=(False, 0.2))
        self.assertIsNone(faceid.step(None)[0])
        self.assertEqual(faceid.last_diagnostics["reason"], "liveness_pending")
        faceid.liveness.update.return_value = (True, 0.9)
        faceid.voter.hist.clear()
        self.assertEqual(faceid.step(None)[0], "Alya")
        self.assertTrue(faceid.adaptive_status()["available"])
        self.assertTrue(faceid.approve_adaptive_update()["success"])
        sface.store.save.assert_called_once()
        self.assertFalse(faceid.adaptive_status()["available"])
        self.assertFalse(faceid.approve_adaptive_update()["success"])
        faceid._adaptive_candidate = ("Alya", obs, 0.9)
        self.assertTrue(faceid.reject_adaptive_update()["success"])
        self.assertFalse(faceid.reject_adaptive_update()["success"])
        self.assertIs(faceid.capture_observation(None), sface.engine.observe.return_value)
        faceid.close()

    def test_faceid_missing_models_and_explicit_lbph_modes(self):
        cropper = MagicMock()
        common = (
            patch("backend.faceid.identifier.load_labels", return_value={}),
            patch(
                "backend.faceid.identifier.LandmarkerFaceCropper",
                return_value=cropper,
            ),
        )
        with common[0], common[1], patch(
            "backend.faceid.identifier.SFaceRecognizer",
            side_effect=FileNotFoundError,
        ):
            sface = FaceID(recognizer_mode="sface", vote_min_samples=1)
        self.assertIsNone(sface.capture_observation(None))
        self.assertEqual(sface.step(None)[2], None)
        self.assertEqual(sface.last_diagnostics["reason"], "model_unavailable")

        with common[0], common[1], patch(
            "backend.faceid.identifier.EmbeddingRecognizer",
            side_effect=FileNotFoundError,
        ), patch(
            "backend.faceid.identifier.load_lbph", side_effect=FileNotFoundError
        ):
            arcface = FaceID(recognizer_mode="arcface")
        self.assertIsNone(arcface.embedding_rec)
        self.assertIsNone(arcface.rec)

        with common[0], common[1], patch(
            "backend.faceid.identifier.load_lbph", side_effect=FileNotFoundError
        ):
            lbph = FaceID(recognizer_mode="anything-else")
        self.assertEqual(lbph.recognizer_mode, "lbph")
        self.assertIsNone(lbph.rec)


class TemplateBuildTests(unittest.TestCase):
    def test_build_templates_skips_invalid_and_saves_valid(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            dataset = root / "dataset"
            output = root / "embeddings.json"
            (dataset / "Alya").mkdir(parents=True)
            for name in ("bad.jpg", "error.jpg", "none.jpg", "valid_left.jpg"):
                (dataset / "Alya" / name).touch()
            engine = MagicMock()
            engine.observe.side_effect = [RuntimeError("bad"), None, observation()]

            def read_image(path, _mode):
                if path.endswith("bad.jpg"):
                    return None
                return np.ones((20, 20, 3), dtype=np.uint8)

            with patch("backend.faceid.sface_model.cv2.imread", side_effect=read_image):
                success = build_sface_templates(
                    {"Alya": 1, "Missing": 2},
                    dataset_dir=dataset,
                    output_path=output,
                    engine=engine,
                )
            self.assertTrue(success)
            loaded = SFaceTemplateStore(output)
            self.assertIn("Alya", loaded.identities)
            self.assertEqual(loaded.identities["Alya"][0]["condition"], "left")

            with patch("backend.faceid.sface_model.cv2.imread", return_value=None):
                self.assertFalse(
                    build_sface_templates(
                        {"Alya": 1},
                        dataset_dir=dataset,
                        output_path=output,
                        engine=engine,
                    )
                )


if __name__ == "__main__":
    unittest.main()
