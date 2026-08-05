#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NODE_VERSION="${NODE_VERSION:-24.18.0}"
MACHINE_ARCH="$(uname -m)"

case "$MACHINE_ARCH" in
  aarch64|arm64) NODE_ARCH="arm64" ;;
  x86_64) NODE_ARCH="x64" ;;
  *)
    echo "[android-auto] unsupported CPU architecture: $MACHINE_ARCH" >&2
    exit 1
    ;;
esac

ARCHIVE="node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz"
RUNTIME_ROOT="$PROJECT_ROOT/.tools"
NODE_ROOT="$RUNTIME_ROOT/node-v${NODE_VERSION}-linux-${NODE_ARCH}"
DOWNLOAD_ROOT="$RUNTIME_ROOT/downloads"
RECEIVER_ROOT="$PROJECT_ROOT/frontend/projection_receiver"

mkdir -p "$DOWNLOAD_ROOT"
if [[ ! -x "$NODE_ROOT/bin/node" ]]; then
  echo "[android-auto] downloading Node.js v${NODE_VERSION} (${NODE_ARCH})"
  curl --fail --location --retry 3 \
    "https://nodejs.org/dist/v${NODE_VERSION}/${ARCHIVE}" \
    --output "$DOWNLOAD_ROOT/$ARCHIVE"
  curl --fail --location --retry 3 \
    "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt" \
    --output "$DOWNLOAD_ROOT/SHASUMS256.txt"
  (
    cd "$DOWNLOAD_ROOT"
    grep "  ${ARCHIVE}$" SHASUMS256.txt | sha256sum --check -
  )
  tar -xJf "$DOWNLOAD_ROOT/$ARCHIVE" -C "$RUNTIME_ROOT"
fi

echo "[android-auto] installing receiver dependencies"
cd "$RECEIVER_ROOT"
export PATH="$NODE_ROOT/bin:$PATH"
npm install --no-audit --no-fund
npm run build

echo "[android-auto] receiver ready"
echo "[android-auto] node: $NODE_ROOT/bin/node"
