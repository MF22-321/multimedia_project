from faceid import FaceID
from faceid.enroll_runtime import RuntimeEnroller
from faceid.profile_manager import get_or_create_profile, save_profile

class IdentityController:
    def __init__(self, cfg_faceid, cfg_enroll):
        self.cfg = cfg_faceid

        self.faceid = None
        if cfg_faceid.enable:
            self.faceid = FaceID(
                conf_threshold=cfg_faceid.conf_threshold,
                vote_window_sec=cfg_faceid.vote_window_sec,
                vote_min_ratio=cfg_faceid.vote_min_ratio,
                vote_min_samples=cfg_faceid.vote_min_samples,
            )

        self.enroller = RuntimeEnroller(
            capture_seconds=cfg_enroll.capture_seconds,
            capture_interval=cfg_enroll.capture_interval
        )

        self.current_driver = None
        self.current_profile = None

        self.guest_mode = False
        self.guest_until = 0.0
        self.unknown_since = None

        self.no_face_since = None
        self.raw_unknown_since = None

        self.frame_counter = 0

    def close(self):
        try:
            self.enroller.close()
        except Exception:
            pass
        if self.faceid is not None:
            try:
                self.faceid.close()
            except Exception:
                pass

    def _reload_faceid(self):
        if self.faceid is None:
            return
        try:
            self.faceid.close()
        except Exception:
            pass
        self.faceid = FaceID(
            conf_threshold=self.cfg.conf_threshold,
            vote_window_sec=self.cfg.vote_window_sec,
            vote_min_ratio=self.cfg.vote_min_ratio,
            vote_min_samples=self.cfg.vote_min_samples,
        )

    def _switch_driver(self, name: str):
        self.current_driver = name
        self.current_profile = get_or_create_profile(name)
        self.no_face_since = None
        self.raw_unknown_since = None
        self.unknown_since = None

    def unlock_to_unknown(self):
        self.current_driver = None
        self.current_profile = None
        self.no_face_since = None
        self.raw_unknown_since = None
        self.unknown_since = None

    def step_faceid(self, frame_bgr, now: float):
        self.frame_counter += 1

        if (self.faceid is not None) and (self.frame_counter % self.cfg.every_n_frames == 0) and (not self.enroller.active):
            stable_name, stable_ratio, _ = self.faceid.step(frame_bgr)
        else:
            stable_name, stable_ratio = None, 0.0

        if stable_name is not None and stable_name != self.current_driver:
            self._switch_driver(stable_name)

        # unstuck logic if locked
        if (self.faceid is not None) and (self.current_driver is not None) and (not self.enroller.active):
            have_bbox = (self.faceid.last_bbox is not None)
            raw_unknown = (self.faceid.last_raw_name is None)

            if not have_bbox:
                self.no_face_since = self.no_face_since or now
            else:
                self.no_face_since = None

            if have_bbox and raw_unknown:
                self.raw_unknown_since = self.raw_unknown_since or now
            else:
                self.raw_unknown_since = None

            if self.no_face_since is not None and (now - self.no_face_since) >= self.cfg.unlock_no_face_sec:
                self.unlock_to_unknown()
            elif self.raw_unknown_since is not None and (now - self.raw_unknown_since) >= self.cfg.unlock_unknown_sec:
                self.unlock_to_unknown()

        bbox = self.faceid.last_bbox if self.faceid is not None else None
        raw = self.faceid.last_raw_name if self.faceid is not None else None
        return self.current_driver, float(stable_ratio), bbox, raw

    def should_prompt_unknown(self, have_face_any: bool, now: float) -> bool:
        if self.guest_mode and now >= self.guest_until:
            self.guest_mode = False

        if self.faceid is None or self.enroller.active or self.guest_mode:
            self.unknown_since = None
            return False

        raw_unknown = (self.faceid.last_raw_name is None)
        if raw_unknown and have_face_any:
            if self.unknown_since is None:
                self.unknown_since = now
            elif (now - self.unknown_since) >= self.cfg.unknown_prompt_sec:
                return True
        else:
            self.unknown_since = None

        return False

    def set_guest(self, now: float):
        self.guest_mode = True
        self.guest_until = now + self.cfg.guest_suppress_sec
        self.unknown_since = None

    def start_enroll(self, name: str) -> bool:
        if not name:
            return False
        ok = self.enroller.start(name)
        if ok:
            self.unlock_to_unknown()
        return ok

    def update_enroll(self, frame_bgr) -> dict:
        info = {
            "active": self.enroller.active,
            "driver_id": self.enroller.driver_id,
            "left_s": None,
            "saved": 0,
            "bbox": None,
            "trained": False,
            "train_ok": False,
        }
        if not self.enroller.active:
            return info

        bbox, roi_ok, left_s, saved = self.enroller.update(frame_bgr)
        info["bbox"] = bbox
        info["left_s"] = left_s
        info["saved"] = saved

        if not self.enroller.active:
            ok = self.enroller.finish_and_train()
            info["trained"] = True
            info["train_ok"] = bool(ok)
            if ok:
                self._reload_faceid()
        return info

    def profile_baseline(self):
        if self.current_profile is None:
            return None
        return self.current_profile.get("baseline_ear")

    def save_profile_baseline(self, baseline_ear: float):
        if self.current_driver is None:
            return
        prof = get_or_create_profile(self.current_driver)
        prof["baseline_ear"] = float(baseline_ear)
        save_profile(self.current_driver, prof)
        self.current_profile = prof