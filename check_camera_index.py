import cv2

def test_camera(index, backend=None):
    if backend is None:
        cap = cv2.VideoCapture(index)
    else:
        cap = cv2.VideoCapture(index, backend)

    if not cap.isOpened():
        return False, None

    ret, frame = cap.read()
    if not ret or frame is None:
        cap.release()
        return False, None

    h, w = frame.shape[:2]
    cap.release()
    return True, (w, h)

print("Checking camera indexes...\n")

for i in range(10):
    ok, size = test_camera(i, cv2.CAP_DSHOW)
    if ok:
        print(f"[OK] Camera index {i} works with CAP_DSHOW, resolution={size}")
    else:
        print(f"[--] Camera index {i} failed with CAP_DSHOW")