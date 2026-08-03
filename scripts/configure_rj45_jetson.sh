#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: sudo $0 <ethernet-interface>" >&2
  echo "Example: sudo $0 enP8p1s0" >&2
  exit 2
fi

RJ45_INTERFACE="$1"
RJ45_PROFILE="multimedia-rj45"

if [[ "$EUID" -ne 0 ]]; then
  echo "Run this script with sudo." >&2
  exit 2
fi

if [[ ! -e "/sys/class/net/$RJ45_INTERFACE" ]]; then
  echo "Network interface does not exist: $RJ45_INTERFACE" >&2
  exit 2
fi

if nmcli -t -f NAME connection show | grep -Fxq "$RJ45_PROFILE"; then
  nmcli connection modify "$RJ45_PROFILE" \
    connection.interface-name "$RJ45_INTERFACE" \bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
    connection.autoconnect yes \
    ipv4.method manual \
    ipv4.addresses 192.168.50.2/24 \
    ipv4.gateway "" \
    ipv4.never-default yes \
    ipv6.method disabled
else
  nmcli connection add \
    type ethernet \
    ifname "$RJ45_INTERFACE" \
    con-name "$RJ45_PROFILE" \
    connection.autoconnect yes \
    ipv4.method manual \
    ipv4.addresses 192.168.50.2/24 \
    ipv4.never-default yes \
    ipv6.method disabled
fi

nmcli connection up "$RJ45_PROFILE"

echo
echo "RJ45 profile configured. Verify with:"
echo "  ip -br address show $RJ45_INTERFACE"
echo "  ip route get 192.168.50.1"
echo "  ip route show default"
