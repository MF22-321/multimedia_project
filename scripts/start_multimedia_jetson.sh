#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/toyota-multimedia"

mkdir -p "$STATE_DIR"
cd "$PROJECT_ROOT"

# GNOME autostart entries are also executed by TurboVNC/XFCE sessions.  The
# VNC X server exposes llvmpipe, so Flutter and GtkGLArea render entirely on
# the CPU and cannot produce smooth page transitions or a 60 FPS vehicle.
# Keep VNC available for development, but never let it own the production HMI.
if [[ "${ALLOW_SOFTWARE_RENDERER:-0}" != "1" ]] && command -v glxinfo >/dev/null 2>&1; then
  if OPENGL_INFO="$(glxinfo -B 2>&1)"; then
    OPENGL_RENDERER="$(printf '%s\n' "$OPENGL_INFO" | sed -n 's/^OpenGL renderer string: //p' | head -n 1)"
    if printf '%s\n' "$OPENGL_INFO" | grep -Eiq 'llvmpipe|softpipe|swrast|Accelerated: no'; then
      echo "[frontend] refusing software OpenGL renderer: ${OPENGL_RENDERER:-unknown}"
      echo "[frontend] HMI production must run on the physical NVIDIA display."
      echo "[frontend] set ALLOW_SOFTWARE_RENDERER=1 only for low-FPS VNC diagnostics."
      exit 0
    fi
    echo "[frontend] OpenGL renderer: ${OPENGL_RENDERER:-unknown}"
  else
    echo "[frontend] warning: unable to query OpenGL renderer on DISPLAY=${DISPLAY:-unset}"
  fi
fi

# A login on another desktop session must not stop the active backend and
# replace its GPU-accelerated frontend. The descriptor remains locked across
# exec into startup.sh and is released automatically when the HMI exits.
if command -v flock >/dev/null 2>&1; then
  exec 9>"$STATE_DIR/instance.lock"
  if ! flock -n 9; then
    echo "[frontend] another Toyota Multimedia instance is already running"
    exit 0
  fi
fi

export FRONTEND_MODE="${FRONTEND_MODE:-bundle}"
exec ./startup.sh >>"$STATE_DIR/startup.log" 2>&1
