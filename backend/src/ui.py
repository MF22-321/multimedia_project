import cv2

def draw_points(frame, pts, color, r=2):
    if pts is None:
        return
    for p in pts.astype(int):
        cv2.circle(frame, tuple(p), r, color, -1)

def draw_bbox(frame, bbox, color=(0,255,0), thick=2):
    if bbox is None:
        return
    x, y, w, h = bbox
    cv2.rectangle(frame, (x,y), (x+w, y+h), color, thick)

def put(frame, text, x, y, scale=0.8, color=(0,255,255), thick=2):
    cv2.putText(frame, text, (x,y), cv2.FONT_HERSHEY_SIMPLEX, scale, color, thick)

def render_overlay(frame, *, driver_name, vote_ratio, baseline_src,
                   unknown_prompt_active, guest_mode, guest_left_s,
                   enroll_info, drowsy_out, cfg):
    h = frame.shape[0]

    put(frame, f"Driver: {driver_name} (vote {vote_ratio:.2f})", 20, 30, 0.85, (0,255,255), 2)
    put(frame, f"BaselineSrc: {baseline_src}", 20, 65, 0.75, (180,180,180), 2)

    if unknown_prompt_active and (not enroll_info["active"]) and (not guest_mode):
        put(frame, "NEW DRIVER: press 'n' add | 'g' guest", 20, 130, 0.8, (0,255,255), 2)

    if guest_mode:
        put(frame, f"GUEST MODE {guest_left_s:.0f}s", 20, 160, 0.75, (180,180,180), 2)

    if enroll_info["active"]:
        put(frame, f"ENROLLING: {enroll_info['driver_id']} left={enroll_info['left_s']:.1f}s saved={enroll_info['saved']}",
            20, 95, 0.85, (0,255,255), 2)

    if drowsy_out.calibrating:
        put(frame, "CALIBRATING: keep eyes OPEN", 20, 200, 1.0, (0,255,255), 2)
        put(frame, f"Remaining: {drowsy_out.calib_remaining:.1f}s", 20, 245, 0.9, (0,255,255), 2)
        if drowsy_out.ear is not None:
            put(frame, f"EAR: {drowsy_out.ear:.3f}", 20, 290, 1.0, (0,255,255), 2)
        else:
            put(frame, "No face detected", 20, 290, 1.0, (0,0,255), 2)
    else:
        baseline = drowsy_out.baseline_ear or 0.0
        ref_th = baseline * cfg.thresh_ratio_display if drowsy_out.baseline_ear is not None else 0.0

        put(frame, f"EAR: {drowsy_out.ear:.3f}" if drowsy_out.ear is not None else "EAR: -", 20, 200, 1.0, (0,255,255), 2)
        put(frame, f"Baseline: {baseline:.3f} (refTh {ref_th:.3f})", 20, 240, 0.85, (0,255,255), 2)
        if drowsy_out.mar is not None:
            put(frame, f"MAR: {drowsy_out.mar:.3f}", 20, 280, 1.0, (255,255,0), 2)

        yawn_color = (0,255,0)
        if drowsy_out.yawn_status == "MAYBE":
            yawn_color = (0,255,255)
        elif drowsy_out.yawn_status == "YES":
            yawn_color = (0,0,255)

        put(frame, f"YAWN: {drowsy_out.yawn_status} | Total: {drowsy_out.yawn_total}", 20, 320, 1.0, yawn_color, 3)
        put(frame, f"Yawns({int(cfg.yawn_window_sec)}s): {drowsy_out.yawns_in_window}/{cfg.yawn_alert_count}", 20, 360, 0.9, (255,255,0), 2)

        if cfg.use_score:
            if drowsy_out.ear_ratio is not None:
                put(frame, f"ear_ratio: {drowsy_out.ear_ratio:.2f}  eye_score: {drowsy_out.eye_score:.2f}", 20, 425, 0.8, (180,180,180), 2)
            put(frame, f"YawnScore: {drowsy_out.yawn_score:.2f}", 20, 395, 0.8, (255,255,0), 2)
            put(frame, f"SCORE: {drowsy_out.score:.2f} (th {cfg.score_alert_th:.2f})", 20, 455, 1.0, (0,200,255), 2)

        if drowsy_out.alert_active:
            put(frame, "DROWSY ALERT! (Head Unit Action)", 20, 515, 1.2, (0,0,255), 3)
        else:
            put(frame, "NORMAL", 20, 515, 1.2, (0,255,0), 3)

    put(frame, "Keys: q quit | r recalib | n add | g guest", 20, h - 20, 0.7, (180,180,180), 2)