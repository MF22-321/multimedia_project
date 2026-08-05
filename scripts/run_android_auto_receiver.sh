#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NODE_BIN="$(find "$PROJECT_ROOT/.tools" -maxdepth 3 -type f -path '*/bin/node' -print -quit 2>/dev/null || true)"
RECEIVER_JS="$PROJECT_ROOT/frontend/projection_receiver/dist/receiver.js"

if [[ -z "$NODE_BIN" || ! -f "$RECEIVER_JS" ]]; then
  echo "[android-auto] receiver is not installed; run ./scripts/setup_android_auto_receiver.sh" >&2
  exit 1
fi

export AA_PROTO_ROOT="$PROJECT_ROOT/frontend/projection_receiver/dist/protos"
exec "$NODE_BIN" "$RECEIVER_JS"
