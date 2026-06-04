#!/usr/bin/env bash
set -euo pipefail

SPOTIFYD_BIN="${SPOTIFYD_BIN:-$HOME/.cargo/bin/spotifyd}"
DEVICE_NAME="${SPOTIFYD_DEVICE_NAME:-Jetson Multimedia}"
CACHE_PATH="${SPOTIFYD_CACHE_PATH:-$HOME/.cache/spotifyd}"

if [[ ! -x "$SPOTIFYD_BIN" ]]; then
  echo "[spotifyd] binary not found: $SPOTIFYD_BIN"
  echo "[spotifyd] install it first with: cargo install spotifyd --version 0.3.5 --locked"
  exit 1
fi

mkdir -p "$CACHE_PATH"

SUPPORTS_AUTHENTICATE=0
if "$SPOTIFYD_BIN" --help 2>/dev/null | grep -q "authenticate"; then
  SUPPORTS_AUTHENTICATE=1
fi

VOLUME_CONTROLLER="softvol"
if "$SPOTIFYD_BIN" --help 2>/dev/null | grep -q "soft-volume"; then
  VOLUME_CONTROLLER="soft-volume"
fi

BACKEND="alsa"
if "$SPOTIFYD_BIN" --help 2>/dev/null | grep -q "pulseaudio"; then
  BACKEND="pulseaudio"
fi
BACKEND="${SPOTIFYD_BACKEND:-$BACKEND}"
AUDIO_DEVICE="${SPOTIFYD_AUDIO_DEVICE:-default}"

if [[ "$BACKEND" == "pulseaudio" && -z "${SPOTIFYD_AUDIO_DEVICE:-}" ]]; then
  if command -v pactl >/dev/null 2>&1; then
    AUDIO_DEVICE="$(pactl get-default-sink 2>/dev/null || true)"
  fi

  if [[ -z "$AUDIO_DEVICE" ]]; then
    AUDIO_DEVICE="default"
  fi
fi

if [[ "$SUPPORTS_AUTHENTICATE" == "0" ]]; then
  if [[ -z "${SPOTIFY_USERNAME:-}" ]]; then
    read -r -p "Spotify username/email: " SPOTIFY_USERNAME
  fi

  if [[ -z "${SPOTIFY_PASSWORD:-}" ]]; then
    read -r -s -p "Spotify password: " SPOTIFY_PASSWORD
    echo
  fi
else
  if [[ ! -f "$CACHE_PATH/oauth/credentials.json" &&
        ! -f "$CACHE_PATH/credentials.json" &&
        ! -f "$CACHE_PATH/credentials" ]]; then
    echo "[spotifyd] no cached OAuth credentials found."
    echo "[spotifyd] run once first:"
    echo "  $SPOTIFYD_BIN authenticate --cache-path \"$CACHE_PATH\""
    exit 1
  fi
fi

echo "[spotifyd] starting device: $DEVICE_NAME"
echo "[spotifyd] backend: $BACKEND"
echo "[spotifyd] audio device: $AUDIO_DEVICE"
echo "[spotifyd] volume controller: $VOLUME_CONTROLLER"
echo "[spotifyd] cache: $CACHE_PATH"
echo "[spotifyd] keep this terminal open, then choose '$DEVICE_NAME' from Spotify Connect."

ARGS=(
  --no-daemon \
  --backend "$BACKEND" \
  --device-name "$DEVICE_NAME" \
  --device-type speaker \
  --bitrate 160 \
  --initial-volume 70 \
  --volume-controller "$VOLUME_CONTROLLER" \
  --cache-path "$CACHE_PATH" \
  --verbose
)

if [[ -n "$AUDIO_DEVICE" ]]; then
  ARGS+=(--device "$AUDIO_DEVICE")
fi

if "$SPOTIFYD_BIN" --help 2>/dev/null | grep -q -- "--use-mpris"; then
  ARGS+=(--use-mpris=true --dbus-type session)
fi

if [[ "$SUPPORTS_AUTHENTICATE" == "0" ]]; then
  SPOTIFYD_USERNAME="$SPOTIFY_USERNAME" \
  SPOTIFYD_PASSWORD="$SPOTIFY_PASSWORD" \
  "$SPOTIFYD_BIN" "${ARGS[@]}" \
    --username-cmd 'printf "%s" "$SPOTIFYD_USERNAME"' \
    --password-cmd 'printf "%s" "$SPOTIFYD_PASSWORD"'
else
  "$SPOTIFYD_BIN" "${ARGS[@]}"
fi
