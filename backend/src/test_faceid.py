
import cv2
from faceid import FaceID

def main():
    cap = cv2.VideoCapture(0, cv2.CAP_DSHOW)
    if not cap.isOpened():
        print("Camera tidak bisa dibuka.")
        return

    faceid = FaceID(conf_threshold=0.30)

    try:
        while True:
            ret, frame = cap.read()
            if not ret:
                break

            frame = cv2.flip(frame, 1)

            stable_name, stable_ratio, bbox = faceid.step(frame)

            if bbox is not None:
                x, y, w, h = bbox
                cv2.rectangle(frame, (x, y), (x+w, y+h), (0, 255, 0), 2)

            raw = faceid.last_raw_name if faceid.last_raw_name else "UNKNOWN"
            raw_conf = faceid.last_raw_conf
            stable = stable_name if stable_name else "UNKNOWN"

            cv2.putText(frame, f"RAW: {raw} conf={raw_conf:.2f}", (20, 40),
                        cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0, 255, 255), 2)
            cv2.putText(frame, f"STABLE: {stable} ratio={stable_ratio:.2f}", (20, 80),
                        cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0, 255, 255), 2)

            cv2.imshow("FaceID Test (SRP)", frame)
            if (cv2.waitKey(1) & 0xFF) == ord("q"):
                break
    finally:
        faceid.close()
        cap.release()
        cv2.destroyAllWindows()

if __name__ == "__main__":
    main()