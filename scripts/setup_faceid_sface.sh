#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODEL_DIR="$PROJECT_ROOT/backend/models"
YUNET_PATH="$MODEL_DIR/face_detection_yunet_2023mar.onnx"
SFACE_PATH="$MODEL_DIR/face_recognition_sface_2021dec.onnx"
YUNET_SHA256="8f2383e4dd3cfbb4553ea8718107fc0423210dc964f9f4280604804ed2552fa4"
SFACE_SHA256="0ba9fbfa01b5270c96627c4ef784da859931e02f04419c829e83484087c34e79"

mkdir -p "$MODEL_DIR"

download_model() {
  local target="$1"
  local url="$2"
  local expected="$3"

  if [[ -f "$target" ]] && echo "$expected  $target" | sha256sum --check --status; then
    echo "[faceid] model verified: $target"
    return
  fi

  curl -fL --retry 3 -o "$target.part" "$url"
  echo "$expected  $target.part" | sha256sum --check --status
  mv "$target.part" "$target"
  echo "[faceid] downloaded and verified: $target"
}

download_model \
  "$YUNET_PATH" \
  "https://github.com/opencv/opencv_zoo/raw/main/models/face_detection_yunet/face_detection_yunet_2023mar.onnx" \
  "$YUNET_SHA256"

download_model \
  "$SFACE_PATH" \
  "https://github.com/opencv/opencv_zoo/raw/main/models/face_recognition_sface/face_recognition_sface_2021dec.onnx" \
  "$SFACE_SHA256"

PYTHON_BIN="${PYTHON_BIN:-/home/multimedia/miniconda3/envs/multimedia/bin/python}"
export MPLCONFIGDIR="${MPLCONFIGDIR:-/tmp/matplotlib-faceid-setup}"
"$PYTHON_BIN" "$PROJECT_ROOT/backend/src/rebuild_face_embeddings.py"

echo "YuNet + SFace setup complete."
