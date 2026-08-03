import importlib
import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock, patch


controller_module = importlib.import_module("backend.src.identity.controller")
IdentityController = controller_module.IdentityController


def configs(enabled=True):
    face = SimpleNamespace(
        enable=enabled,
        conf_threshold=0.5,
        vote_window_sec=1.0,
        vote_min_ratio=0.6,
        vote_min_samples=2,
        every_n_frames=2,
        unlock_no_face_sec=2.0,
        unlock_unknown_sec=3.0,
        unknown_prompt_sec=1.0,
        guest_suppress_sec=5.0,
    )
    enroll = SimpleNamespace(capture_seconds=2.0, capture_interval=0.2)
    return face, enroll


class IdentityControllerTests(unittest.TestCase):
    def make_controller(self, enabled=True):
        face_cfg, enroll_cfg = configs(enabled)
        faceid = MagicMock()
        faceid.last_bbox = None
        faceid.last_raw_name = None
        enroller = MagicMock()
        enroller.active = False
        with patch.object(controller_module, "FaceID", return_value=faceid), patch.object(
            controller_module, "RuntimeEnroller", return_value=enroller
        ):
            controller = IdentityController(face_cfg, enroll_cfg)
        return controller, faceid, enroller

    def test_init_disabled_close_and_reload(self):
        controller, _, enroller = self.make_controller(False)
        self.assertIsNone(controller.faceid)
        controller._reload_faceid()
        enroller.close.side_effect = RuntimeError
        controller.close()

        controller, faceid, enroller = self.make_controller(True)
        faceid.close.side_effect = RuntimeError
        enroller.close.side_effect = RuntimeError
        controller.close()
        new_faceid = MagicMock()
        with patch.object(controller_module, "FaceID", return_value=new_faceid):
            controller._reload_faceid()
        self.assertIs(controller.faceid, new_faceid)

    def test_switch_unlock_and_step_faceid_paths(self):
        controller, faceid, enroller = self.make_controller(True)
        profile = {"driver_id": "Alice", "baseline_ear": 0.3}
        with patch.object(
            controller_module, "get_or_create_profile", return_value=profile
        ):
            faceid.step.return_value = ("Alice", 0.9, None)
            driver, ratio, _, _ = controller.step_faceid(None, 1.0)
            self.assertIsNone(driver)  # every second frame only
            driver, ratio, _, _ = controller.step_faceid(None, 2.0)
            self.assertEqual(driver, "Alice")
            self.assertEqual(ratio, 0.9)

        faceid.last_bbox = None
        faceid.last_raw_name = None
        faceid.step.return_value = (None, 0.0, None)
        controller.step_faceid(None, 3.0)
        controller.step_faceid(None, 5.1)
        self.assertIsNone(controller.current_driver)

        with patch.object(
            controller_module,
            "get_or_create_profile",
            return_value={"driver_id": "Alice", "baseline_ear": 0.3},
        ):
            controller._switch_driver("Alice")
        faceid.last_bbox = (1, 2, 3, 4)
        faceid.last_raw_name = None
        controller.step_faceid(None, 10.0)
        controller.step_faceid(None, 13.1)
        self.assertIsNone(controller.current_driver)

        enroller.active = True
        calls_before = faceid.step.call_count
        controller.step_faceid(None, 14.0)
        self.assertEqual(faceid.step.call_count, calls_before)
        controller.unlock_to_unknown()

    def test_unknown_prompt_guest_and_enrollment(self):
        controller, faceid, enroller = self.make_controller(True)
        self.assertFalse(controller.should_prompt_unknown(False, 1.0))
        self.assertFalse(controller.should_prompt_unknown(True, 2.0))
        self.assertTrue(controller.should_prompt_unknown(True, 3.1))
        faceid.last_raw_name = "Known"
        self.assertFalse(controller.should_prompt_unknown(True, 4.0))

        controller.set_guest(10.0)
        self.assertFalse(controller.should_prompt_unknown(True, 11.0))
        self.assertFalse(controller.should_prompt_unknown(True, 16.0))
        self.assertFalse(controller.guest_mode)

        enroller.active = True
        self.assertFalse(controller.should_prompt_unknown(True, 20.0))
        controller.faceid = None
        self.assertFalse(controller.should_prompt_unknown(True, 21.0))

        self.assertFalse(controller.start_enroll(""))
        controller.faceid = faceid
        enroller.start.return_value = False
        self.assertFalse(controller.start_enroll("Alice"))
        enroller.start.return_value = True
        self.assertTrue(controller.start_enroll("Alice"))
        self.assertIsNone(controller.current_driver)

    def test_update_enroll_and_profile_baseline(self):
        controller, _, enroller = self.make_controller(True)
        enroller.active = False
        info = controller.update_enroll(None)
        self.assertFalse(info["active"])

        enroller.active = True
        enroller.driver_id = "Alice"
        enroller.update.return_value = ((1, 2, 3, 4), True, 1.0, 3)
        info = controller.update_enroll(None)
        self.assertEqual(info["saved"], 3)
        self.assertFalse(info["trained"])

        def finish_update(_frame):
            enroller.active = False
            return (None, False, 0.0, 4)

        enroller.update.side_effect = finish_update
        enroller.finish_and_train.return_value = True
        with patch.object(controller, "_reload_faceid") as reload_faceid:
            info = controller.update_enroll(None)
        self.assertTrue(info["trained"])
        self.assertTrue(info["train_ok"])
        reload_faceid.assert_called_once()

        enroller.active = True
        enroller.update.side_effect = finish_update
        enroller.finish_and_train.return_value = False
        self.assertFalse(controller.update_enroll(None)["train_ok"])

        self.assertIsNone(controller.profile_baseline())
        controller.current_profile = {"baseline_ear": 0.29}
        self.assertEqual(controller.profile_baseline(), 0.29)
        controller.save_profile_baseline(0.3)

        controller.current_driver = "Alice"
        profile = {"driver_id": "Alice"}
        with patch.object(
            controller_module, "get_or_create_profile", return_value=profile
        ), patch.object(controller_module, "save_profile") as save:
            controller.save_profile_baseline(0.31)
        self.assertEqual(controller.current_profile["baseline_ear"], 0.31)
        save.assert_called_once()


if __name__ == "__main__":
    unittest.main()
