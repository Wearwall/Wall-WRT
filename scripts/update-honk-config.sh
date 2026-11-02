#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SOURCE="https://raw.githubusercontent.com/daeuniverse/openwrt-packages/f930ef7c90ea1f64c38d38c1a9587ae78e6e6e82/honk/files/config.dae"
DEST="${1:-package/base-files/files/etc/honk/config.dae}"
mkdir -p "$(dirname "$DEST")"
curl --fail --location --retry 3 "$SOURCE" -o "$DEST"
# Replace package default UI listener with loopback for a safe first boot.
sed -i "s/listen: '0.0.0.0:9527'/listen: '127.0.0.1:9527'/" "$DEST"
