#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TARGETS_CONF="${TARGETS_CONF:-$PROJECT_ROOT/configs/targets.conf}"
FLAVOR="${FLAVOR:-libwrt}"
PACKAGES_FILE="${PACKAGES_FILE:-$PROJECT_ROOT/$(awk -F= -v key="${FLAVOR}_packages" '$1 == key {print $2}' "$TARGETS_CONF")}"
BASE_CONFIG="${BASE_CONFIG:-$PROJECT_ROOT/configs/roc-base.config}"
THIRD_PARTY_SOURCES_FILE="${THIRD_PARTY_SOURCES_FILE:-$PWD/third-party-sources.txt}"
if [ ! -f scripts/feeds ] || [ ! -f "$PACKAGES_FILE" ]; then
  echo 'Error: run inside a source tree with a valid packages list' >&2
  exit 1
fi

package_enabled() {
  local pkg
  for pkg in "$@"; do
    if awk -v symbol="CONFIG_PACKAGE_$pkg" '
      { sub(/\r$/, ""); sub(/[[:space:]]+#.*$/, ""); sub(/[[:space:]]+$/, "") }
      $0 == symbol "=y" { selected = 1 }
      $0 == symbol "=n" || $0 == symbol "=m" || $0 == "# " symbol " is not set" { selected = 0 }
      END { exit(selected ? 0 : 1) }
    ' "$BASE_CONFIG" "$PACKAGES_FILE"; then return 0; fi
  done
  return 1
}

clone_repository() {
  local url="$1" branch="$2" target_dir="$3"
  case "$target_dir" in package/*|feeds/*) ;; *) echo "Error: unsafe clone path: $target_dir" >&2; return 1 ;; esac
  rm -rf "$target_dir"
  git clone --depth 1 -b "$branch" "$url" "$target_dir"
  printf '%s\t%s\t%s\n' "$url" "$branch" "$(git -C "$target_dir" rev-parse HEAD)" >> "$THIRD_PARTY_SOURCES_FILE"
}

add_feed() {
  local name="$1" url="$2" branch="$3" file
  [ -f feeds.conf ] || cp feeds.conf.default feeds.conf
  for file in feeds.conf.default feeds.conf; do
    # Replace a matching upstream definition, preserving every other feed.
    sed -i -E "/^src-git(-full)?[[:space:]]+${name}[[:space:]]/d" "$file"
    printf 'src-git %s %s;%s\n' "$name" "$url" "$branch" >> "$file"
  done
}

configure_feeds() {
  if package_enabled luci-app-store; then add_feed istore https://github.com/linkease/istore main; fi
  if package_enabled luci-app-openclash; then add_feed openclash https://github.com/vernesong/OpenClash.git master; fi
  if package_enabled luci-app-passwall luci-app-passwall2; then
    add_feed pw_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git main
  fi
  if package_enabled luci-app-passwall; then add_feed passwall https://github.com/Openwrt-Passwall/openwrt-passwall.git main; fi
  if package_enabled luci-app-passwall2; then add_feed passwall2 https://github.com/Openwrt-Passwall/openwrt-passwall2.git main; fi
}

if [ "${1:-}" = --feeds-only ]; then
  configure_feeds
  exit 0
fi
printf 'Repository\tBranch\tCommit\n' > "$THIRD_PARTY_SOURCES_FILE"
mkdir -p package
# Clear previous generated links so removed/replaced packages cannot stay selected.
rm -rf package/feeds
# Clashoo is excluded: its virtual mihomo provider replaces FCHomo in APK.
rm -rf package/openwrt-clashoo feeds/packages/net/clashoo feeds/luci/applications/luci-app-clashoo

# Preserve the template's Go source. There is no effective CONFIG_GOLANG_VERSION_1_26 switch.
clone_repository https://github.com/laipeng668/packages master package/wall-golang-source
# This is a bundle: compiler package Makefiles live below golang/ and
# golang1.xx/, while the shared package include lives directly in lang/golang.
if [ ! -f package/wall-golang-source/lang/golang/golang-package.mk ] || \
  [ ! -f package/wall-golang-source/lang/golang/golang/Makefile ]; then
    echo 'Error: Go repository layout changed (missing shared include/compiler package)' >&2
    exit 1
fi
rm -rf feeds/packages/lang/golang
mv package/wall-golang-source/lang/golang feeds/packages/lang/golang
if package_enabled luci-app-ddns ddns-scripts-cloudflare; then
  rm -rf feeds/packages/net/ddns-scripts
  mv package/wall-golang-source/net/ddns-scripts feeds/packages/net/ddns-scripts
fi
rm -rf package/wall-golang-source

# Match the reference utility sources, alongside the guide's plugin overrides.
replace_feed_paths() {
  local repository="$1" branch="$2" feed="$3" path
  shift 3
  clone_repository "$repository" "$branch" package/wall-reference-feed
  for path in "$@"; do
    [ -f "package/wall-reference-feed/$path/Makefile" ] || {
      echo "Error: reference feed layout changed: $repository $path" >&2; return 1;
    }
    rm -rf "feeds/$feed/$path"
    mkdir -p "feeds/$feed/$(dirname "$path")"
    mv "package/wall-reference-feed/$path" "feeds/$feed/$path"
  done
  rm -rf package/wall-reference-feed
}
if package_enabled luci-app-ddns; then
  replace_feed_paths https://github.com/laipeng668/luci master luci applications/luci-app-ddns
fi
if package_enabled luci-app-frpc luci-app-frps; then
  replace_feed_paths https://github.com/laipeng668/packages frp-binary packages net/frp
  frp_paths=()
  for app in frpc frps; do
    if package_enabled "luci-app-$app"; then frp_paths+=("applications/luci-app-$app"); fi
  done
  replace_feed_paths https://github.com/laipeng668/luci frp luci "${frp_paths[@]}"
  for path in "${frp_paths[@]}"; do sed -i '/^LUCI_EXTRA_DEPENDS:=/d' "feeds/luci/$path/Makefile"; done
fi
if package_enabled luci-app-upnp; then
  replace_feed_paths https://github.com/immortalwrt/packages master packages net/miniupnpd
fi
utility_paths=()
for app in upnp wol; do
  if package_enabled "luci-app-$app"; then utility_paths+=("applications/luci-app-$app"); fi
done
if [ "${#utility_paths[@]}" -gt 0 ]; then
  replace_feed_paths https://github.com/immortalwrt/luci master luci "${utility_paths[@]}"
fi
if package_enabled luci-theme-argon luci-app-argon-config; then
  clone_repository https://github.com/jerrykuku/luci-theme-argon master feeds/luci/themes/luci-theme-argon
fi
if package_enabled luci-app-argon-config; then
  clone_repository https://github.com/jerrykuku/luci-app-argon-config master feeds/luci/applications/luci-app-argon-config
fi

# Disabled plugins must not survive a repeated build's previous clones.
for spec in \
  'athena-led,luci-app-athena-led:package/wall-athena-led' \
  'luci-app-athena-led:package/luci-app-athena-led' \
  'luci-app-re-homeproxy:package/luci-app-re-homeproxy' \
  'momo,luci-app-momo:package/OpenWrt-momo' \
  'nikki-rs,luci-app-nikki-rs:package/OpenWrt-nikki-rs' \
  'mihomo,luci-app-fchomo:package/openwrt-fchomo' \
  'luci-app-adguardhome:package/luci-app-adguardhome' \
  'luci-app-tailscale-community:package/luci-app-tailscale-community' \
  'luci-app-dockerman:package/lisaac-dockerman' \
  'luci-lib-docker,luci-app-dockerman:package/luci-lib-docker'; do
  IFS=: read -r selection directory <<< "$spec"
  IFS=, read -r -a choices <<< "$selection"
  if ! package_enabled "${choices[@]}"; then rm -rf "$directory"; fi
done
if package_enabled athena-led luci-app-athena-led; then
  clone_repository https://github.com/NONGFAH/athena-led.git main package/wall-athena-led/src
  cp "$PROJECT_ROOT/packages/athena-led/Makefile" package/wall-athena-led/Makefile
  python3 "$PROJECT_ROOT/scripts/patch-athena-led.py" package/wall-athena-led/src
  cp "$PROJECT_ROOT/packages/athena-led/gpio.go" package/wall-athena-led/src/internal/gpio.go
fi
if package_enabled luci-app-athena-led; then
  clone_repository https://github.com/NONGFAH/luci-app-athena-led.git main package/luci-app-athena-led
  # The UI's bundled executable is replaced by the daemon built from source.
  rm -f package/luci-app-athena-led/root/usr/sbin/athena-led
  cp "$PROJECT_ROOT/packages/athena-led/luci-Makefile" package/luci-app-athena-led/Makefile
  chmod +x package/luci-app-athena-led/root/etc/init.d/athena_led
  sed -i '/procd_set_param respawn/a\  procd_set_param stdout 1\n  procd_set_param stderr 1' package/luci-app-athena-led/root/etc/init.d/athena_led
  sed -i 's@pgrep /usr/sbin/athena-led@pgrep -f /usr/sbin/[a]thena-led@' package/luci-app-athena-led/luasrc/controller/athena_led.lua
fi
# Remove obsolete template implementations superseded by the requested plugins/feeds.
rm -rf package/luci-app-homeproxy package/OpenWrt-nikki package/luci-app-nikki \
  package/passwall-packages package/luci-app-passwall package/luci-app-passwall2 package/luci-app-openclash

if package_enabled tailscale luci-app-tailscale-community; then
  rm -rf feeds/packages/net/tailscale package/tailscale
  clone_repository https://github.com/whzhni1/luci-app-tailscale main package/whzhni1-tailscale
  [ -f package/whzhni1-tailscale/tailscale/Makefile ] || { echo 'Error: Tailscale repository layout changed' >&2; exit 1; }
  mv package/whzhni1-tailscale/tailscale feeds/packages/net/tailscale
  rm -rf package/whzhni1-tailscale
fi
if package_enabled luci-app-tailscale-community; then
  rm -rf feeds/luci/applications/luci-app-tailscale-community
  clone_repository https://github.com/Tokisaki-Galaxy/luci-app-tailscale-community master package/luci-app-tailscale-community
  tailscale_view=package/luci-app-tailscale-community/luci-app-tailscale-community/htdocs/luci-static/resources/view/tailscale.js
  python3 "$PROJECT_ROOT/scripts/patch-tailscale-ui.py" "$tailscale_view"
  node "$PROJECT_ROOT/scripts/check-tailscale-ui.js" "$tailscale_view"
fi
if package_enabled luci-app-dockerman; then
  rm -rf feeds/luci/applications/luci-app-dockerman
  clone_repository https://github.com/lisaac/luci-app-dockerman master package/lisaac-dockerman
  sed -i -E 's/^(PKG_VERSION[[:space:]]*:?=[[:space:]]*)v([0-9])/\1\2/' \
    package/lisaac-dockerman/applications/luci-app-dockerman/Makefile
  sed -i 's/_("Docker")/_("容器")/g' \
    package/lisaac-dockerman/applications/luci-app-dockerman/luasrc/controller/dockerman.lua
fi
if package_enabled luci-app-dockerman luci-lib-docker; then
  rm -rf feeds/luci/collections/luci-lib-docker package/luci-lib-docker
  clone_repository https://github.com/lisaac/luci-lib-docker master package/luci-lib-docker-tmp
  mv package/luci-lib-docker-tmp/collections/luci-lib-docker package/luci-lib-docker
  rm -rf package/luci-lib-docker-tmp
  sed -i -E 's/^(PKG_VERSION[[:space:]]*:?=[[:space:]]*)v([0-9])/\1\2/' package/luci-lib-docker/Makefile
fi
if package_enabled luci-app-re-homeproxy; then
  rm -rf feeds/luci/applications/luci-app-homeproxy feeds/luci/applications/luci-app-re-homeproxy
  clone_repository https://github.com/1andrevich/homeproxy-hiddify master package/luci-app-re-homeproxy
  python3 "$PROJECT_ROOT/scripts/patch-homeproxy-startup.py" package/luci-app-re-homeproxy/root/etc/init.d/homeproxy
  python3 "$PROJECT_ROOT/scripts/patch-homeproxy-dns.py" package/luci-app-re-homeproxy/root/etc/homeproxy/scripts/generate_client.uc
fi
if package_enabled momo luci-app-momo; then
  rm -rf feeds/packages/net/momo feeds/luci/applications/luci-app-momo
  clone_repository https://github.com/nikkinikki-org/OpenWrt-momo main package/OpenWrt-momo
  python3 "$PROJECT_ROOT/scripts/patch-momo-startup.py" package/OpenWrt-momo/momo/files/momo.init
fi
if package_enabled nikki-rs luci-app-nikki-rs; then
  rm -rf feeds/packages/net/nikki-rs feeds/luci/applications/luci-app-nikki-rs
  clone_repository https://github.com/CHKayanami/OpenWrt-nikki-rs main package/OpenWrt-nikki-rs
fi
if package_enabled mihomo luci-app-fchomo; then
  rm -rf feeds/packages/net/mihomo feeds/luci/applications/luci-app-fchomo
  clone_repository https://github.com/fcshark-org/openwrt-fchomo master package/openwrt-fchomo
fi
if package_enabled luci-app-adguardhome; then
  rm -rf feeds/luci/applications/luci-app-adguardhome
  clone_repository https://github.com/rufengsuixing/luci-app-adguardhome master package/luci-app-adguardhome
fi

# Prevent feed precedence from shadowing the explicitly requested app feeds.
for app in openclash passwall passwall2; do
  if package_enabled "luci-app-$app"; then rm -rf "feeds/luci/applications/luci-app-$app"; fi
done
if package_enabled luci-app-passwall luci-app-passwall2; then
  for pkg in xray-core v2ray-geodata sing-box chinadns-ng dns2socks hysteria ipt2socks \
    microsocks naiveproxy shadowsocks-libev shadowsocks-rust shadowsocksr-libev \
    simple-obfs tcping trojan-plus tuic-client v2ray-plugin xray-plugin geoview shadow-tls; do
    # Remove only definitions actually supplied by pw_packages at this revision.
    if find feeds/pw_packages -type d -name "$pkg" -print -quit | grep -q .; then
      rm -rf "feeds/packages/net/$pkg"
    fi
  done
fi

# Keep the previously verified archive-build fix before BuildPackage evaluation.
if package_enabled dockerd luci-app-dockerman; then
  runc_makefile=feeds/packages/utils/runc/Makefile
  # shellcheck disable=SC2016 # Literal Make variable; not a shell substitution.
  if grep -Fq 'MAKE_VARS += $(GO_PKG_VARS)' "$runc_makefile"; then
    sed -i '/^MAKE_VARS += GOFLAGS=-buildvcs=false$/d' "$runc_makefile"
    # shellcheck disable=SC2016
    sed -i '/^MAKE_VARS += $(GO_PKG_VARS)$/a MAKE_VARS += GOFLAGS=-buildvcs=false' "$runc_makefile"
  else
    echo 'Warning: runc Makefile changed; verify Go VCS flags manually' >&2
  fi
fi
