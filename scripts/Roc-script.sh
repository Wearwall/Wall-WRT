#!/usr/bin/env bash
# Retain the template customization entrypoint; plugin sources are shared now.
set -Eeuo pipefail
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
python3 "$PROJECT_ROOT/scripts/firmware-config.py" network "$PWD"
