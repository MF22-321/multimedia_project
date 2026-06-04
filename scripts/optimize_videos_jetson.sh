#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VIDEO_DIR="${VIDEO_DIR:-$ROOT_DIR/frontend/assets/video_sdr}"
BACKUP_DIR="${BACKUP_DIR:-$ROOT_DIR/frontend/assets/video_sdr_original}"
WIDTH="${VIDEO_WIDTH:-960}"
HEIGHT="${VIDEO_HEIGHT:-540}"
CRF="${VIDEO_CRF:-24}"
PRESET="${VIDEO_PRESET:-veryfast}"

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "[video] ffmpeg not found. Install with: sudo apt install -y ffmpeg"
  exit 1
fi

mkdir -p "$BACKUP_DIR"

shopt -s nullglob
videos=("$VIDEO_DIR"/*.mp4)
if [[ "${#videos[@]}" -eq 0 ]]; then
  echo "[video] no mp4 files found in: $VIDEO_DIR"
  exit 0
fi

echo "[video] optimizing ${#videos[@]} files for Jetson"
echo "[video] output: H.264 yuv420p ${WIDTH}x${HEIGHT}, CRF ${CRF}, preset ${PRESET}"
echo "[video] backup: $BACKUP_DIR"

for src in "${videos[@]}"; do
  name="$(basename "$src")"
  backup="$BACKUP_DIR/$name"
  tmp="$src.jetson.tmp.mp4"

  if [[ ! -f "$backup" ]]; then
    cp -p "$src" "$backup"
  fi

  echo "[video] $name"
  ffmpeg -hide_banner -loglevel error -y \
    -i "$backup" \
    -vf "scale=${WIDTH}:${HEIGHT}:force_original_aspect_ratio=decrease,pad=${WIDTH}:${HEIGHT}:(ow-iw)/2:(oh-ih)/2,format=yuv420p" \
    -c:v libx264 -preset "$PRESET" -crf "$CRF" \
    -c:a aac -b:a 128k \
    "$tmp"

  mv "$tmp" "$src"
done

echo "[video] done. Original files are in: $BACKUP_DIR"
