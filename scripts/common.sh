#!/usr/bin/env bash
# Shared by build.sh and the source-only sync entrypoint.
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGETS_CONF="${TARGETS_CONF:-$PROJECT_ROOT/configs/targets.conf}"
SOURCE_ROOT="${SOURCE_ROOT:-$PROJECT_ROOT/sources}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$PROJECT_ROOT/artifacts}"
LOG_ROOT="${LOG_ROOT:-$PROJECT_ROOT/logs}"
LOCK_FILE="${LOCK_FILE:-$PROJECT_ROOT/upstream-lock.txt}"

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

target_value() {
  local key="$1"
  awk -F= -v key="$key" '
    { sub(/\r$/, "") }
    $1 == key { if (++count > 1) exit 2; value = substr($0, index($0, "=") + 1) }
    END { if (count != 1 || value == "") exit 2; print value }
  ' "$TARGETS_CONF"
}

load_target() {
  FLAVOR="$1"
  case "$FLAVOR" in libwrt|immortalwrt) ;; *) die "Unknown FLAVOR: $FLAVOR" ;; esac
  REPO_URL="$(target_value "${FLAVOR}_repo")"
  REPO_BRANCH="$(target_value "${FLAVOR}_branch")"
  PACKAGE_MANAGER="$(target_value "${FLAVOR}_package_manager")"
  DEVICE_CONFIG="$PROJECT_ROOT/$(target_value "${FLAVOR}_device_config")"
  PACKAGES_FILE="$PROJECT_ROOT/$(target_value "${FLAVOR}_packages")"
  EXTRA_CONFIG="$PROJECT_ROOT/$(target_value "${FLAVOR}_extra_config")"
  BASE_CONFIG="$PROJECT_ROOT/configs/roc-base.config"
  SOURCE_DIR="$SOURCE_ROOT/$FLAVOR"
  export FLAVOR PROJECT_ROOT BASE_CONFIG DEVICE_CONFIG EXTRA_CONFIG PACKAGES_FILE TARGETS_CONF
  [ "$PACKAGE_MANAGER" = apk ] || die "Only APK targets are configured"
  if [ ! -f "$BASE_CONFIG" ] || [ ! -f "$DEVICE_CONFIG" ] || [ ! -f "$PACKAGES_FILE" ] || [ ! -f "$EXTRA_CONFIG" ]; then
    die 'Missing configuration file'
  fi
}

sync_source() {
  local previous_origin
  mkdir -p "$SOURCE_ROOT"
  if [ -d "$SOURCE_DIR/.git" ]; then
    # This dedicated generated directory is reset; never point it at a work checkout.
    previous_origin="$(git -C "$SOURCE_DIR" remote get-url origin)"
    if [ "$previous_origin" != "$REPO_URL" ]; then
      if { [ "$FLAVOR" = immortalwrt ] &&
           [ "$previous_origin" = https://github.com/immortalwrt/immortalwrt.git ] &&
           [ "$REPO_URL" = https://github.com/laipeng668/immortalwrt.git ]; } ||
         { [ "$FLAVOR" = libwrt ] &&
           [ "$previous_origin" = https://github.com/LiBwrt/LibWrt.git ] &&
           [ "$REPO_URL" = https://github.com/laipeng668/openwrt-6.x.git ]; }; then
        echo "Migrating generated $FLAVOR checkout to the reference fork"
        git -C "$SOURCE_DIR" remote set-url origin "$REPO_URL"
      else
        die "Unexpected origin in $SOURCE_DIR: $previous_origin"
      fi
    fi
    git -C "$SOURCE_DIR" fetch --depth 1 origin "+refs/heads/$REPO_BRANCH:refs/remotes/origin/$REPO_BRANCH"
    git -C "$SOURCE_DIR" reset --hard "origin/$REPO_BRANCH"
  else
    [ ! -e "$SOURCE_DIR" ] || die "$SOURCE_DIR exists and is not a source Git checkout"
    git clone --depth 1 -b "$REPO_BRANCH" "$REPO_URL" "$SOURCE_DIR"
  fi
  # feeds.conf takes precedence. Refresh it after reset/migration, otherwise
  # the old official feed list hides the fork's NSS driver feed.
  cp "$SOURCE_DIR/feeds.conf.default" "$SOURCE_DIR/feeds.conf"
}

record_lock() {
  python3 "$PROJECT_ROOT/scripts/firmware-config.py" lock "$SOURCE_DIR" "$LOCK_FILE" "$FLAVOR"
}

prepare_feeds() {
  cd "$SOURCE_DIR"
  bash "$PROJECT_ROOT/scripts/plugins-clone.sh" --feeds-only
  ./scripts/feeds update -a
  record_lock
}
