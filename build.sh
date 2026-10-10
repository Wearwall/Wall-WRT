#!/usr/bin/env bash
set -Eeuo pipefail
umask 022
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$SCRIPT_ROOT/scripts/common.sh"

requested_flavor="${FLAVOR:-all}"
case "$requested_flavor" in
  all) flavors=(libwrt immortalwrt) ;;
  libwrt|immortalwrt) flavors=("$requested_flavor") ;;
  *) die 'FLAVOR must be libwrt, immortalwrt or all' ;;
esac
[ "$(uname -s)" = Linux ] || die 'Compile on Linux; macOS supports static checks only'
build_jobs="${JOBS:-$(getconf _NPROCESSORS_ONLN)}"
case "$build_jobs" in ''|*[!0-9]*|0) die 'JOBS must be a positive integer' ;; esac
mkdir -p "$LOG_ROOT" "$OUTPUT_ROOT"

build_one() {
  load_target "$1"
  rm -rf "${OUTPUT_ROOT:?}/${FLAVOR:?}"
  sync_source
  python3 "$PROJECT_ROOT/scripts/firmware-config.py" check-source "$SOURCE_DIR" "$FLAVOR" | tee "$SOURCE_DIR/source-support.txt"
  prepare_feeds
  cd "$SOURCE_DIR"
  bash "$PROJECT_ROOT/scripts/plugins-clone.sh"
  ./scripts/feeds update -i -a
  ./scripts/feeds install -a
  # Feed controllers exist now; only the visible title changes.
  store_controller=feeds/istore/luci/luci-app-store/luasrc/controller/store.lua
  if [ -f "$store_controller" ]; then
    sed -i 's/_("iStore")/_("商店")/g' "$store_controller"
  fi
  bash "$PROJECT_ROOT/scripts/Roc-script.sh"
  cat "$BASE_CONFIG" "$DEVICE_CONFIG" "$EXTRA_CONFIG" "$PACKAGES_FILE" > .config
  # A cached tmp must not retain metadata for replaced plugin/source definitions.
  rm -f tmp/.config-target.in tmp/.targetinfo tmp/.config-package.in tmp/.packageinfo
  # First defconfig generates upstream's target metadata; no compilation occurs.
  make defconfig
  # Discard any default profile/packages selected while the candidate spelling
  # was unresolved; seed the final configuration again from declared inputs.
  cat "$BASE_CONFIG" "$DEVICE_CONFIG" "$EXTRA_CONFIG" "$PACKAGES_FILE" > .config
  python3 "$PROJECT_ROOT/scripts/firmware-config.py" select-device .config tmp/.config-target.in
  make defconfig
  bash "$PROJECT_ROOT/scripts/gen-i18n.sh"
  make defconfig
  python3 "$PROJECT_ROOT/scripts/firmware-config.py" audit .config "$PACKAGES_FILE" "$FLAVOR" | tee config-audit.txt
  # Keep upstream network generation; overlay contains only UI/SSID defaults.
  # Remove files installed by earlier versions in this generated checkout.
  rm -f files/etc/config/network files/etc/uci-defaults/00-athena-network-merge
  mkdir -p files
  cp -a "$PROJECT_ROOT/files/." files/
  # Do not reuse yesterday's images if today's compilation fails or changes target.
  rm -rf bin/targets/qualcommax/ipq60xx
  make download -j"$build_jobs"
  make -j"$build_jobs" V=s
  python3 "$PROJECT_ROOT/scripts/firmware-config.py" artifacts "$SOURCE_DIR" "$OUTPUT_ROOT/$FLAVOR" "$FLAVOR"
  cp "$LOCK_FILE" "$OUTPUT_ROOT/$FLAVOR/upstream-lock.txt"
  cp third-party-sources.txt "$OUTPUT_ROOT/$FLAVOR/"
  cp config-audit.txt "$OUTPUT_ROOT/$FLAVOR/"
  cp source-support.txt "$OUTPUT_ROOT/$FLAVOR/"
  (cd "$OUTPUT_ROOT/$FLAVOR"; sha256sum -- * > SHA256SUMS)
}

# Each build runs in a subshell under errexit. Continue the second flavor after
# a failure without Bash's conditional-function suppression of errexit.
failures=0
for flavor in "${flavors[@]}"; do
  set +e
  (set -Eeuo pipefail; build_one "$flavor") 2>&1 | tee "$LOG_ROOT/$flavor.log"
  build_statuses=("${PIPESTATUS[@]}")
  status=${build_statuses[0]}
  if [ "${build_statuses[1]}" -ne 0 ]; then status=${build_statuses[1]}; fi
  set -e
  if [ "$status" -ne 0 ]; then
    printf 'ERROR: %s failed (exit %s); see %s\n' "$flavor" "$status" "$LOG_ROOT/$flavor.log" >&2
    # Keep the actual error visible on the public run summary even when the
    # viewer cannot download the full log artifact or use the Actions API.
    if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
      {
        printf '\n### %s build failed (exit %s)\n\n' "$flavor" "$status"
        printf '```text\n'
        tail -c 16000 "$LOG_ROOT/$flavor.log" | tr '\r' '\n' | tail -n 60
        printf '\n```\n'
      } >> "$GITHUB_STEP_SUMMARY"
    fi
    failures=$((failures + 1))
  fi
done
[ "$failures" -eq 0 ]
