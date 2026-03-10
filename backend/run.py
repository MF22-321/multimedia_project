import sys
from pathlib import Path

# Tambahkan root project ke PYTHONPATH
ROOT = Path(__file__).resolve().parent
sys.path.append(str(ROOT))

from src.app import main

if __name__ == "__main__":
    main()