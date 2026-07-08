import time
import numpy as np
from dataclasses import dataclass
from .metrics import clamp

@dataclass
class DrowsyOutputs:
    ear: float | None
    mar: float | None

    baseline_ear: float | None
    baseline_source: str

    yawn_status: str
    yawn_total: int
    yawns_in_window: int

    eye_score: float
    yawn_score: float
    ear_ratio: float | None
    eye_closed_elapsed: float
    score: float
    alert_active: bool
    alert_reason: str | None

    calibrating: bool
    calib_remaining: float

class DrowsinessEngine:
    def __init__(self, cfg):
        self.cfg = cfg
        self.reset_all()

    def reset_all(self):
        self.calibrating = True
        self.calib_ears = []
        self.calib_start = time.time()
        self.baseline_ear = None
        self.baseline_source = "SESSION"

        self.yawn_frame_counter = 0
        self.last_yawn_time = -999.0
        self.yawn_total = 0
        self.yawn_times = []
        self.yawn_status = "NO"

        self.score_smoothed = 0.0
        self.yawn_points = 0.0
        self.alert_until = 0.0
        self.last_alert_time = -999.0
        self.eye_closed_since = None
        self.eye_closed_elapsed = 0.0
        self.alert_reason = None

    def _reset_monitoring(self):
        self.yawn_frame_counter = 0
        self.last_yawn_time = -999.0
        self.yawn_total = 0
        self.yawn_times = []
        self.yawn_status = "NO"

        self.score_smoothed = 0.0
        self.yawn_points = 0.0
        self.alert_until = 0.0
        self.last_alert_time = -999.0
        self.eye_closed_since = None
        self.eye_closed_elapsed = 0.0
        self.alert_reason = None

    def set_profile_baseline(self, baseline_ear: float, source: str):
        self.baseline_ear = float(baseline_ear)
        self.baseline_source = source
        self.calibrating = False
        self._reset_monitoring()

    def start_calibration(self, source: str):
        self.calibrating = True
        self.calib_ears = []
        self.calib_start = time.time()
        self.baseline_ear = None
        self.baseline_source = source
        self._reset_monitoring()

    def step(self, ear: float | None, mar: float | None, now: float) -> DrowsyOutputs:
        c = self.cfg

        if self.calibrating:
            elapsed = now - self.calib_start
            remaining = max(0.0, c.calib_seconds - elapsed)

            if ear is not None:
                self.calib_ears.append(float(ear))

            if elapsed >= c.calib_seconds:
                if len(self.calib_ears) >= 10:
                    baseline = float(np.median(np.array(self.calib_ears)))
                elif len(self.calib_ears) > 0:
                    baseline = float(np.mean(np.array(self.calib_ears)))
                else:
                    baseline = None

                if baseline is None or baseline < c.min_baseline:
                    self.calib_ears = []
                    self.calib_start = now
                else:
                    self.baseline_ear = baseline
                    self.calibrating = False
                    self._reset_monitoring()

            return DrowsyOutputs(
                ear=ear, mar=mar,
                baseline_ear=self.baseline_ear,
                baseline_source=self.baseline_source,
                yawn_status="NO", yawn_total=self.yawn_total, yawns_in_window=0,
                eye_score=0.0, yawn_score=0.0, ear_ratio=None,
                eye_closed_elapsed=0.0,
                score=self.score_smoothed,
                alert_active=False,
                alert_reason=None,
                calibrating=True,
                calib_remaining=remaining
            )

        # keep yawns window
        self.yawn_times = [t for t in self.yawn_times if (now - t) <= c.yawn_window_sec]
        yawns_in_window = len(self.yawn_times)

        # yawn detection
        self.yawn_status = "NO"
        yawn_event = False

        if mar is not None:
            if mar > c.mar_threshold:
                self.yawn_frame_counter += 1
                if self.yawn_frame_counter >= 2:
                    self.yawn_status = "MAYBE"
            else:
                self.yawn_frame_counter = 0

            if (self.yawn_frame_counter >= c.consec_frames_yawn) and ((now - self.last_yawn_time) > c.yawn_cooldown_sec):
                yawn_event = True
                self.yawn_status = "YES"
                self.yawn_total += 1
                self.last_yawn_time = now
                self.yawn_frame_counter = 0
                self.yawn_times.append(now)
                yawns_in_window = len([t for t in self.yawn_times if (now - t) <= c.yawn_window_sec])

        # score
        eye_score = 0.0
        yawn_score = 0.0
        ear_ratio = None
        alert_from_score = False
        alert_from_closed_eye = False

        if c.use_score:
            self.yawn_points = max(0.0, self.yawn_points - c.yawn_decay_per_sec)
            if yawn_event:
                self.yawn_points = min(c.yawn_points_max, self.yawn_points + c.yawn_points_per_event)

            if ear is not None and self.baseline_ear is not None:
                ear_ratio = ear / self.baseline_ear
                if ear_ratio >= c.eye_low_ratio:
                    eye_score = 0.0
                elif ear_ratio <= c.eye_full_close_ratio:
                    eye_score = 1.0
                else:
                    eye_score = (c.eye_low_ratio - ear_ratio) / (c.eye_low_ratio - c.eye_full_close_ratio)
                    eye_score = clamp(eye_score)

            yawn_score = clamp(self.yawn_points / c.yawn_points_max)

            score_raw = c.w_eye * eye_score + c.w_yawn * yawn_score
            self.score_smoothed = (1 - c.score_alpha) * self.score_smoothed + c.score_alpha * score_raw

        closed_by_ratio = ear_ratio is not None and ear_ratio <= c.closed_eye_ratio
        closed_by_absolute_ear = ear is not None and ear <= c.closed_eye_ear

        if closed_by_ratio or closed_by_absolute_ear:
            if self.eye_closed_since is None:
                self.eye_closed_since = now
            self.eye_closed_elapsed = now - self.eye_closed_since
            alert_from_closed_eye = self.eye_closed_elapsed >= c.closed_eye_alert_sec
        else:
            self.eye_closed_since = None
            self.eye_closed_elapsed = 0.0

        # yawn rule
        alert_from_yawn_rule = False
        if yawns_in_window >= c.yawn_alert_count:
            alert_from_yawn_rule = True
            self.yawn_times = []
            yawns_in_window = 0

        alert_from_score = (
            self.score_smoothed >= c.score_alert_th
            and (
                alert_from_closed_eye
                or yawn_event
                or yawns_in_window > 0
            )
        )

        alert_should = alert_from_score or alert_from_yawn_rule or alert_from_closed_eye
        cooldown_sec = max(0.0, getattr(c, "alert_cooldown_sec", 0.0))
        cooldown_active = (now - self.last_alert_time) < cooldown_sec
        trigger_alert = alert_should and not cooldown_active

        if trigger_alert:
            self.last_alert_time = now
            self.alert_until = now + c.alert_hold_sec

            if alert_from_closed_eye:
                self.alert_reason = "closed_eye"
            elif alert_from_yawn_rule:
                self.alert_reason = "yawn"
            else:
                self.alert_reason = "score"

        alert_active = now < self.alert_until
        if not alert_active:
            self.alert_reason = None

        return DrowsyOutputs(
            ear=ear, mar=mar,
            baseline_ear=self.baseline_ear,
            baseline_source=self.baseline_source,
            yawn_status=self.yawn_status,
            yawn_total=self.yawn_total,
            yawns_in_window=yawns_in_window,
            eye_score=eye_score,
            yawn_score=yawn_score,
            ear_ratio=ear_ratio,
            eye_closed_elapsed=self.eye_closed_elapsed,
            score=self.score_smoothed,
            alert_active=alert_active,
            alert_reason=self.alert_reason,
            calibrating=False,
            calib_remaining=0.0
        )
