#!/usr/bin/env bash
set -euo pipefail

detect_max_power_mode() {
  local config="${NVP_MODEL_CONFIG:-/etc/nvpmodel.conf}"

  if [[ -r "$config" ]]; then
    local detected
    detected="$(
      awk '
        /< POWER_MODEL/ {
          id = "";
          name = "";
          for (i = 1; i <= NF; i++) {
            if ($i ~ /^ID=/) {
              id = $i;
              sub(/^ID=/, "", id);
            }
            if ($i ~ /^NAME=/) {
              name = $i;
              sub(/^NAME=/, "", name);
            }
          }
          if (name == "MAXN_SUPER" || name == "MAXN") {
            print id;
            exit;
          }
        }
      ' "$config"
    )"

    if [[ -n "$detected" ]]; then
      echo "$detected"
      return
    fi
  fi

  echo "0"
}

NVP_MODEL="${NVP_MODEL:-$(detect_max_power_mode)}"

if command -v nvpmodel >/dev/null 2>&1; then
  echo "[jetson] setting nvpmodel mode: $NVP_MODEL"
  sudo nvpmodel -m "$NVP_MODEL"
else
  echo "[jetson] nvpmodel not found, skipping power mode"
fi

if command -v jetson_clocks >/dev/null 2>&1; then
  echo "[jetson] enabling jetson_clocks"
  sudo jetson_clocks
else
  echo "[jetson] jetson_clocks not found, skipping clock lock"
fi

echo "[jetson] current mode:"
if command -v nvpmodel >/dev/null 2>&1; then
  if command -v timeout >/dev/null 2>&1; then
    timeout 5s nvpmodel -q || true
  else
    nvpmodel -q || true
  fi
fi

echo "[jetson] done. Monitor load with: sudo tegrastats"
