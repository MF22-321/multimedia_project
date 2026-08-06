#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRONTEND_DIR="$PROJECT_ROOT/frontend"
RECEIVER_DIR="$FRONTEND_DIR/projection_receiver"
FLUTTER_BIN="${FLUTTER_BIN:-/home/multimedia/flutter/flutter/bin/flutter}"
NODE_DIR="${NODE_DIR:-$PROJECT_ROOT/.tools/node-v24.18.0-linux-arm64/bin}"

if [[ ! -x "$FLUTTER_BIN" ]]; then
  echo "Flutter SDK tidak ditemukan: $FLUTTER_BIN" >&2
  exit 2
fi

if [[ ! -x "$NODE_DIR/node" || ! -x "$NODE_DIR/npm" ]]; then
  echo "Node.js proyek tidak ditemukan: $NODE_DIR" >&2
  exit 2
fi

echo "[1/5] Backend Face ID, identity, drowsiness, dan mood"
"$PROJECT_ROOT/scripts/test_backend_quality.sh"

echo "[2/5] Analisis statis Flutter"
cd "$FRONTEND_DIR"
"$FLUTTER_BIN" analyze

echo "[3/5] Semua unit, API-contract, widget, dan integration-style test Flutter"
"$FLUTTER_BIN" test --no-pub

echo "[4/5] Android Auto receiver: type-check, protocol tests, dan production build"
cd "$RECEIVER_DIR"
PATH="$NODE_DIR:$PATH" npm run check
PATH="$NODE_DIR:$PATH" npm test
PATH="$NODE_DIR:$PATH" npm run build

echo "[5/5] Pothole, ESP32, maps, coverage >=90%, dan firmware build"
FLUTTER_BIN="$FLUTTER_BIN" "$PROJECT_ROOT/scripts/test_pothole_quality.sh"

echo "Semua quality gate SDT Linkage lulus."
echo "Catatan: pengujian fisik kamera, ESP32, GPS, RJ45, audio, USB, dan wireless tetap wajib."
