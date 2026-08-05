#!/usr/bin/env bash
set -euo pipefail

echo "[android-auto] me-restart service Bluetooth..."
sudo systemctl restart bluetooth.service

echo "[android-auto] menunggu adaptor BlueZ siap..."
for _attempt in 1 2 3 4 5; do
  if bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
    echo "[android-auto] Bluetooth siap"
    bluetoothctl show | grep -E "Controller|Powered|Pairable|Discoverable"
    exit 0
  fi
  sleep 1
done

echo "[android-auto] adaptor belum siap setelah restart" >&2
exit 1
