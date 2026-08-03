#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/toyota-multimedia"

mkdir -p "$STATE_DIR"
cd "$PROJECT_ROOT"

export FRONTEND_MODE="${FRONTEND_MODE:-bundle}"
exec ./startup.sh >>"$STATE_DIR/startup.log" 2>&1
