import numpy as np

def euclidean(p1, p2) -> float:
    return float(np.linalg.norm(p1 - p2))

def clamp(x, lo=0.0, hi=1.0):
    return max(lo, min(hi, x))

def eye_aspect_ratio(eye_pts: np.ndarray) -> float:
    p1, p2, p3, p4, p5, p6 = eye_pts
    vertical1 = euclidean(p2, p6)
    vertical2 = euclidean(p3, p5)
    horizontal = euclidean(p1, p4)
    if horizontal == 0:
        return 0.0
    return (vertical1 + vertical2) / (2.0 * horizontal)

def mouth_aspect_ratio(mouth_pts: np.ndarray) -> float:
    left, up1, up2, right, low2, low1 = mouth_pts
    vertical1 = euclidean(up1, low1)
    vertical2 = euclidean(up2, low2)
    horizontal = euclidean(left, right)
    if horizontal == 0:
        return 0.0
    return (vertical1 + vertical2) / (2.0 * horizontal)