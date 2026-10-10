# 雅典娜双分支改造交付记录

2026-10-10 当前基线：两条源码均采用 openwrt-ci-roc 对应 fork，共用其 General.config 快照；移除网络 overlay/重建及首启 DHCP、无线 disabled 改写。详见 [当前基线说明](roc-baseline.md)。下文最初交付背景保留作历史记录，代码快照按本次改造更新。

本次工作目录 `/workspace/Wall-WRT`；初始改造仅执行静态检查，用户随后授权的真实 GitHub 双分支编译已成功，记录见 [实际构建记录](build-attempts.md)。没有刷机。初次改造已同步到 GitHub；本次参考仓库的 ImmortalWrt 修复也以独立提交同步。云环境安装脚本与启动说明草稿已更新，保存不代表发布。
**设备定义阻塞已修复：ImmortalWrt 改用参考 openwrt-ci-roc 的 laipeng668 fork / openwrt-25.12，选择测试内核和 NSS 12.5，并关闭 WiFi NSS；不再使用缺少雅典娜的官方稳定分支。设备树/镜像/网口/校准/eMMC 静态检查通过，后续真实双分支编译已成功，实机仍未验证。详见 [修复记录](immortalwrt-fix.md)。**

| 文件 | 操作 | 改动与原因 |
|---|---|---|
| `build.sh` | 新增 | 保留 Bash/Kconfig 风格，FLAVOR=all/单线、fetch/reset、共用插件、语言再 defconfig、警告审计、单设备产物与分离日志。 |
| `configs/targets.conf` | 新增 | 两条指定仓库/分支/apk/配置路径，key=value 只读解析。 |
| `configs/device.config` | 新增 | 共用雅典娜单设备配置、关闭多机型、中文与 Docker 内核候选。 |
| `configs/libwrt.config` | 新增 | NSS 11.4、ath11k NSS/mesh/内存设置仅属于 LibWrt。 |
| `configs/immortalwrt.config` | 新增 | 沿用参考 fork 的测试内核、512M、NSS 12.5；关闭 WiFi NSS / mesh。 |
| `configs/packages.txt` | 新增 | 四类包及 OpenClash/Passwall/Passwall2；不替换 RE:HomeProxy、Lua Dockerman、AdGuardHome UI 方案。 |
| `scripts/common.sh` | 新增 | 共用配置/同步；旧官方目录定向迁移 fork，重建 feeds.conf，保留 NSS feed 和 revision 记录。 |
| `scripts/plugins-clone.sh` | 新增 | 自己实现 package_enabled/clone_repository，按指定源码 clone、原位替换、独立库布局/APK 版本处理与 runc 修复。 |
| `scripts/sync-upstream.sh` | 新增 | 只同步源码/feeds，打印短 SHA，更新 lock；不编译、不自动提交/推送。 |
| `scripts/gen-i18n.sh` | 新增 | 无硬编码应用清单，调用实际源码 Po/Makefile 扫描。 |
| `scripts/firmware-config.py` | 新增 | 源码预检、设备符号解析、缺包警告、语言别名、上游固定 LAN 路径、lock 与各 flavor 内核/NSS 产物校验。 |
| `scripts/Roc-script.sh` | 修改 | 保留原定制入口，插件逻辑移入共用脚本；仅在上游 base-files/config_generate 修改默认 LAN 地址。 |
| `scripts/SDK-script.sh` | 修改 | 手动 SDK 工具保留；默认目标改为 qualcommax/ipq60xx，去掉其他设备 profile 和不存在的 x86 config 引用，处理两条 ShellCheck 提示；签名校验不变。 |
| `files/etc/config/network` | 删除 | 使用上游生成的完整硬件网络。 |
| `files/etc/uci-defaults/00-athena-network-merge` | 删除 | 取消首启重建网络。 |
| `files/etc/uci-defaults/99-athena-defaults` | 新增 | 仅按 band/channel/path 设置 SSID，保留上游网络与无线默认逻辑。 |
| `.github/workflows/build.yml` | 新增 | 单一固件入口，手动/push/每日、双线独立矩阵、dl/tmp/ccache 缓存、带日期 artifact 和失败日志。 |
| `Dockerfile` | 新增 | 可选 Linux 非 root 编译环境，仅静态读取，本次没有构建镜像。 |
| `docker-compose.yml` | 新增 | 挂载当前目录、flavor/jobs 与 UID/GID 配置；只验证 compose 语法。 |
| `.gitignore` | 新增 | 忽略生成源码、日志、产物与 Python 缓存，不忽略 lock。 |
| `upstream-lock.txt` | 新增 | 26 条真实只读远端 HEAD 观察；不是编译证明/版本固定，sync 会写入实际 checkout HEAD。 |
| `README.md` | 修改 | 双线状态、插件矩阵、网络默认值、菜单决策、刷机/升级、产物、NSS 校验、风险与人工核实项。 |
| `docs/static-checks.txt` | 新增 | 本次实际静态命令与原始输出、退出码，不编造无输出的检查结果。 |
| `docs/implementation-report.md` | 新增 | 逐文件交付表、完整要求文件快照、检查证据与限制。 |
| `.github/workflows/Build-OpenWrt.yml` | 删除 | 通用多目标构建器由单设备 build.sh 入口替代，防止绕过校验。 |
| `.github/workflows/IPQ60XX-LibWrt.yml` | 删除 | 移除多设备固件入口。 |
| `.github/workflows/JDCloud-ImmortalWrt.yml` | 删除 | 移除旧多 JDCloud 入口及错误 NSS 说明。 |
| `.github/workflows/Trigger-All-Workflows.yml` | 删除 | 移除引用不存在文件的旧触发器。 |
| `.github/workflows/Build-Packages.yml` | 删除 | 去掉旧多架构自动任务和失效配置引用；SDK 工具仍可手动使用。 |
| `configs/General.config` | 删除 | 由 device.config、分支额外配置及 packages.txt 合并替代，避免多个配置真源或多设备选择。 |
| `configs/IPQ60XX.config` | 删除 | 由 device.config、分支额外配置及 packages.txt 合并替代，避免多个配置真源或多设备选择。 |
| `configs/JDCloud.config` | 删除 | 由 device.config、分支额外配置及 packages.txt 合并替代，避免多个配置真源或多设备选择。 |

## 自检真实命令输出

以下退出码来自实际命令。语法/静态分析通过通常没有 stdout。grep 退出 1 表示没有匹配，不是语法检查失败。bash -n scripts/*.sh 只解析第一个参数，因此另做逐文件循环。没有新增统一 VPN JSON，JSON 解析实际扫描到 0 文件，不能称为验证了运行菜单。

```text
Static validation only; no build / make / image generation executed in this refactor.

Shell tools
$ shellcheck --version; /workspace/.wall-wrt-env/bin/actionlint -version
ShellCheck - shell script analysis tool
version: 0.10.0
license: GNU General Public License, version 3
website: https://www.shellcheck.net
1.7.7
installed by downloading from release page
built with go1.23.4 compiler for linux/amd64
[exit 0]

Requested syntax command
$ bash -n build.sh && bash -n scripts/*.sh
[exit 0]

Every shell file, including router defaults
$ for script in build.sh scripts/*.sh files/etc/uci-defaults/*; do bash -n "$script" || exit; done
[exit 0]

ShellCheck
$ shellcheck build.sh scripts/*.sh
[exit 0]

Router POSIX shell check
$ shellcheck -s sh files/etc/uci-defaults/*
[exit 0]

JSON syntax
$ python3 -c 'import json,pathlib; paths=list(pathlib.Path("files").rglob("*.json")); [json.loads(p.read_text()) for p in paths]; print("JSON files checked:", len(paths))'
JSON files checked: 0
[exit 0]

Python source syntax
$ python3 -c 'import ast,pathlib; paths=list(pathlib.Path("scripts").glob("*.py")); [ast.parse(p.read_text(), filename=str(p)) for p in paths]; print("Python AST files checked:", len(paths))'
Python AST files checked: 1
[exit 0]

Actions workflow
$ /workspace/.wall-wrt-env/bin/actionlint .github/workflows/build.yml
[exit 0]

Docker Compose syntax only
$ docker compose config --quiet
[exit 0]

Old LAN string lookup in build code/overlay
$ grep -rn '192.168.1.1' build.sh configs scripts files
scripts/firmware-config.py:133:        changed = text.replace("192.168.1.1", "192.168.6.1").replace("192.168.2.1", "192.168.6.1")
scripts/firmware-config.py:137:    if any("192.168.1.1" in path.read_text() for path in paths):
[exit 0]

Old LAN default lookup in overlay
$ grep -rn '192.168.1.1' files
[exit 1]

Git whitespace
$ git diff --check
[exit 0]

Stable upstream supports Athena?
$ git -C /workspace/.wall-wrt-env/diagnosis/immortal-inspect grep -n 'jdcloud_re-cs-02' HEAD -- target/linux/qualcommax
[exit 1]

Master upstream device support (read-only)
$ git -C /workspace/.wall-wrt-env/diagnosis/immortal-inspect grep -n 'jdcloud_re-cs-02' FETCH_HEAD -- target/linux/qualcommax/image/ipq60xx.mk
FETCH_HEAD:target/linux/qualcommax/image/ipq60xx.mk:109:define Device/jdcloud_re-cs-02
FETCH_HEAD:target/linux/qualcommax/image/ipq60xx.mk:117:	DEVICE_PACKAGES := ath11k-firmware-qcn9074 ipq-wifi-jdcloud_re-cs-02 kmod-ath11k-pci
FETCH_HEAD:target/linux/qualcommax/image/ipq60xx.mk:119:TARGET_DEVICES += jdcloud_re-cs-02
[exit 0]

Actual LibWrt Kconfig spelling (read-only)
$ grep -n '^config TARGET_qualcommax_ipq60xx_DEVICE_jdcloud_re-cs-02$' /workspace/.wall-wrt-env/diagnosis/openwrt/tmp/.config-target.in
79198:config TARGET_qualcommax_ipq60xx_DEVICE_jdcloud_re-cs-02
[exit 0]
```

LAN 查询在脚本中找到的旧地址仅为替换/残留检查的匹配字符串，overlay 中没有旧地址。没有在本次执行构建入口，因此不能声称未来拉取的整个上游源码树已被 patch；实际构建会对所有发现的 config_generate 替换并检查。上游文档/其它平台示例中的旧地址不应作为默认 LAN 残留而全局误改。

## 菜单与语言决策

容器/商店只改可见标题，不改 admin/docker、admin/store。服务使用原生菜单；未创建统一顶级 VPN，保留八个插件的原生路径/ACL（按需求第五节允许选择并说明）。SSID 的 Wall-6E 名字不代表 6 GHz。两个 5g auto 信道按硬件 path 排序仅是确定性回退，低/高频对应必须实机核对。zh_Hans 等 po 目录可能经 luci.mk 别名变成 zh-cn APK，自动扫描会同时生成候选与实际符号，不改主包名称。

## 已知风险与限制

- ImmortalWrt 现在使用参考 CI 的社区 NSS fork，NSS 12.5 提供以太网加速，WiFi 使用正常 ath11k 路径；不能宣称其有 NSS 11.4 的 WiFi offload，也不能沿用之前“全部无 NSS”的性能描述。两条线实际性能差异需实测。测试内核 6.18 与动态 feeds 更新也可能引入新的编译/运行问题。
- 八个透明代理插件的配置可以同时选择，但本次没有编译证明依赖兼容。**运行时只启用一个**，防火墙规则可能互相覆盖；Open-Box 若另行安装也需独占。本仓库未额外添加 Open-Box。
- Tailscale 社区前端 `DEPENDS:=+tailscale` 强制 select；要关闭必须守护与前端同时设 n。
- 按用户提供的故障诊断：Go 1.27 与官方 tailscale 1.98.3 的 json/v2 API 不兼容；保持 whzhni1 替换源，而非无效的 CONFIG_GOLANG_VERSION_1_26 降版本尝试。共用脚本保留模板 laipeng668 Go 源，版本随上游更新；本次没有重现编译错误。
- whzhni1 初始预期 1.102.5，但每日 bot 会改版，不能同时宣称固定版本和自动更新。此仓设置 `ts_omit_ssh`，Tailscale 内置 SSH 不可用。仅该源确实编译失败后，人工采用 `https://github.com/GuNanOvO/openwrt-tailscale` main，其包目录是 `package/tailscale`；脚本不静默回退。
- iStore 官方说明覆盖 x86_64/arm64；本目标虽为 aarch64，qualcommax/ipq60xx 的完整商店运行与应用兼容仍未实机验证。需联网访问 istore.linkease.com。
- iStore UI、nikki-rs、mihomo 构建期下载 GitHub Release 文件可能失败。保留原校验，重跑或排查访问；不修改哈希或关闭 TLS。Nikki RS 禁用回退、FCHomo 冲突时禁用直接 mihomo 选择均需核对当时 Makefile，不能假设 UI 总能补装缺失的强制依赖。
- Passwall 与 firewall4/nftables 共存需实测。已选择 dnsmasq-full；若上游 DEFAULT_PACKAGES.router 仍强制 dnsmasq 且报冲突，人工检查 `include/target.mk` 后将 router 默认中的 dnsmasq 改为 dnsmasq-full，不全局替换无关内容。
- 某些上游 feeds.conf 或嵌套依赖使用 gitcode，访问可能失败。本仓 iStore 固定官方 GitHub 镜像 `src-git istore https://github.com/linkease/istore;main`；其它可修改的嵌套源需核实官方镜像，不猜 URL。要换 istore 主源需同时修改 plugins-clone.sh 的 add_feed 地址，否则下一次准备会恢复它。
- kmod 必须与当前固件的内核 ABI/hash 一致。本仓选定 kmod 直接编进固件；不能在线安装其他构建的 kmod。普通插件依赖也可能引入 kmod，应核对当前源。
- APK 包不允许 lisaac 版本号的 v 前缀，脚本泛化移除数字版本前的 v；runc 保留 GOFLAGS=-buildvcs=false 归档构建修复。上游 Makefile 布局变化会报错或显著警告，需人工核对。
- 静态校验无法验证 NSS、网口、eMMC 分区、Docker cgroup 或最终 APK 依赖解析；多插件、首次工具链与 GitHub runner 磁盘容量也是实际构建风险。

## 需人工核实项

1. ImmortalWrt fork 的测试内核 6.18 / NSS 12.5 实际构建和启动兼容性，特别是正常 ath11k 无线与以太网 NSS 驱动集成；源码支持已核对，但没有实际出包或刷机。
2. 各 openwrt-25.12 feed 中 cloudflared、Lua 运行时、内核选项及各插件依赖的最终 Kconfig/manifest；`CONFIG_KERNEL_BRIDGE_NETFILTER` 在此前 LibWrt 静态定义中不存在，实际内核依赖由 kmod-br-netfilter 提供，已保留你要求的候选并警告。
3. 两个 5g auto radio 的硬件 path 与实际高/低频对应关系、原厂首次安装与跨 flavor 升级布局、128G 数据分区；均需设备验证。
4. 动态包源的实际版本、Po/PKG_NAME 非标准变量写法、翻译别名、原生菜单，以及代理核心/UI 下载功能；源目录扫描不能代替运行验证。
5. mihomo / sing-box 等多源同名包的冲突与 Passwall 默认 dnsmasq 替换是否必要，需真实 defconfig 和编译日志判定。


## 要求交付文件的完整最终内容

以下内容已更新为 ImmortalWrt 修复后的文件快照；当前静态输出新增于 static-checks.txt 和 immortalwrt-fix.md。

### configs/targets.conf

```text
# Plain key=value; scripts/common.sh reads this file without executing it.
libwrt_repo=https://github.com/laipeng668/openwrt-6.x.git
libwrt_branch=25.12-nss
libwrt_package_manager=apk
libwrt_device_config=configs/device.config
libwrt_packages=configs/packages.txt
libwrt_extra_config=configs/libwrt.config
# Same Athena-capable fork as laipeng668/openwrt-ci-roc.
immortalwrt_repo=https://github.com/laipeng668/immortalwrt.git
immortalwrt_branch=openwrt-25.12
immortalwrt_package_manager=apk
immortalwrt_device_config=configs/device.config
immortalwrt_packages=configs/packages.txt
immortalwrt_extra_config=configs/immortalwrt.config
```

### configs/packages.txt

```text
# Container: classic lisaac Lua UI; keep its separate library and compatibility layer.
CONFIG_PACKAGE_dockerd=y
CONFIG_PACKAGE_docker=y
CONFIG_PACKAGE_docker-compose=y
CONFIG_PACKAGE_luci-app-dockerman=y
CONFIG_PACKAGE_luci-lib-docker=y
CONFIG_PACKAGE_luci-compat=y
CONFIG_PACKAGE_luci-lua-runtime=y
CONFIG_PACKAGE_ttyd=y
CONFIG_PACKAGE_luci-app-ttyd=y
CONFIG_PACKAGE_kmod-veth=y
CONFIG_PACKAGE_kmod-br-netfilter=y

# Store: official iStore feed; xz-utils satisfies tar's xz dependency.
CONFIG_PACKAGE_luci-app-store=y
CONFIG_PACKAGE_luci-lib-taskd=y
CONFIG_PACKAGE_taskd=y
CONFIG_PACKAGE_xz-utils=y

# VPN: enable one transparent proxy at runtime.
CONFIG_PACKAGE_luci-app-re-homeproxy=y
CONFIG_PACKAGE_momo=y
CONFIG_PACKAGE_luci-app-momo=y
# CONFIG_PACKAGE_clashoo is not set
# CONFIG_PACKAGE_luci-app-clashoo is not set
CONFIG_PACKAGE_nikki-rs=y
CONFIG_PACKAGE_luci-app-nikki-rs=y
CONFIG_PACKAGE_mihomo=y
CONFIG_PACKAGE_luci-app-fchomo=y
CONFIG_PACKAGE_luci-app-openclash=y
CONFIG_PACKAGE_luci-app-passwall=y
CONFIG_PACKAGE_luci-app-passwall2=y
CONFIG_PACKAGE_luci-app-passwall_Nftables_Transparent_Proxy=y
# CONFIG_PACKAGE_luci-app-passwall_Iptables_Transparent_Proxy is not set
CONFIG_PACKAGE_dnsmasq-full=y
# CONFIG_PACKAGE_dnsmasq is not set

# OpenClash's explicit dependencies; other proxy dependencies come from Makefiles.
CONFIG_PACKAGE_ipset=y
CONFIG_PACKAGE_ip-full=y
CONFIG_PACKAGE_ruby=y
CONFIG_PACKAGE_ruby-yaml=y
CONFIG_PACKAGE_kmod-ipt-nat=y
CONFIG_PACKAGE_iptables-mod-tproxy=y
CONFIG_PACKAGE_iptables-mod-extra=y
CONFIG_PACKAGE_kmod-inet-diag=y
CONFIG_PACKAGE_kmod-nft-tproxy=y
CONFIG_PACKAGE_kmod-tun=y
CONFIG_PACKAGE_bash=y
CONFIG_PACKAGE_curl=y
CONFIG_PACKAGE_unzip=y

# Services: Tailscale daemon + community UI must be disabled together.
CONFIG_PACKAGE_tailscale=y
CONFIG_PACKAGE_luci-app-tailscale-community=y
CONFIG_PACKAGE_cloudflared=y
CONFIG_PACKAGE_luci-app-cloudflared=y
# Intentional alternatives: defconfig keeps the symbol this feed defines.
CONFIG_PACKAGE_luci-i18n-cloudflared-zh_Hans=y
CONFIG_PACKAGE_luci-i18n-cloudflared-zh-cn=y
CONFIG_PACKAGE_luci-app-adguardhome=y
# AdGuardHome core is downloaded in its UI; no official core or acdn replacement.
# CONFIG_PACKAGE_adguardhome is not set
# CONFIG_PACKAGE_luci-app-acdn is not set
# CONFIG_PACKAGE_luci-app-homeproxy is not set
# CONFIG_PACKAGE_luci-app-nikki is not set

# Preserve useful template defaults without pulling unrelated custom repositories.
CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-app-argon-config=y
CONFIG_PACKAGE_athena-led=y
CONFIG_PACKAGE_luci-app-athena-led=y
CONFIG_PACKAGE_iw-full=y
# CONFIG_PACKAGE_iw is not set
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-app-ddns=y
CONFIG_PACKAGE_ddns-scripts-cloudflare=y
CONFIG_PACKAGE_luci-app-upnp=y
CONFIG_PACKAGE_luci-app-wol=y
CONFIG_PACKAGE_luci-app-samba4=y
CONFIG_PACKAGE_luci-app-autoreboot=y
CONFIG_PACKAGE_luci-app-cpufreq=y
CONFIG_PACKAGE_luci-proto-wireguard=y
CONFIG_PACKAGE_luci-app-watchcat=y
CONFIG_PACKAGE_htop=y
CONFIG_PACKAGE_nano-full=y
CONFIG_PACKAGE_fdisk=y
CONFIG_PACKAGE_fstrim=y
CONFIG_PACKAGE_openssh-sftp-server=y

# Argon is the requested default; override the reference Aurora selection.
# CONFIG_PACKAGE_luci-theme-aurora is not set
# CONFIG_PACKAGE_luci-app-aurora-config is not set
```

### scripts/plugins-clone.sh

```bash
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
fi
if package_enabled momo luci-app-momo; then
  rm -rf feeds/packages/net/momo feeds/luci/applications/luci-app-momo
  clone_repository https://github.com/nikkinikki-org/OpenWrt-momo main package/OpenWrt-momo
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
```

### scripts/sync-upstream.sh

```bash
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
```

### scripts/gen-i18n.sh

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Read source Makefiles and actual po directories; no hard-coded app list.
python3 "$SCRIPT_ROOT/firmware-config.py" i18n "${1:-$PWD}"
```

### files/etc/config/network

本次参考基线改造已删除此文件，网络由上游设备初始化生成。

### files/etc/uci-defaults/00-athena-network-merge

本次参考基线改造已删除此文件，网络由上游设备初始化生成。

### files/etc/uci-defaults/99-athena-defaults

```text
#!/bin/sh
SSID_2G='Wall'
SSID_5G_LOW='Wall-5G'
SSID_5G_HIGH='Wall-6E'

# On upgrades retaining settings, leave the user's working configuration intact.
[ -e /etc/config/.athena-defaults-applied ] && exit 0
# boot normally generates wireless before running uci-defaults. Retry on next
# boot when no radios exist yet, rather than consuming the one-shot defaults.
radios="$(uci -q show wireless | sed -n 's/^wireless\.\([^.=]*\)=wifi-device$/\1/p')"
[ -n "$radios" ] || exit 1

# Order the two 5 GHz radios by channel, falling back to their stable physical
# paths for auto channels. Never depend on radio0/radio1/radio2 enumeration.
five_ghz=''
for radio in $radios; do
        band="$(uci -q get "wireless.$radio.band")"
        [ "$band" = 5g ] || continue
        channel="$(uci -q get "wireless.$radio.channel")"
        case "$channel" in ''|*[!0-9]*) channel=999 ;; esac
        path="$(uci -q get "wireless.$radio.path")"
        five_ghz="$five_ghz
$channel $path $radio"
done
low_radio="$(printf '%s\n' "$five_ghz" | sed '/^$/d' | sort -n -k1,1 -k2,2 | head -n 1 | awk '{print $NF}')"

interfaces="$(uci -q show wireless | sed -n 's/^wireless\.\(default_radio[^.=]*\)=wifi-iface$/\1/p')"
[ -n "$interfaces" ] || exit 1
for interface in $interfaces; do
        radio="$(uci -q get "wireless.$interface.device")"
        band="$(uci -q get "wireless.$radio.band")"
        case "$band" in
                2g) ssid="$SSID_2G" ;;
                5g)
                        if [ "$radio" = "$low_radio" ]; then ssid="$SSID_5G_LOW"; else ssid="$SSID_5G_HIGH"; fi
                        ;;
                *) continue ;;
        esac
        uci set "wireless.$interface.ssid=$ssid" || exit 1
done
uci commit wireless || exit 1
# Persistent marker is included by sysupgrade's /etc/config preservation.
touch /etc/config/.athena-defaults-applied
# Leave activation, channels, country, bridge and DHCP to upstream defaults.
exit 0
```

### .github/workflows/build.yml

```yaml
name: 编译雅典娜固件（LibWrt / ImmortalWrt）

on:
  workflow_dispatch:
    inputs:
      flavor:
        description: 选择编译分支
        required: true
        type: choice
        default: all
        options:
          - all
          - libwrt
          - immortalwrt
  push:
    branches: [master]
    paths:
      - 'build.sh'
      - 'configs/**'
      - 'scripts/**'
      - 'packages/**'
      - 'files/**'
      - '.github/workflows/build.yml'
      - '.github/workflows/release.yml'
  schedule:
    - cron: '17 3 * * *'

permissions:
  contents: read

defaults:
  run:
    shell: bash

concurrency:
  group: athena-${{ github.ref }}
  cancel-in-progress: false

jobs:
  validate:
    name: 静态检查 / 工作流入口
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
      - name: Install ShellCheck
        run: |
          sudo apt-get update
          sudo apt-get install -y --no-install-recommends shellcheck
      - name: Static checks
        run: |
          for script in build.sh scripts/*.sh files/etc/uci-defaults/* files/usr/sbin/*; do bash -n "$script"; done
          shellcheck build.sh scripts/*.sh
          shellcheck -s sh files/etc/uci-defaults/* files/usr/sbin/*
          python3 -c 'import ast,json,pathlib; [ast.parse(p.read_text()) for p in pathlib.Path("scripts").glob("*.py")]; [json.loads(p.read_text()) for p in pathlib.Path("files").rglob("*.json")]'
  build:
    name: Athena / ${{ matrix.flavor }}
    needs: validate
    # Register the entry via a real push run, without starting a firmware build.
    # Normal pushes, daily schedules and manual dispatches still compile.
    if: github.event_name != 'push' || !contains(github.event.head_commit.message, '[workflow-register]')
    runs-on: ubuntu-24.04
    timeout-minutes: 360
    strategy:
      fail-fast: false
      matrix:
        flavor: ${{ fromJSON(github.event_name == 'workflow_dispatch' && inputs.flavor != 'all' && format('["{0}"]', inputs.flavor) || '["libwrt","immortalwrt"]') }}
    env:
      FLAVOR: ${{ matrix.flavor }}
      TZ: Asia/Shanghai
      # Keep concurrent compiler processes within the hosted runner's memory.
      JOBS: '2'
    steps:
      - uses: actions/checkout@v4
      - name: Install prerequisites
        run: |
          sudo apt-get update
          sudo apt-get install -y --no-install-recommends \
            build-essential clang flex bison gawk gettext git rsync unzip \
            libncurses-dev libssl-dev libelf-dev zlib1g-dev \
            python3 python3-setuptools python3-dev swig wget curl file \
            zstd ccache shellcheck
          df -h .
      - name: Sync upstream and feeds (no compilation)
        run: bash scripts/sync-upstream.sh
      - name: Cache identity
        id: identity
        run: |
          echo "date=$(date -u +%Y%m%d)" >> "$GITHUB_OUTPUT"
          echo "lock=$(sha256sum upstream-lock.txt | cut -d ' ' -f 1)" >> "$GITHUB_OUTPUT"
      - name: Download cache
        uses: actions/cache@v4
        with:
          path: sources/${{ matrix.flavor }}/dl
          key: dl-${{ runner.os }}-${{ matrix.flavor }}-${{ steps.identity.outputs.lock }}
          restore-keys: dl-${{ runner.os }}-${{ matrix.flavor }}-
      - name: Temporary metadata cache
        uses: actions/cache@v4
        with:
          path: sources/${{ matrix.flavor }}/tmp
          key: tmp-${{ runner.os }}-${{ matrix.flavor }}-${{ steps.identity.outputs.lock }}-${{ steps.identity.outputs.date }}-${{ hashFiles('configs/**', 'scripts/**', 'build.sh') }}
      - name: Compiler cache
        uses: actions/cache@v4
        with:
          path: sources/${{ matrix.flavor }}/.ccache
          key: ccache-${{ runner.os }}-${{ matrix.flavor }}-${{ steps.identity.outputs.lock }}-${{ github.run_id }}
          restore-keys: ccache-${{ runner.os }}-${{ matrix.flavor }}-
      - name: Build Athena only
        run: bash build.sh
      - name: Firmware
        uses: actions/upload-artifact@v4
        with:
          name: Athena-${{ matrix.flavor }}-${{ steps.identity.outputs.date }}-${{ github.run_id }}
          path: artifacts/${{ matrix.flavor }}/
          if-no-files-found: error
          retention-days: 14
      - name: Logs and upstream revisions
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: Athena-${{ matrix.flavor }}-logs-${{ github.run_id }}
          path: |
            logs/${{ matrix.flavor }}.log
            upstream-lock.txt
            sources/${{ matrix.flavor }}/config-audit.txt
            sources/${{ matrix.flavor }}/source-support.txt
            sources/${{ matrix.flavor }}/third-party-sources.txt
            sources/${{ matrix.flavor }}/i18n-map.txt
          if-no-files-found: warn
  release:
    name: 发布带日期的固件
    needs: build
    permissions:
      actions: read
      contents: write
    uses: ./.github/workflows/release.yml
    with:
      run_id: ${{ format('{0}', github.run_id) }}
```

## 核心入口的完整内容

### build.sh

```bash
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
```

### configs/device.config

```text
# Athena only. firmware-config.py resolves this spelling against upstream Kconfig.
CONFIG_TARGET_qualcommax=y
CONFIG_TARGET_qualcommax_ipq60xx=y
CONFIG_TARGET_qualcommax_ipq60xx_DEVICE_jdcloud_re_cs_02=y
# CONFIG_TARGET_MULTI_PROFILE is not set
# CONFIG_TARGET_ALL_PROFILES is not set
# CONFIG_TARGET_PER_DEVICE_ROOTFS is not set
CONFIG_TARGET_ROOTFS_SQUASHFS=y
CONFIG_DEVEL=y
CONFIG_CCACHE=y
CONFIG_LUCI_LANG_zh_Hans=y
CONFIG_KERNEL_CGROUPS=y
CONFIG_KERNEL_CGROUP_FREEZER=y
# kmod-br-netfilter supplies CONFIG_BRIDGE_NETFILTER in the kernel config.
CONFIG_DOCKER_CGROUP_OPTIONS=y
```

### configs/libwrt.config

```text
# WiFi NSS offload requires 11.4 on this LibWrt IPQ60xx branch.
CONFIG_NSS_FIRMWARE_VERSION_11_4=y
CONFIG_ATH11K_MEM_PROFILE_512M=y
CONFIG_ATH11K_NSS_SUPPORT=y
CONFIG_ATH11K_NSS_MESH_SUPPORT=y
# CONFIG_NSS_FIRMWARE_VERSION_12_5 is not set
```

### configs/immortalwrt.config

```text
# Match openwrt-ci-roc's JDCloud line; device selection stays Athena-only.
CONFIG_TESTING_KERNEL=y
CONFIG_ATH11K_MEM_PROFILE_512M=y
CONFIG_NSS_FIRMWARE_VERSION_12_5=y
# CONFIG_NSS_FIRMWARE_VERSION_11_4 is not set
# IPQ60xx NSS 12.5 does not provide WiFi offload; keep normal ath11k WiFi.
# CONFIG_ATH11K_NSS_SUPPORT is not set
# CONFIG_ATH11K_NSS_MESH_SUPPORT is not set
```

### scripts/common.sh

```bash
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
```

### scripts/firmware-config.py

```python
#!/usr/bin/env python3
"""Source-only configuration, revision records and Athena artifact checks."""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys


REQUIRED_PACKAGES = {'dnsmasq-full', 'luci-theme-argon', 'luci-app-argon-config', 'athena-led', 'luci-app-athena-led',
            'dockerd', 'docker', 'docker-compose', 'luci-app-dockerman', 'luci-lib-docker',
            'kmod-br-netfilter', 'kmod-veth', 'luci-app-store', 'tailscale', 'luci-app-tailscale-community', 'cloudflared', 'luci-app-cloudflared',
            'luci-app-re-homeproxy', 'momo', 'luci-app-momo',
            'nikki-rs', 'luci-app-nikki-rs', 'mihomo', 'luci-app-fchomo', 'luci-app-openclash',
            'luci-app-passwall', 'luci-app-passwall2', 'luci-app-adguardhome'}

def git(directory, *args):
    return subprocess.check_output(["git", "-C", str(directory), *args], text=True).strip()


def assignments(path):
    values = {}
    for line in path.read_text().splitlines():
        line = re.sub(r"\s+#.*$", "", line).strip()
        match = re.fullmatch(r"(CONFIG_[\w-]+)=(.*)", line)
        disabled = re.fullmatch(r"# (CONFIG_[\w-]+) is not set", line)
        if match:
            values[match[1]] = match[2]
        elif disabled:
            values[disabled[1]] = "n"
    return values


def selected_devices(values):
    return [key for key, value in values.items()
            if "_DEVICE_" in key and key.startswith("CONFIG_TARGET_")
            and value in ("y", "m")]


def is_athena(key):
    return key.endswith("_DEVICE_jdcloud_re_cs_02") or key.endswith("_DEVICE_jdcloud_re-cs-02")


def check_source(source, flavor):
    """Read upstream files only, before feeds or make; never fabricate a profile."""
    target = source / "target/linux/qualcommax"
    image = target / "image/ipq60xx.mk"
    text = image.read_text()
    if not re.search(r"^define Device/jdcloud_re-cs-02\s*$", text, re.M) or not re.search(
            r"^TARGET_DEVICES\s*\+=\s*jdcloud_re-cs-02\s*$", text, re.M):
        raise ValueError("Upstream has no Athena image definition; check the configured repository/branch")
    required = [target / "files/arch/arm64/boot/dts/qcom/ipq6010-re-cs-02.dts",
                target / "files/arch/arm64/boot/dts/qcom/ipq6010-re-cs.dtsi"]
    for path in required:
        if not path.is_file():
            raise ValueError(f"Missing Athena device tree: {path}")
    files = [target / "ipq60xx/base-files" / name for name in (
        "etc/board.d/02_network", "etc/hotplug.d/firmware/11-ath11k-caldata", "lib/upgrade/platform.sh")]
    for path in files:
        if "jdcloud,re-cs-02" not in path.read_text():
            raise ValueError(f"Missing Athena board integration: {path}")
    if "$(call Device/EmmcImage)" not in text.split("define Device/jdcloud_re-cs-02", 1)[1].split("endef", 1)[0]:
        raise ValueError("Athena eMMC image layout changed; review upstream")
    print(f"{flavor}: Athena image/device-tree/network/calibration/eMMC integration found")
    print(f"Source commit: {git(source, 'rev-parse', 'HEAD')}")
    if flavor == "immortalwrt":
        makefile = (target / "Makefile").read_text()
        kernel = re.search(r"^KERNEL_TESTING_PATCHVER\s*:?=\s*(\S+)", makefile, re.M)
        if not kernel:
            raise ValueError("ImmortalWrt fork no longer defines its testing kernel")
        if "src-git nss_packages " not in (source / "feeds.conf.default").read_text():
            raise ValueError("ImmortalWrt fork's NSS feed definition is missing")
        print(f"ImmortalWrt testing kernel: {kernel[1]}; NSS feed present")


def flavor_requirements(flavor):
    if flavor == "libwrt":
        return {"CONFIG_NSS_FIRMWARE_VERSION_11_4": "y"}
    if flavor == "immortalwrt":
        return {"CONFIG_TESTING_KERNEL": "y", "CONFIG_NSS_FIRMWARE_VERSION_12_5": "y",
                "CONFIG_ATH11K_MEM_PROFILE_512M": "y",
                "CONFIG_ATH11K_NSS_SUPPORT": "n", "CONFIG_ATH11K_NSS_MESH_SUPPORT": "n"}
    raise ValueError(f"Unknown flavor: {flavor}")


def select_device(config, metadata):
    available = set(re.findall(r"^config (TARGET_qualcommax_ipq60xx_DEVICE_\S+)$",
                               metadata.read_text(), re.M))
    candidates = ["TARGET_qualcommax_ipq60xx_DEVICE_jdcloud_re_cs_02",
                  "TARGET_qualcommax_ipq60xx_DEVICE_jdcloud_re-cs-02"]
    symbol = next((key for key in candidates if key in available), None)
    if not symbol:
        raise ValueError("Upstream has no Athena RE-CS-02 profile. Do not compile another device. "
                         "Use the Athena-capable fork configured in targets.conf.")
    lines = [line for line in config.read_text().splitlines()
             if not re.match(r"(?:# )?CONFIG_TARGET_.*_DEVICE_", line)
             and not re.match(r"(?:# )?CONFIG_TARGET_(?:MULTI_PROFILE|ALL_PROFILES|PER_DEVICE_ROOTFS)\b", line)]
    lines += [f"CONFIG_{symbol}=y", "# CONFIG_TARGET_MULTI_PROFILE is not set",
              "# CONFIG_TARGET_ALL_PROFILES is not set", "# CONFIG_TARGET_PER_DEVICE_ROOTFS is not set"]
    config.write_text("\n".join(lines) + "\n")
    print(f"Athena profile resolved from upstream metadata: CONFIG_{symbol}=y")


def audit(config, packages, flavor):
    values = assignments(config)
    expected = assignments(packages)
    warnings = [f"{key}=y (missing or not built-in)" for key, value in expected.items()
                if key.startswith("CONFIG_PACKAGE_") and value == "y" and values.get(key) != "y"
                and not (key.startswith("CONFIG_PACKAGE_luci-i18n-") and key.endswith("-zh_Hans")
                         and values.get(key.removesuffix("-zh_Hans") + "-zh-cn") == "y")]
    missing_required = sorted(package for package in REQUIRED_PACKAGES
                              if values.get(f"CONFIG_PACKAGE_{package}") != "y")
    if missing_required:
        raise ValueError(f"Required guide/runtime packages not built-in: {missing_required}")
    if any(values.get(f"CONFIG_PACKAGE_{package}") in ("y", "m")
           for package in ("clashoo", "luci-app-clashoo")):
        raise ValueError("Clashoo is excluded from Athena firmware")
    devices = selected_devices(values)
    if len(devices) != 1 or not all(is_athena(key) for key in devices):
        warnings.append(f"Selected devices must be Athena only: {devices}")
    if values.get("CONFIG_TARGET_MULTI_PROFILE") == "y":
        warnings.append("Multiple-device mode is still enabled")
    for key in ("CONFIG_KERNEL_CGROUPS", "CONFIG_KERNEL_CGROUP_FREEZER",
                "CONFIG_DOCKER_CGROUP_OPTIONS", "CONFIG_PACKAGE_kmod-br-netfilter"):
        if values.get(key) != "y":
            warnings.append(f"Docker prerequisite missing: {key}")
    for key, value in flavor_requirements(flavor).items():
        if values.get(key, "n") != value:
            warnings.append(f"{flavor} requires {key}={value}")
    if warnings:
        print("\n" + "!" * 72 + "\nWARNING: FINAL CONFIGURATION DIFFERS FROM REQUEST")
        print("\n".join(f"  - {warning}" for warning in warnings))
        print("Compilation continues; review this log before flashing.\n" + "!" * 72)
        print("::warning::Final configuration differs from request; see config-audit.txt")
    else:
        print("Configuration audit passed: Athena only; expected packages built-in.")


def i18n(source):
    config = source / ".config"
    active = assignments(config)
    generated = set()
    seen = set()
    alias_file = source / "feeds/luci/luci.mk"
    aliases = dict(re.findall(r"^LUCI_LC_ALIAS\.([\w-]+)\s*:?=\s*([\w-]+)",
                             alias_file.read_text() if alias_file.exists() else "", re.M))
    rows = ["Package\tPO directory\tGenerated i18n package"]
    for base in (source / "feeds", source / "package"):
        if not base.exists():
            continue
        for makefile in sorted(base.rglob("Makefile")):
            app = makefile.parent
            if not app.name.startswith("luci-app-") or app.resolve() in seen:
                continue
            seen.add(app.resolve())
            text = makefile.read_text(errors="replace")
            match = re.search(r"^PKG_NAME\s*[:?+]?=\s*(luci-app-[\w-]+)\s*$", text, re.M)
            name = match[1] if match else app.name  # luci.mk defaults PKG_NAME to directory name.
            if active.get(f"CONFIG_PACKAGE_{name}") != "y":
                continue
            po = app / "po"
            for lang in ("zh-cn", "zh_Hans"):
                if not (po / lang).is_dir() or not any((po / lang).glob("*.po")):
                    continue
                # First write the requested po-based candidate; when luci.mk
                # aliases it, also write that actual package symbol. defconfig
                # removes the undefined alternative without losing translation.
                candidate = f"luci-i18n-{name.removeprefix('luci-app-')}-{lang}"
                actual = f"luci-i18n-{name.removeprefix('luci-app-')}-{aliases.get(lang, lang)}"
                generated.update((f"CONFIG_PACKAGE_{candidate}=y", f"CONFIG_PACKAGE_{actual}=y"))
                rows.append(f"{name}\t{lang}\t{actual}" + (f" (candidate {candidate})" if candidate != actual else ""))
    lines = config.read_text().splitlines()
    existing = set(lines)
    config.write_text("\n".join(lines + sorted(generated - existing)) + "\n")
    (source / "i18n-map.txt").write_text("\n".join(rows) + "\n")
    print("\n".join(rows))


def network_patch(source):
    path = source / "package/base-files/files/bin/config_generate"
    text = path.read_text()
    if not any(address in text for address in ("192.168.1.1", "192.168.2.1", "192.168.6.1")):
        raise ValueError("Upstream LAN default changed; inspect config_generate")
    text = text.replace("192.168.1.1", "192.168.6.1").replace("192.168.2.1", "192.168.6.1")
    text, count = re.subn(r"(set system\.@system\[-1\]\.hostname=)'[^']*'",
                         r"\1'Wall-WRT'", text)
    if count != 1:
        raise ValueError("Upstream default hostname layout changed; inspect config_generate")
    path.write_text(text)
    print(f"Default hostname/LAN source patched: {path.relative_to(source)}")


def lock(source, destination, flavor):
    import fcntl  # Only source-sync locking needs Unix; syntax checks work on macOS too.
    records = [f"{flavor}\tsource\t{git(source, 'remote', 'get-url', 'origin')}\t"
               f"{git(source, 'rev-parse', 'HEAD')}"]
    print(f"{flavor}: source {git(source, 'rev-parse', '--short', 'HEAD')}")
    for feed in sorted((source / "feeds").iterdir()):
        if not feed.is_dir() or not (feed / ".git").exists():
            continue
        sha = git(feed, "rev-parse", "HEAD")
        records.append(f"{flavor}\tfeed:{feed.name}\t{git(feed, 'remote', 'get-url', 'origin')}\t{sha}")
        print(f"{flavor}: feed {feed.name} {sha[:12]}")
    # Two CI matrix jobs use separate files; local all mode shares this lock.
    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open("a+") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        handle.seek(0)
        retained = [line for line in handle.read().splitlines()
                    if line and not line.startswith("#") and not line.startswith(flavor + "\t")]
        handle.seek(0)
        handle.truncate()
        handle.write("# flavor\tcomponent\trepository\tcommit (observed checkout HEAD; not version pins)\n")
        handle.write("\n".join(sorted(retained + records)) + "\n")


def artifacts(source, output, flavor):
    values = assignments(source / ".config")
    if any(values.get(f"CONFIG_PACKAGE_{package}") in ("y", "m")
           for package in ("clashoo", "luci-app-clashoo")):
        raise ValueError("Clashoo is excluded from Athena firmware")
    devices = selected_devices(values)
    if len(devices) != 1 or not is_athena(devices[0]) or values.get("CONFIG_TARGET_MULTI_PROFILE") == "y":
        raise ValueError("Refusing artifacts: final configuration is not Athena only")
    for key, value in flavor_requirements(flavor).items():
        if values.get(key, "n") != value:
            raise ValueError(f"Refusing {flavor} artifacts: {key} must be {value}")
    if values.get("CONFIG_TARGET_BOARD") != '"qualcommax"' or values.get("CONFIG_TARGET_SUBTARGET") != '"ipq60xx"':
        raise ValueError("Refusing artifacts: target is not qualcommax/ipq60xx")
    target = source / "bin/targets/qualcommax/ipq60xx"
    images = [path for path in target.glob("*") if path.is_file()
              and "jdcloud_re-cs-02" in path.name and path.suffix in (".bin", ".itb", ".img", ".gz")]
    other = [path.name for path in target.glob("*") if path.is_file()
             and path.suffix in (".bin", ".itb", ".img", ".gz") and "jdcloud_re-cs-02" not in path.name]
    if other:
        raise ValueError(f"Unexpected non-Athena images: {other}")
    if not any("sysupgrade" in path.name and path.stat().st_size for path in images):
        raise ValueError("No nonempty Athena sysupgrade image was generated")
    if not any("factory" in path.name and path.stat().st_size for path in images):
        raise ValueError("No nonempty Athena factory image was generated")
    if any(not path.stat().st_size for path in images):
        raise ValueError("An Athena image is empty")
    manifests = list(target.glob("*.manifest"))
    if not manifests:
        raise ValueError("No firmware manifest was generated")
    installed = {line.split()[0] for path in manifests for line in path.read_text().splitlines() if line.strip()}
    required = REQUIRED_PACKAGES
    if not required <= installed:
        raise ValueError(f"Required runtime packages missing: {sorted(required - installed)}")
    missing = [key.removeprefix("CONFIG_PACKAGE_") for key, value in values.items()
               if value == "y" and key.startswith("CONFIG_PACKAGE_luci-app-") and key.removeprefix("CONFIG_PACKAGE_") not in installed]
    if missing:
        print(f"::warning::LuCI packages missing from installed manifest: {', '.join(missing)}")
    output.mkdir(parents=True, exist_ok=True)
    for path in images + manifests + list(target.glob("*.buildinfo")) + list(target.glob("profiles.json")):
        shutil.copy2(path, output / path.name)
    shutil.copy2(source / ".config", output / "firmware.config")
    shutil.copy2(source / "i18n-map.txt", output / "i18n-map.txt")
    (output / "build-info.json").write_text(json.dumps({"flavor": flavor, "device": "jdcloud_re-cs-02",
                                                      "source_commit": git(source, "rev-parse", "HEAD")}, indent=2) + "\n")
    print(f"Athena images collected: {output}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("check-source", "select-device", "audit", "i18n", "network", "lock", "artifacts"))
    parser.add_argument("paths", nargs="+")
    args = parser.parse_args()
    functions = {"check-source": check_source, "select-device": select_device, "audit": audit, "i18n": i18n,
                 "network": network_patch, "lock": lock, "artifacts": artifacts}
    converted = [Path(value) if index < {"check-source": 1, "select-device": 2, "audit": 2, "i18n": 1,
                                        "network": 1, "lock": 2, "artifacts": 2}[args.operation] else value
                 for index, value in enumerate(args.paths)]
    try:
        functions[args.operation](*converted)
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

## 自动发布 Releases（2026-10-09）

新增 `.github/workflows/release.yml` 与 `scripts/prepare-release.py`。固件构建成功后调用发布工作流；也可输入历史成功构建的 run ID 补发。仅发布 master 的固件构建，校验原始 SHA256SUMS，日期取自原始 artifact 名；每个镜像文件名包含分支、日期与构建编号，发布后重新生成对应 SHA256SUMS。

发布补充：本次固件已发布到 `athena-20261008-37795451532`，9 个附件均上传成功。自动创建版本的步骤分为创建源码标签、建立 Release 草稿、上传附件、公开 Release，上传失败时新版本保留草稿。发布错误同时写入运行摘要及 annotation。

命名调整：Release 标题为 `京东雅典娜AX6600 YYYY-MM-DD`，固件附件为 `JDCloud-Athena-<分支>-YYYYMMDD-<构建编号>-sysupgrade.bin` / `factory.bin` / `initramfs.itb`，不再包含目标平台、设备符号、文件系统或重复分支。资料包沿用同前缀的 `info.zip`。

实机反馈修复：新增源码构建的雅典娜屏幕包、Argon 默认设置和无线/DHCP诊断命令；修正首次配置与包完整性校验。证据和实机验证限制见 [修复记录](runtime-fixes.md)。
