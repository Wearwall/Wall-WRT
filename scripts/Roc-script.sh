#!/usr/bin/env bash
set -Eeuo pipefail

WORKSPACE="${GITHUB_WORKSPACE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
DEVICE_CONFIG_FILE="${1:-${CONFIG_FILE:-}}"
GENERAL_CONFIG_FILE="${2:-${GENERAL_CONFIG_FILE:-configs/General.config}}"
GIT_CLONE_RETRY_COUNT="${GIT_CLONE_RETRY_COUNT:-3}"
THIRD_PARTY_SOURCES_FILE="${THIRD_PARTY_SOURCES_FILE:-$PWD/third-party-sources.txt}"

case "$GIT_CLONE_RETRY_COUNT" in
  '' | *[!0-9]* | 0)
    echo "Error: GIT_CLONE_RETRY_COUNT must be a positive integer" >&2
    exit 1
    ;;
esac

resolve_config_file() {
  local config_file="$1"

  if [ -f "$config_file" ]; then
    printf '%s\n' "$config_file"
  elif [ -f "$WORKSPACE/$config_file" ]; then
    printf '%s\n' "$WORKSPACE/$config_file"
  else
    echo "Error: configuration file was not found: $config_file" >&2
    return 1
  fi
}

CONFIG_FILES=()
if [ -n "$DEVICE_CONFIG_FILE" ]; then
  CONFIG_FILES+=("$(resolve_config_file "$DEVICE_CONFIG_FILE")")
elif [ -f .config ]; then
  # Keep direct invocations compatible with an existing OpenWrt .config.
  CONFIG_FILES+=("$PWD/.config")
else
  echo "Error: pass the device config as the first argument or CONFIG_FILE" >&2
  exit 1
fi
CONFIG_FILES+=("$(resolve_config_file "$GENERAL_CONFIG_FILE")")

config_symbol_enabled() {
  local symbol="$1"

  awk -v symbol="$symbol" '
    { sub(/\r$/, "") }
    $0 == symbol "=y" || $0 == symbol "=m" { enabled = 1; next }
    $0 == symbol "=n" || $0 == "# " symbol " is not set" { enabled = 0 }
    END { exit(enabled ? 0 : 1) }
  ' "${CONFIG_FILES[@]}"
}

target_device_package_enabled() {
  local package_name="$1"

  awk -v package_name="$package_name" '
    { sub(/\r$/, "") }
    /^CONFIG_TARGET_DEVICE_PACKAGES_[^=]+="/ {
      packages = $0
      sub(/^[^"]*"/, "", packages)
      sub(/"$/, "", packages)
      count = split(packages, values, /[[:space:]]+/)
      for (i = 1; i <= count; i++) {
        if (values[i] == package_name) {
          found = 1
        }
      }
    }
    END { exit(found ? 0 : 1) }
  ' "${CONFIG_FILES[@]}"
}

package_enabled() {
  local package_name

  for package_name in "$@"; do
    if config_symbol_enabled "CONFIG_PACKAGE_$package_name" || target_device_package_enabled "$package_name"; then
      return 0
    fi
  done

  return 1
}

clone_with_retry() {
  local target_dir="$1"
  local attempt
  shift

  for ((attempt = 1; attempt <= GIT_CLONE_RETRY_COUNT; attempt++)); do
    rm -rf "$target_dir"
    if git clone "$@" "$target_dir"; then
      return 0
    fi

    if [ "$attempt" -lt "$GIT_CLONE_RETRY_COUNT" ]; then
      echo "Git clone failed; retrying ($((attempt + 1))/$GIT_CLONE_RETRY_COUNT): ${*: -1}" >&2
      sleep $((attempt * 2))
    fi
  done

  echo "Error: git clone failed after $GIT_CLONE_RETRY_COUNT attempts: ${*: -1}" >&2
  return 1
}

record_git_revision() {
  local repo_url="$1"
  local branch="$2"
  local checkout_dir="$3"
  local commit
  local revision

  commit="$(git -C "$checkout_dir" rev-parse HEAD)"
  printf -v revision '%s\t%s\t%s' "$repo_url" "$branch" "$commit"
  grep -Fqx -- "$revision" "$THIRD_PARTY_SOURCES_FILE" || printf '%s\n' "$revision" >> "$THIRD_PARTY_SOURCES_FILE"
}

clone_repository() {
  local repo_url="$1"
  local branch="$2"
  local target_dir="$3"

  clone_with_retry "$target_dir" \
    --depth=1 \
    --no-tags \
    --branch "$branch" \
    --single-branch \
    "$repo_url"
  record_git_revision "$repo_url" "$branch" "$target_dir"
}

mkdir -p "$(dirname "$THIRD_PARTY_SOURCES_FILE")"
printf 'Repository\tBranch\tCommit\n' > "$THIRD_PARTY_SOURCES_FILE"

# 修改默认IP & 固件名称 & 编译署名和时间
sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate
sed -i "s/hostname='.*'/hostname='Roc'/g" package/base-files/files/bin/config_generate
luci_system_js="feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/10_system.js"
firmware_version_anchor="_('Firmware Version'), (L.isObject(boardinfo.release) ? boardinfo.release.description + ' / ' : '') + (luciversion || ''),"
grep -Fq "$firmware_version_anchor" "$luci_system_js" || { echo "Error: LuCI firmware version anchor was not found in $luci_system_js" >&2; exit 1; }
sed -i "s#_('Firmware Version'), (L\.isObject(boardinfo\.release) ? boardinfo\.release\.description + ' / ' : '') + (luciversion || ''),# \
            _('Firmware Version'),\n \
            E('span', {}, [\n \
                (L.isObject(boardinfo.release)\n \
                ? boardinfo.release.description + ' / '\n \
                : '') + (luciversion || '') + ' / ',\n \
            E('a', {\n \
                href: 'https://github.com/laipeng668/openwrt-ci-roc/releases',\n \
                target: '_blank',\n \
                rel: 'noopener noreferrer'\n \
                }, [ 'Built by Roc $(date "+%Y-%m-%d %H:%M:%S")' ])\n \
            ]),#" "$luci_system_js"

# 调整NSS驱动q6_region内存区域预留大小（ipq6018.dtsi默认预留85MB，ipq6018-512m.dtsi默认预留55MB，带WiFi必须至少预留54MB，以下分别是改成预留16MB、32MB、64MB和96MB）
# sed -i 's/reg = <0x0 0x4ab00000 0x0 0x[0-9a-f]\+>/reg = <0x0 0x4ab00000 0x0 0x01000000>/' target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq6018-512m.dtsi
# sed -i 's/reg = <0x0 0x4ab00000 0x0 0x[0-9a-f]\+>/reg = <0x0 0x4ab00000 0x0 0x02000000>/' target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq6018-512m.dtsi
# sed -i 's/reg = <0x0 0x4ab00000 0x0 0x[0-9a-f]\+>/reg = <0x0 0x4ab00000 0x0 0x04000000>/' target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq6018-512m.dtsi
# sed -i 's/reg = <0x0 0x4ab00000 0x0 0x[0-9a-f]\+>/reg = <0x0 0x4ab00000 0x0 0x06000000>/' target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq6018-512m.dtsi

# 调节IPQ60XX的1.5GHz频率电压(从0.9375V提高到0.95V，过低可能导致不稳定，过高可能增加功耗和发热，具体数值需要根据实际情况调整)
# sed -i 's/opp-microvolt = <937500>;/opp-microvolt = <950000>;/' target/linux/qualcommax/patches-6.12/0038-v6.16-arm64-dts-qcom-ipq6018-add-1.5GHz-CPU-Frequency.patch

# Git稀疏克隆，只克隆指定目录到本地
git_sparse_clone() {
  local branch="$1"
  local repourl="$2"
  local repodir
  local sparse_path
  shift 2

  repodir="$(basename "${repourl%.git}")"
  clone_with_retry "$repodir" \
    --depth=1 \
    --no-tags \
    --branch "$branch" \
    --single-branch \
    --filter=blob:none \
    --sparse \
    "$repourl"
  (
    cd "$repodir"
    git sparse-checkout set "$@"
  )
  record_git_revision "$repourl" "$branch" "$repodir"

  for sparse_path in "$@"; do
    rm -rf "package/$(basename "$sparse_path")"
    mv "$repodir/$sparse_path" package/
  done
  rm -rf "$repodir"
}

# Aria2 & nginx & Go & DDNS & frp & UPnP & Wol
rm -rf feeds/packages/lang/golang
git_sparse_clone master https://github.com/laipeng668/packages lang/golang
mv package/golang feeds/packages/lang/golang

if package_enabled luci-app-aria2 aria2; then
  rm -rf feeds/packages/net/aria2
  git_sparse_clone aria2 https://github.com/laipeng668/packages net/aria2
  mv package/aria2 feeds/packages/net/aria2
fi
if package_enabled ariang; then
  rm -rf feeds/packages/net/ariang
  git_sparse_clone ariang https://github.com/laipeng668/packages net/ariang
  mv package/ariang feeds/packages/net/ariang
fi

if package_enabled nginx nginx-full nginx-ssl luci-app-nginx; then
  rm -rf feeds/packages/net/nginx
  git_sparse_clone nginx https://github.com/laipeng668/packages net/nginx
  mv package/nginx feeds/packages/net/nginx
fi

if package_enabled luci-app-ddns ddns-scripts ddns-scripts-cloudflare; then
  rm -rf feeds/packages/net/ddns-scripts
  git_sparse_clone master https://github.com/laipeng668/packages net/ddns-scripts
  mv package/ddns-scripts feeds/packages/net/ddns-scripts
fi
if package_enabled luci-app-ddns; then
  rm -rf feeds/luci/applications/luci-app-ddns
  git_sparse_clone master https://github.com/laipeng668/luci applications/luci-app-ddns
  mv package/luci-app-ddns feeds/luci/applications/luci-app-ddns
fi

if package_enabled frp frpc frps luci-app-frpc luci-app-frps; then
  rm -rf \
    feeds/packages/net/frp
  git_sparse_clone frp-binary https://github.com/laipeng668/packages net/frp
  mv package/frp feeds/packages/net/frp
fi

frp_luci_paths=()
if package_enabled luci-app-frpc; then
  rm -rf feeds/luci/applications/luci-app-frpc
  frp_luci_paths+=(applications/luci-app-frpc)
fi
if package_enabled luci-app-frps; then
  rm -rf feeds/luci/applications/luci-app-frps
  frp_luci_paths+=(applications/luci-app-frps)
fi
if [ "${#frp_luci_paths[@]}" -gt 0 ]; then
  git_sparse_clone frp https://github.com/laipeng668/luci "${frp_luci_paths[@]}"
  for frp_luci_path in "${frp_luci_paths[@]}"; do
    mv "package/$(basename "$frp_luci_path")" "feeds/luci/$frp_luci_path"
    sed -i '/^LUCI_EXTRA_DEPENDS:=/d' "feeds/luci/$frp_luci_path/Makefile"
  done
fi

if package_enabled luci-app-upnp miniupnpd; then
  rm -rf feeds/packages/net/miniupnpd
  git_sparse_clone master https://github.com/immortalwrt/packages net/miniupnpd
  mv package/miniupnpd feeds/packages/net/miniupnpd
fi
if package_enabled luci-app-upnp; then
  rm -rf feeds/luci/applications/luci-app-upnp
  git_sparse_clone master https://github.com/immortalwrt/luci applications/luci-app-upnp
  mv package/luci-app-upnp feeds/luci/applications/luci-app-upnp
fi

if package_enabled luci-app-wol; then
  rm -rf feeds/luci/applications/luci-app-wol
  git_sparse_clone master https://github.com/immortalwrt/luci applications/luci-app-wol
  mv package/luci-app-wol feeds/luci/applications/luci-app-wol
fi

# Themes and standalone applications. A config application pulls in its theme as a dependency.
if package_enabled luci-theme-argon luci-app-argon-config; then
  rm -rf feeds/luci/themes/luci-theme-argon
  clone_repository https://github.com/jerrykuku/luci-theme-argon master feeds/luci/themes/luci-theme-argon
fi
if package_enabled luci-app-argon-config; then
  rm -rf feeds/luci/applications/luci-app-argon-config
  clone_repository https://github.com/jerrykuku/luci-app-argon-config master feeds/luci/applications/luci-app-argon-config
fi

if package_enabled luci-theme-aurora luci-app-aurora-config; then
  rm -rf feeds/luci/themes/luci-theme-aurora
  clone_repository https://github.com/eamonxg/luci-theme-aurora master feeds/luci/themes/luci-theme-aurora
fi
if package_enabled luci-app-aurora-config; then
  rm -rf feeds/luci/applications/luci-app-aurora-config
  clone_repository https://github.com/eamonxg/luci-app-aurora-config master feeds/luci/applications/luci-app-aurora-config
fi

if package_enabled luci-app-openlist2 openlist2; then
  clone_repository https://github.com/laipeng668/luci-app-openlist2 main package/openlist2
fi

if package_enabled luci-app-lucky lucky; then
  clone_repository https://github.com/gdy666/luci-app-lucky main package/luci-app-lucky
fi

if package_enabled luci-app-wechatpush; then
  rm -rf feeds/luci/applications/luci-app-wechatpush
  clone_repository https://github.com/tty228/luci-app-wechatpush master package/luci-app-wechatpush
fi

if package_enabled luci-app-oaf open-app-filter; then
  rm -rf feeds/luci/applications/luci-app-appfilter feeds/packages/net/open-app-filter
  clone_repository https://github.com/destan19/OpenAppFilter.git master package/OpenAppFilter
fi

if package_enabled luci-app-gecoosac gecoosac; then
  clone_repository https://github.com/laipeng668/luci-app-gecoosac main package/luci-app-gecoosac
fi

if package_enabled luci-app-athena-led luci-i18n-athena-led-zh-cn; then
  clone_repository https://github.com/NONGFAH/luci-app-athena-led main package/luci-app-athena-led
  chmod +x package/luci-app-athena-led/root/etc/init.d/athena_led package/luci-app-athena-led/root/usr/sbin/athena-led
fi

### PassWall & OpenClash ###

if package_enabled luci-app-passwall luci-app-passwall2; then
  # 移除 OpenWrt Feeds 自带的核心库
  rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-libev,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,trojan-plus,tuic-client,v2ray-plugin,xray-plugin,geoview,shadow-tls}
  clone_repository https://github.com/Openwrt-Passwall/openwrt-passwall-packages main package/passwall-packages
fi

if package_enabled luci-app-passwall; then
  rm -rf feeds/luci/applications/luci-app-passwall
  clone_repository https://github.com/Openwrt-Passwall/openwrt-passwall main package/luci-app-passwall
fi

if package_enabled luci-app-passwall2; then
  rm -rf feeds/luci/applications/luci-app-passwall2
  clone_repository https://github.com/Openwrt-Passwall/openwrt-passwall2 main package/luci-app-passwall2
fi

if package_enabled luci-app-openclash; then
  rm -rf feeds/luci/applications/luci-app-openclash
  clone_repository https://github.com/vernesong/OpenClash master package/luci-app-openclash
fi

# 清理 PassWall 的 chnlist 规则文件
# echo "baidu.com"  > package/luci-app-passwall/luci-app-passwall/root/usr/share/passwall/rules/chnlist

# ===================== 用户指定插件：第三方源码 clone =====================
# 用 Wall-WRT 自带 package_enabled 判断（读 General.config / JDCloud-Athena.config），只在勾选时才 clone

if package_enabled tailscale; then
  # 用 whzhni1 的 tailscale 1.102.5（每日 bot 自动跟版）整体替换官方 feed 的 1.98.3（后者在 Go 1.27 下编译失败）
  # 包名同为 tailscale，General.config 的 CONFIG_PACKAGE_tailscale=y 直接生效
  # 备选守护进程源：https://github.com/GuNanOvO/openwrt-tailscale（同为 1.102.5，保留内置 SSH，但其 package/ 目录多一层：mv package/openwrt-tailscale/package/tailscale ...）
  rm -rf feeds/packages/net/tailscale package/tailscale
  clone_repository https://github.com/whzhni1/luci-app-tailscale main package/whzhni1-tailscale
  mv package/whzhni1-tailscale/tailscale feeds/packages/net/tailscale
  rm -rf package/whzhni1-tailscale
fi

if package_enabled luci-app-tailscale-community; then
  # 前端：Tokisaki community 版。官方 luci feed 已有同名包，必须先删 feed 副本，否则被遮蔽编成 feed 版
  rm -rf feeds/luci/applications/luci-app-tailscale-community
  clone_repository https://github.com/Tokisaki-Galaxy/luci-app-tailscale-community master package/luci-app-tailscale-community
fi

if package_enabled luci-app-adguardhome; then
  # AdGuardHome 的 LuCI 管理页（核心二进制刷机后在 LuCI 内「下载核心」拉取，不编进固件）
  clone_repository https://github.com/rufengsuixing/luci-app-adguardhome master package/luci-app-adguardhome
fi

if package_enabled luci-app-re-homeproxy; then
  clone_repository https://github.com/1andrevich/homeproxy-hiddify master package/luci-app-re-homeproxy
fi

if package_enabled luci-app-momo momo; then
  clone_repository https://github.com/nikkinikki-org/OpenWrt-momo main package/OpenWrt-momo
fi

if package_enabled luci-app-clashoo clashoo; then
  clone_repository https://github.com/kenzok8/openwrt-clashoo main package/openwrt-clashoo
fi

if package_enabled luci-app-nikki-rs nikki-rs; then
  clone_repository https://github.com/CHKayanami/OpenWrt-nikki-rs main package/OpenWrt-nikki-rs
fi

if package_enabled luci-app-fchomo mihomo; then
  clone_repository https://github.com/fcshark-org/openwrt-fchomo master package/openwrt-fchomo
fi

# iStore 应用商店：官方推荐的固件集成方式——把 istore feed 追加进 feeds 配置。
# ⚠️ 真·根因（2026-10-08 用 scripts/feeds 源码 + 三份构建日志坐实）：
#    scripts/feeds 的 parse_config() 优先读 feeds.conf，不存在才读 feeds.conf.default；
#    而 feeds.conf 是构建早期 `make defconfig` 从 feeds.conf.default 自动重新生成的。
#    → 只把 src-git istore 写进 feeds.conf.default 不够：脚本跑 `./scripts/feeds update istore` 时，
#      parse_config 读的是「已生成、但此刻还没有 istore 的」feeds.conf → 找不到 istore → 静默跳过、零克隆；
#      随后 refresh_config 触发的 make defconfig 才把 istore 补进 feeds.conf，结尾 `feeds update -i -a`
#      只建了个空索引（日志里只有 feeds/istore.index，没有 Cloning into）→ 固件没 iStore。
#    ✅ 修复：istore 行【必须同时写进 feeds.conf 和 feeds.conf.default】两份（下面两行 grep 各管一份）。
#    随后 `feeds update istore`（不带 -i，真实克隆，日志须出现 "Updating feed 'istore' from ..." +
#    "Cloning into 'istore'..."，这就是验收标志）和 `feeds install istore`（立即建软链，不依赖结尾
#    `feeds install -a`）才是 iStore 进固件的分水岭。
#    （补充：结尾的 `feeds update -i -a` 中 `-i` 真实语义＝只重建索引、绝不克隆，源码原文
#     "Recreate the index only. No feed update from repository is performed"，同样不能指望它来克隆 istore。）
grep -q 'src-git istore' feeds.conf.default || echo 'src-git istore https://github.com/linkease/istore;main' >> feeds.conf.default
grep -q 'src-git istore' feeds.conf || echo 'src-git istore https://github.com/linkease/istore;main' >> feeds.conf
./scripts/feeds update istore
./scripts/feeds install istore
# （2026-10-07 起弃用整仓 clone 到 package/ 的方式：luci.mk 版包在实际构建中被 defconfig 静默丢弃）

./scripts/feeds update -i -a
./scripts/feeds install -a

# 重命名主菜单：iStore → 商店
sed -i 's/_("iStore")/_("商店")/g' feeds/istore/luci/luci-app-store/luasrc/controller/store.lua 2>/dev/null || true
