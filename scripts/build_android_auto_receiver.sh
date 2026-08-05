#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NODE_BIN="$(find "$PROJECT_ROOT/.tools" -maxdepth 3 -type f -path '*/bin/node' -print -quit 2>/dev/null || true)"

if [[ -z "$NODE_BIN" ]]; then
  echo "[android-auto] local Node.js runtime not found." >&2
  echo "[android-auto] run: ./scripts/setup_android_auto_receiver.sh" >&2
  exit 1
fi

NODE_ROOT="$(cd "$(dirname "$NODE_BIN")/.." && pwd)"
cd "$PROJECT_ROOT/frontend/projection_receiver"
export PATH="$NODE_ROOT/bin:$PATH"
npm run build
