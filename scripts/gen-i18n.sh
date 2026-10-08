#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Read source Makefiles and actual po directories; no hard-coded app list.
python3 "$SCRIPT_ROOT/firmware-config.py" i18n "${1:-$PWD}"
