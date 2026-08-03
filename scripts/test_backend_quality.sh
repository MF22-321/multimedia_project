#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_BIN="${PYTHON_BIN:-/home/multimedia/miniconda3/envs/multimedia/bin/python}"

if [[ ! -x "$PYTHON_BIN" ]]; then
  echo "Backend Python environment not found. Set PYTHON_BIN explicitly." >&2
  exit 2
fi

export PYTHONPATH="$PROJECT_ROOT/backend:$PROJECT_ROOT${PYTHONPATH:+:$PYTHONPATH}"
export MPLCONFIGDIR="${MPLCONFIGDIR:-/tmp/matplotlib-backend-quality}"

cd "$PROJECT_ROOT"
"$PYTHON_BIN" -m coverage erase --rcfile=backend/.coveragerc
"$PYTHON_BIN" -m coverage run --rcfile=backend/.coveragerc \
  -m unittest discover -s backend/tests -v
"$PYTHON_BIN" -m coverage report --rcfile=backend/.coveragerc
