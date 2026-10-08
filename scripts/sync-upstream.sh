#!/usr/bin/env bash
set -Eeuo pipefail
umask 022
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$SCRIPT_ROOT/common.sh"

case "${FLAVOR:-all}" in
  all) flavors=(libwrt immortalwrt) ;;
  libwrt|immortalwrt) flavors=("$FLAVOR") ;;
  *) die 'FLAVOR must be libwrt, immortalwrt or all' ;;
esac
for flavor in "${flavors[@]}"; do
  load_target "$flavor"
  sync_source
  prepare_feeds
done
printf 'Updated %s (source + each feed HEAD). Review and git add this file.\n' "$LOCK_FILE"
