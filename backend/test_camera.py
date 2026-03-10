import cv2

for i in range(6):
    print("Testing camera", i)
    cap = cv2.VideoCapture(i, cv2.CAP_V4L2)

    if cap.isOpened():
        print("Camera", i, "bisa dibuka")
    else:
        print("Camera", i, "tidak bisa dibuka")

    cap.release()