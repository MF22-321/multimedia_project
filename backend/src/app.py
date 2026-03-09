import cv2
import time

from src.config import AppConfig
from src.vision.landmarker import FaceLandmarkerWrapper
from src.drowsy.engine import DrowsinessEngine
from src.identity.controller import IdentityController
from src.ui import draw_points, draw_bbox, render_overlay

def main():
    cfg = AppConfig()

    api = cv2.CAP_DSHOW if cfg.camera.use_dshow else 0
    cap = cv2.VideoCapture(cfg.camera.index, api)
    if not cap.isOpened():
        print(f"Camera index {cfg.camera.index} tidak bisa dibuka.")
        return
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, cfg.camera.width)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, cfg.camera.height)

    ident = IdentityController(cfg.faceid, cfg.enroll)
    drowsy = DrowsinessEngine(cfg.drowsy)

    with FaceLandmarkerWrapper(cfg.paths.face_landmarker_task) as lm:
        try:
            while True:
                ok, frame = cap.read()
                if not ok:
                    print("Gagal membaca frame.")
                    break

                frame = cv2.flip(frame, 1)
                now = time.time()

                # 1) FaceID
                driver, vote_ratio, bbox_faceid, raw_name = ident.step_faceid(frame, now)

                # 2) Enrollment
                enroll_info = ident.update_enroll(frame)
                if enroll_info["active"]:
                    draw_bbox(frame, enroll_info["bbox"], (0,255,255), 2)
                elif enroll_info["trained"]:
                    drowsy.start_calibration("SESSION")

                # 3) MediaPipe
                sig = lm.step(frame)
                draw_points(frame, sig.left_eye, (0,255,0), 2)
                draw_points(frame, sig.right_eye, (0,255,0), 2)
                draw_points(frame, sig.mouth, (255,0,0), 2)

                # draw FaceID bbox (green)
                draw_bbox(frame, bbox_faceid, (0,255,0), 2)

                # 4) Unknown prompt
                have_face_any = (bbox_faceid is not None) or sig.have_face
                unknown_prompt_active = ident.should_prompt_unknown(have_face_any, now)

                # 5) Baseline policy (per driver)
                if driver is not None and (not enroll_info["active"]):
                    prof_base = ident.profile_baseline()
                    if prof_base is not None and drowsy.baseline_source != f"PROFILE:{driver}":
                        drowsy.set_profile_baseline(float(prof_base), f"PROFILE:{driver}")
                    elif prof_base is None and drowsy.baseline_source != f"PROFILE:{driver} (new)":
                        drowsy.start_calibration(f"PROFILE:{driver} (new)")
                elif driver is None and drowsy.baseline_source != "SESSION":
                    drowsy.start_calibration("SESSION")

                # 6) Drowsiness
                out = drowsy.step(sig.ear, sig.mar, now)

                # save baseline if driver known and profile baseline missing
                if (not out.calibrating) and driver is not None:
                    if ident.profile_baseline() is None and out.baseline_ear is not None:
                        ident.save_profile_baseline(out.baseline_ear)
                        drowsy.baseline_source = f"PROFILE:{driver}"

                # 7) UI
                driver_display = driver if driver else "UNKNOWN"
                guest_left = max(0.0, ident.guest_until - now) if ident.guest_mode else 0.0

                render_overlay(
                    frame,
                    driver_name=driver_display,
                    vote_ratio=vote_ratio,
                    baseline_src=drowsy.baseline_source,
                    unknown_prompt_active=unknown_prompt_active,
                    guest_mode=ident.guest_mode,
                    guest_left_s=guest_left,
                    enroll_info=enroll_info,
                    drowsy_out=out,
                    cfg=cfg.drowsy
                )

                cv2.imshow("Drowsiness + FaceID (SRP)", frame)

                key = cv2.waitKey(1) & 0xFF
                if key == ord("q"):
                    break

                if key == ord("r"):
                    if driver is not None:
                        drowsy.start_calibration(f"PROFILE:{driver} (manual)")
                    else:
                        drowsy.start_calibration("SESSION (manual)")

                # ✅ UNKNOWN -> action n/g works (only when prompt is active)
                if key == ord("n") and unknown_prompt_active and (not enroll_info["active"]):
                    name = input("Nama driver baru: ").strip()
                    if name:
                        if ident.start_enroll(name):
                            print(f"[ENROLL] Started for {name}. Auto-capturing...")
                        else:
                            print("[ENROLL] Start failed.")
                    else:
                        print("[ENROLL] Cancel (empty name).")

                if key == ord("g") and unknown_prompt_active and (not enroll_info["active"]):
                    ident.set_guest(now)
                    print("[GUEST] Continue as guest (prompt suppressed).")

        finally:
            cap.release()
            cv2.destroyAllWindows()
            ident.close()

if __name__ == "__main__":
    main()