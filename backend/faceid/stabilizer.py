import time
from collections import deque, Counter
from typing import Optional, Tuple, Deque

class VoteStabilizer:
    def __init__(self, window_sec=1.5, min_ratio=0.6, min_samples=6):
        self.window_sec = window_sec
        self.min_ratio = min_ratio
        self.min_samples = min_samples
        self.hist: Deque[Tuple[float, Optional[str]]] = deque()

    def push(self, name: Optional[str]):
        now = time.time()
        self.hist.append((now, name))
        cutoff = now - self.window_sec
        while self.hist and self.hist[0][0] < cutoff:
            self.hist.popleft()

    def stable(self) -> Tuple[Optional[str], float, int]:
        if len(self.hist) < self.min_samples:
            return None, 0.0, len(self.hist)
        names = [n for _, n in self.hist if n is not None]
        if not names:
            return None, 0.0, len(self.hist)
        c = Counter(names)
        winner, win_count = c.most_common(1)[0]
        ratio = win_count / max(1, len(self.hist))
        if ratio >= self.min_ratio:
            return winner, ratio, len(self.hist)
        return None, ratio, len(self.hist)