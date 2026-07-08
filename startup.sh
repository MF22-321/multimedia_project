#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_PYTHON_BIN="python3"
if [[ -x "$HOME/miniconda3/envs/multimedia/bin/python" ]]; then
  DEFAULT_PYTHON_BIN="$HOME/miniconda3/envs/multimedia/bin/python"
fi

PYTHON_BIN="${PYTHON_BIN:-$DEFAULT_PYTHON_BIN}"
if ! command -v "$PYTHON_BIN" >/dev/null 2>&1 && [[ ! -x "$PYTHON_BIN" ]]; then
  echo "[backend] python not found: $PYTHON_BIN"
  echo "[backend] falling back to: $DEFAULT_PYTHON_BIN"
  PYTHON_BIN="$DEFAULT_PYTHON_BIN"
fi

BACKEND_HOST="${BACKEND_HOST:-127.0.0.1}"
BACKEND_PORT="${BACKEND_PORT:-8000}"
FRONTEND_MODE="${FRONTEND_MODE:-release}"
BACKEND_RELOAD="${BACKEND_RELOAD:-0}"
START_SPOTIFYD="${START_SPOTIFYD:-1}"
VIDEO_HW_ACCEL="${VIDEO_HW_ACCEL:-0}"
VIDEO_SURFACE_WIDTH="${VIDEO_SURFACE_WIDTH:-960}"
VIDEO_SURFACE_HEIGHT="${VIDEO_SURFACE_HEIGHT:-540}"
AI_VIDEO_WIDTH="${AI_VIDEO_WIDTH:-360}"
AI_VIDEO_HEIGHT="${AI_VIDEO_HEIGHT:-202}"
CAMERA_LOOP_FPS="${CAMERA_LOOP_FPS:-16}"
CAMERA_FPS="${CAMERA_FPS:-16}"
CAMERA_STREAM_WIDTH="${CAMERA_STREAM_WIDTH:-640}"
CAMERA_STREAM_FPS="${CAMERA_STREAM_FPS:-16}"
CAMERA_JPEG_QUALITY="${CAMERA_JPEG_QUALITY:-80}"
CAMERA_WS_WIDTH="${CAMERA_WS_WIDTH:-640}"
CAMERA_WS_FPS="${CAMERA_WS_FPS:-16}"
CAMERA_WS_JPEG_QUALITY="${CAMERA_WS_JPEG_QUALITY:-80}"
FACEID_EVERY_N_FRAMES="${FACEID_EVERY_N_FRAMES:-2}"
DROWSY_EVERY_N_FRAMES="${DROWSY_EVERY_N_FRAMES:-2}"
DROWSY_CLOSED_EYE_ALERT_SEC="${DROWSY_CLOSED_EYE_ALERT_SEC:-3.0}"
DROWSY_CLOSED_EYE_RATIO="${DROWSY_CLOSED_EYE_RATIO:-0.70}"
DROWSY_CLOSED_EYE_EAR="${DROWSY_CLOSED_EYE_EAR:-0.22}"
DROWSY_EYE_LOW_RATIO="${DROWSY_EYE_LOW_RATIO:-0.78}"
DROWSY_EYE_FULL_CLOSE_RATIO="${DROWSY_EYE_FULL_CLOSE_RATIO:-0.58}"
DROWSY_ALERT_HOLD_SEC="${DROWSY_ALERT_HOLD_SEC:-4.0}"
DROWSY_ALERT_COOLDOWN_SEC="${DROWSY_ALERT_COOLDOWN_SEC:-5.0}"
MOOD_HAPPY_CONFIRM_SEC="${MOOD_HAPPY_CONFIRM_SEC:-3.0}"
MOOD_SAD_CONFIRM_SEC="${MOOD_SAD_CONFIRM_SEC:-3.0}"
MOOD_NEUTRAL_CONFIRM_SEC="${MOOD_NEUTRAL_CONFIRM_SEC:-3.0}"
MOOD_HIGH_CONF_CONFIRM_SEC="${MOOD_HIGH_CONF_CONFIRM_SEC:-3.0}"
DRAW_CAMERA_OVERLAY="${DRAW_CAMERA_OVERLAY:-0}"
FACE_MESH_REFINE="${FACE_MESH_REFINE:-0}"
CV2_THREADS="${CV2_THREADS:-2}"
REBUILD_FACE_EMBEDDINGS="${REBUILD_FACE_EMBEDDINGS:-auto}"
FACEID_EMBEDDING_MODEL_PATH="${FACEID_EMBEDDING_MODEL_PATH:-$ROOT_DIR/backend/models/arcface.onnx}"
FACEID_EMBEDDINGS_PATH="$ROOT_DIR/backend/models/face_embeddings.json"
SPOTIFYD_SCRIPT="$ROOT_DIR/scripts/start_spotifyd_jetson.sh"
SPOTIFYD_CACHE_PATH="${SPOTIFYD_CACHE_PATH:-$HOME/.cache/spotifyd}"

if [[ -z "${FLUTTER_BIN:-}" ]]; then
  if command -v flutter >/dev/null 2>&1; then
    FLUTTER_BIN="flutter"
  elif [[ -x "$HOME/flutter/flutter/bin/flutter" ]]; then
    FLUTTER_BIN="$HOME/flutter/flutter/bin/flutter"
  else
    FLUTTER_BIN="flutter"
  fi
fi

if ! command -v spotify >/dev/null 2>&1; then
  if [[ "$(uname -m)" == "aarch64" || "$(uname -m)" == "arm64" ]]; then
    echo "[spotify] desktop app is not available as a stable snap on arm64."
    echo "[spotify] using spotifyd/Spotify Connect when available."
  else
    echo "[spotify] command not found. Install with: sudo snap install spotify"
  fi
fi

cd "$ROOT_DIR"
export PYTHONPATH="$ROOT_DIR${PYTHONPATH:+:$PYTHONPATH}"
export MULTIMEDIA_ROOT="$ROOT_DIR"
export SPOTIFYD_LOG_PATH="$ROOT_DIR/spotifyd.log"
export VIDEO_HW_ACCEL
export VIDEO_SURFACE_WIDTH
export VIDEO_SURFACE_HEIGHT
export AI_VIDEO_WIDTH
export AI_VIDEO_HEIGHT
export CAMERA_LOOP_FPS
export CAMERA_FPS
export CAMERA_STREAM_WIDTH
export CAMERA_STREAM_FPS
export CAMERA_JPEG_QUALITY
export CAMERA_WS_WIDTH
export CAMERA_WS_FPS
export CAMERA_WS_JPEG_QUALITY
export FACEID_EVERY_N_FRAMES
export DROWSY_EVERY_N_FRAMES
export DROWSY_CLOSED_EYE_ALERT_SEC
export DROWSY_CLOSED_EYE_RATIO
export DROWSY_CLOSED_EYE_EAR
export DROWSY_EYE_LOW_RATIO
export DROWSY_EYE_FULL_CLOSE_RATIO
export DROWSY_ALERT_HOLD_SEC
export DROWSY_ALERT_COOLDOWN_SEC
export MOOD_HAPPY_CONFIRM_SEC
export MOOD_SAD_CONFIRM_SEC
export MOOD_NEUTRAL_CONFIRM_SEC
export MOOD_HIGH_CONF_CONFIRM_SEC
export DRAW_CAMERA_OVERLAY
export FACE_MESH_REFINE
export CV2_THREADS
export FACEID_EMBEDDING_MODEL_PATH

cleanup() {
  if [[ -n "${SPOTIFYD_PID:-}" ]] && kill -0 "$SPOTIFYD_PID" 2>/dev/null; then
    kill "$SPOTIFYD_PID" 2>/dev/null || true
  fi

  if [[ -n "${BACKEND_PID:-}" ]] && kill -0 "$BACKEND_PID" 2>/dev/null; then
    kill "$BACKEND_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

stop_existing_backend() {
  echo "[backend] stopping existing backend on port ${BACKEND_PORT} if any"

  if command -v fuser >/dev/null 2>&1; then
    fuser -k "${BACKEND_PORT}/tcp" >/dev/null 2>&1 || true
    sleep 1
    return
  fi

  pkill -f "uvicorn backend.fastAPI.main:app" >/dev/null 2>&1 || true
  sleep 1
}

latest_dataset_mtime() {
  find "$ROOT_DIR/backend/dataset" "$ROOT_DIR/backend/models/labels.json" \
    -type f -printf '%T@\n' 2>/dev/null | sort -nr | head -n 1
}

should_rebuild_face_embeddings() {
  if [[ "$REBUILD_FACE_EMBEDDINGS" == "0" ]]; then
    return 1
  fi

  if [[ ! -f "$FACEID_EMBEDDING_MODEL_PATH" ]]; then
    echo "[faceid] embedding model not found, LBPH fallback will be used: $FACEID_EMBEDDING_MODEL_PATH"
    return 1
  fi

  if [[ "$REBUILD_FACE_EMBEDDINGS" == "1" || ! -f "$FACEID_EMBEDDINGS_PATH" ]]; then
    return 0
  fi

  local latest_data
  latest_data="$(latest_dataset_mtime)"
  if [[ -z "$latest_data" ]]; then
    return 1
  fi

  local embeddings_mtime
  embeddings_mtime="$(stat -c '%Y' "$FACEID_EMBEDDINGS_PATH")"
  python3 - "$latest_data" "$embeddings_mtime" <<'PY'
import sys
latest = float(sys.argv[1])
embeddings = float(sys.argv[2])
sys.exit(0 if latest > embeddings else 1)
PY
}

if [[ "$START_SPOTIFYD" == "1" ]]; then
  if [[ -x "$SPOTIFYD_SCRIPT" ]]; then
    if [[ -f "$SPOTIFYD_CACHE_PATH/oauth/credentials.json" ||
          -f "$SPOTIFYD_CACHE_PATH/credentials.json" ||
          -f "$SPOTIFYD_CACHE_PATH/credentials" ]]; then
      echo "[spotifyd] starting Spotify Connect"
      "$SPOTIFYD_SCRIPT" > "$ROOT_DIR/spotifyd.log" 2>&1 &
      SPOTIFYD_PID=$!
      sleep 2

      if ! kill -0 "$SPOTIFYD_PID" 2>/dev/null; then
        echo "[spotifyd] failed to start. Last log:"
        tail -n 80 "$ROOT_DIR/spotifyd.log"
        exit 1
      fi
    else
      echo "[spotifyd] OAuth credentials not found."
      echo "[spotifyd] run once: $HOME/.cargo/bin/spotifyd authenticate --cache-path \"$SPOTIFYD_CACHE_PATH\""
    fi
  else
    echo "[spotifyd] script not found/executable: $SPOTIFYD_SCRIPT"
  fi
fi

stop_existing_backend

if should_rebuild_face_embeddings; then
  echo "[faceid] rebuilding face embeddings"
  "$PYTHON_BIN" "$ROOT_DIR/backend/src/rebuild_face_embeddings.py"
else
  echo "[faceid] embedding rebuild skipped"
fi

echo "[backend] starting http://${BACKEND_HOST}:${BACKEND_PORT}"
echo "[backend] python: $PYTHON_BIN"
UVICORN_ARGS=(
  -m uvicorn backend.fastAPI.main:app
  --host "$BACKEND_HOST"
  --port "$BACKEND_PORT"
)

if [[ "$BACKEND_RELOAD" == "1" ]]; then
  UVICORN_ARGS+=(--reload)
fi

"$PYTHON_BIN" "${UVICORN_ARGS[@]}" > "$ROOT_DIR/backend.log" 2>&1 &
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
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64) FLUTTER_ARCH="x64" ;;
    aarch64|arm64) FLUTTER_ARCH="arm64" ;;
    *) FLUTTER_ARCH="$ARCH" ;;
  esac

  FRONTEND_BIN="$ROOT_DIR/frontend/build/linux/$FLUTTER_ARCH/release/bundle/frontend"
  if [[ ! -x "$FRONTEND_BIN" ]]; then
    echo "[frontend] bundle not found: $FRONTEND_BIN"
    echo "[frontend] build it first with: cd frontend && flutter build linux --release"
    exit 1
  fi

  "$FRONTEND_BIN"
elif [[ "$FRONTEND_MODE" == "release" ]]; then
  if ! command -v "$FLUTTER_BIN" >/dev/null 2>&1 && [[ ! -x "$FLUTTER_BIN" ]]; then
    echo "[frontend] flutter command not found. Use FRONTEND_MODE=bundle, set FLUTTER_BIN, or add Flutter to PATH."
    exit 1
  fi

  "$FLUTTER_BIN" run --release -d linux
else
  if ! command -v "$FLUTTER_BIN" >/dev/null 2>&1 && [[ ! -x "$FLUTTER_BIN" ]]; then
    echo "[frontend] flutter command not found. Use FRONTEND_MODE=bundle, set FLUTTER_BIN, or add Flutter to PATH."
    exit 1
  fi

  "$FLUTTER_BIN" run -d linux
fi
