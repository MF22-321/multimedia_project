#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_BIN="${PYTHON_BIN:-/home/febrian/miniconda3/envs/drwosy/bin/python}"
BACKEND_HOST="${BACKEND_HOST:-127.0.0.1}"
BACKEND_PORT="${BACKEND_PORT:-8000}"
FRONTEND_MODE="${FRONTEND_MODE:-run}"

cd "$ROOT_DIR"
export PYTHONPATH="$ROOT_DIR${PYTHONPATH:+:$PYTHONPATH}"

cleanup() {
  if [[ -n "${BACKEND_PID:-}" ]] && kill -0 "$BACKEND_PID" 2>/dev/null; then
    kill "$BACKEND_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

if command -v fuser >/dev/null 2>&1; then
  fuser -k "${BACKEND_PORT}/tcp" >/dev/null 2>&1 || true
fi

echo "[backend] starting http://${BACKEND_HOST}:${BACKEND_PORT}"
"$PYTHON_BIN" -m uvicorn backend.fastAPI.main:app \
  --host "$BACKEND_HOST" \
  --port "$BACKEND_PORT" \
  --reload \
  > "$ROOT_DIR/backend.log" 2>&1 &
BACKEND_PID=$!

sleep 4

if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
  echo "[backend] failed to start. Last log:"
  tail -n 80 "$ROOT_DIR/backend.log"
  exit 1
fi

echo "[frontend] starting"
cd "$ROOT_DIR/frontend"

if [[ "$FRONTEND_MODE" == "bundle" ]]; then
  "$ROOT_DIR/frontend/build/linux/x64/release/bundle/frontend"
else
  flutter run -d linux
fi
