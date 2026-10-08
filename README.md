<div align="center">
<h1>Wall-WRT — 雅典娜 AX6600 云编译</h1>
</div>

本仓库只收集京东云雅典娜 RE-CS-02（`jdcloud_re-cs-02`）的固件，目标固定为 `qualcommax/ipq60xx`。保留原 Bash 脚本、Kconfig 配置和 Actions 工作方式，将插件来源抽为共用脚本，移除旧的多设备固件入口与失效的触发器。独立 SDK 工具仍保留为手动工具；不参与固件流水线。

**本次仅做静态校验，没有执行编译、刷机或运行插件。不能据此保证完整固件编译成功。**

## 双分支与设备支持

| FLAVOR | 仓库 | 跟踪分支 | 包格式 | NSS / 当前设备状态 |
|---|---|---|---|---|
| `libwrt` | https://github.com/LiBwrt/LibWrt.git | `25.12-nss` | apk | NSS 11.4，开启 WiFi offload；已有 RE-CS-02 定义 |
| `immortalwrt` | https://github.com/immortalwrt/immortalwrt.git | `openwrt-25.12` | apk | 不选择 NSS 固件/加速；**当前官方稳定分支没有 RE-CS-02 定义，会明确失败** |

2026-10-08 静态核对：LibWrt `3a3d0b08595530070ad9cd8a20c0ae4ea3e77f70` 有雅典娜；ImmortalWrt 稳定分支 `89dfac46c9f1eaeb56c6cf49eb289b4475f446f7` 没有。ImmortalWrt master `8735c686ae30fe85d94de97669399c2117179f82` 已有雅典娜定义，但内核为 6.18，稳定分支为 6.12。不能只复制 DTS 或偷偷换分支就宣称兼容：需要人工审核设备树、校准数据、镜像布局、网口和 eMMC 升级支持的回移植。此处保留你指定的仓库与分支，第二条线的**构建入口已接好，实际出包仍受设备支持阻塞**。

`configs/device.config` 使用你要求的下划线设备符号并关闭多机型。实际 LibWrt Kconfig 由 `scripts/target-metadata.pl` 生成，目前定义的是 `CONFIG_TARGET_qualcommax_ipq60xx_DEVICE_jdcloud_re-cs-02`；连字符并非无效。构建会读取 `tmp/.config-target.in`，只在确实定义了对应符号时解析为该形式，再执行 defconfig。两种拼写都不存在则停止，防止 Kconfig 默认选中其他设备。最终 .config 中其他设备的 `# … is not set` 属于上游正常输出，不代表构建它们。

## 本地 / 云构建

配置入口：`configs/targets.conf` 描述源码、分支和配置路径；`configs/device.config` 为共用设备设置；`configs/libwrt.config` 只含 NSS 等 LibWrt 选项；`configs/immortalwrt.config` 不含 NSS；`configs/packages.txt` 是唯一插件选择清单。关包用 `=n` 或 `# CONFIG_PACKAGE_xxx is not set`，最后一条设置生效。

Linux 构建命令（本次未执行）：

```bash
FLAVOR=libwrt JOBS=4 bash build.sh
FLAVOR=immortalwrt JOBS=4 bash build.sh
FLAVOR=all JOBS=4 bash build.sh  # 默认 all，一条线失败仍尝试另一条
```

源码位于 `sources/<flavor>/`。已有目录每次执行 fetch + reset --hard 到跟踪分支最新提交；这是专用生成目录，**不要把 SOURCE_ROOT 指向有个人修改的源码工作目录**。插件也每次删除专用目录重新浅克隆。上游动态更新不固定在 lock 的历史版本，构建中仍保留原下载哈希检查。

只同步源码与 feeds，不编译：

```bash
FLAVOR=all bash scripts/sync-upstream.sh
# 打印每个 source/feed 的短 SHA，并写入 upstream-lock.txt。
git add upstream-lock.txt
# 审核 diff 后自行提交；脚本不自动提交或推送。
```

仓库内初始 lock 是本次只读查询的远端分支 HEAD 快照，注释明确标识；第一次 sync 会替换为本地同步后实际 source/feed HEAD。插件完整 SHA 单独写入每条线的 `third-party-sources.txt`，它与 lock 一起随产物保存。日志在 `logs/<flavor>.log`。

Actions 运行 **Athena firmware**：手动、master 构建代码 push、每天 03:17 UTC 触发；两条线独立 matrix，`fail-fast: false`。成功固件上传为 `Athena-<flavor>-<日期>-<run_id>`，失败也保留日志。不会自动发布 Release 或改写仓库。每日更新能检测破坏，不能自动修复上游破坏；可从仍保留的成功 artifact 取回此前版本。

缓存 `dl/`、`tmp/`、ccache。tmp 按源码/feed SHA、配置与日期隔离，插件替换后重新生成设备/包元数据。不会恢复 staging_dir 或伪造 stamp。缓存不能省略首次工具链编译，**不保证一小时完成**；Actions 上限 360 分钟，首次下载、磁盘容量和大量 Go/Rust 包可能成为瓶颈。

可选 Linux 容器（本次未构建镜像）：

```bash
BUILD_UID=$(id -u) BUILD_GID=$(id -g) FLAVOR=libwrt docker compose run --build --rm firmware
```

宿主挂载当前目录，编译用户为非 root。macOS 原生不能编译，本次不在 macOS 或容器中执行编译；跨架构 Linux 容器的可用性也没有验证。

## 插件矩阵

| 分类 / 插件 | 包名 | 仓库（来源） | 分支 | 菜单位置 | 核心来源 |
|---|---|---|---|---|---|
| 容器 · Docker | dockerd / docker / docker-compose | 官方 packages feed | 随目标 feed | 命令行 / 容器 | 构建时编译 |
| 容器 · Dockerman | luci-app-dockerman / luci-lib-docker / luci-compat / ttyd | https://github.com/lisaac/luci-app-dockerman + https://github.com/lisaac/luci-lib-docker | master / master | 顶级「容器」 | 经典 Lua UI，库独立仓库 |
| 商城 · iStore | luci-app-store / luci-lib-taskd / taskd | https://github.com/linkease/istore | main | 顶级「商店」 | 前端构建时从 istore-ui Release 下载，应用在线安装 |
| VPN · RE:HomeProxy | luci-app-re-homeproxy | https://github.com/1andrevich/homeproxy-hiddify | master | 原生菜单（通常服务） | 刷机后 Core & Tools 下载 hiddify-core / sing-box-extended |
| VPN · momo | momo / luci-app-momo | https://github.com/nikkinikki-org/OpenWrt-momo | main | 原生菜单 | 由 Makefile 依赖提供 sing-box |
| VPN · Clashoo | clashoo / luci-app-clashoo | https://github.com/kenzok8/openwrt-clashoo | main | 原生菜单 | UI 下载 mihomo / sing-box，不覆盖系统 sing-box |
| VPN · Nikki RS | nikki-rs / luci-app-nikki-rs | https://github.com/CHKayanami/OpenWrt-nikki-rs | main | 原生菜单 | 构建期从 Release 下载 clash-rs |
| VPN · FullCombo Shark | mihomo / luci-app-fchomo | https://github.com/fcshark-org/openwrt-fchomo | master | 原生菜单 | mihomo 随包下载 |
| VPN · OpenClash | luci-app-openclash | https://github.com/vernesong/OpenClash.git | master | 原生菜单 | UI 下载核心 |
| VPN · Passwall | luci-app-passwall | https://github.com/Openwrt-Passwall/openwrt-passwall.git | main | 原生菜单 | pw_packages 编译依赖 |
| VPN · Passwall2 | luci-app-passwall2 | https://github.com/Openwrt-Passwall/openwrt-passwall2.git | main | 原生菜单 | pw_packages 编译依赖 |
| VPN · 共同依赖 | 按依赖解析 | https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git | main | 无单独菜单 | 与两个 Passwall feed 配套 |
| 服务 · Tailscale | tailscale | https://github.com/whzhni1/luci-app-tailscale | main | 社区前端的服务菜单 | feed 原位替换，初始预期 1.102.5，随后跟随 bot 更新 |
| 服务 · Tailscale 社区前端 | luci-app-tailscale-community | https://github.com/Tokisaki-Galaxy/luci-app-tailscale-community | master | 服务 | 强制依赖 tailscale |
| 服务 · Cloudflare | cloudflared / luci-app-cloudflared | 目标官方 packages / luci feed | 随目标 feed | 服务 | 官方 feed 编译 |
| 服务 · AdGuardHome | luci-app-adguardhome | https://github.com/rufengsuixing/luci-app-adguardhome | master | 服务 | 只编 Lua 管理页；刷机后手动设置/下载核心 |

上述「VPN」是功能分类，**本次未新增统一顶级 VPN 节点**，保留插件原生路径、ACL 和子菜单。用户需求第五节允许做或不做并注明；插件的实际菜单标题仍须刷机核实。服务项使用原生 menu JSON / Lua，不另造节点。Dockerman 只改 `_("Docker")` 为 `_("容器")`；iStore 在 feeds install 后改 `_("iStore")` 为 `_("商店")`，路径 `admin/docker` / `admin/store` 不变。若上游改成 JS 菜单，需人工核对，而非替换 lisaac 源码。

其他 Lua 应用扩展改名方法：

```bash
grep -rn 'entry({"admin",' <app>/luasrc/controller/
# 找到两元素顶级 entry，检查 _(标题)，再用同样 sed 只替换标题字符串。
```

全局开启 `CONFIG_LUCI_LANG_zh_Hans=y`。`gen-i18n.sh` 在第一次设备 defconfig 后扫描当前 feeds/package 中已选中的 `luci-app-*`，读取 PKG_NAME 和真实中文 po 目录。zh-cn 与 zh_Hans 分别写入，不硬编码插件清单；同时读取当前 `luci.mk` 的 `LUCI_LC_ALIAS`（例如 zh_Hans → zh-cn），追加实际包名候选，再执行 defconfig，输出 `i18n-map.txt`。因此 po 目录名不一定等于 APK 的语言后缀。Cloudflared 两种候选明确保留；缺翻译只警告，不影响主包功能。最终中文界面需实机检查，不能以静态目录扫描代替。

## 默认值与网络合并

| 项目 | 默认值 |
|---|---|
| LAN | `192.168.6.1/24` |
| 2.4 GHz SSID | `Wall` |
| 低频 5 GHz SSID | `Wall-5G` |
| 高频 5 GHz SSID | `Wall-6E` |
| 登录用户名 | `root` |
| 密码 / WiFi 加密 | 沿用目标上游默认，本仓库不写密码；首次登录请设置 |

三处 LAN 冗余：构建时查找实际 `config_generate` 并替换旧地址；overlay `files/etc/config/network` 含完整静态 LAN 段；99 首刷默认脚本再次 UCI 写入。单独预置 network 会阻止上游生成网桥/WAN，所以新增 00 脚本：仅在发现本仓库 overlay 标记时，先重新生成上游硬件默认网络，再用 `uci import -m` 合并 LAN 配置，保留其它段。恢复用户旧配置时无标记，不重生成。

SSID 变量位于 `files/etc/uci-defaults/99-athena-defaults` 顶部。脚本遍历 `wireless.default_radio*`，通过 device 引用读取 band，2g 单独处理；两条 5g 按信道排序，auto 信道时按硬件 path 排序，不写死 radio 编号。**两个 radio 都 auto 时，仅靠 band 无法知道哪个是低频/高频，path 回退的对应关系需人工核实**。`Wall-6E` 只是 SSID，AX6600 此机型的第三频段仍是 5 GHz，不是 6 GHz。

脚本不写加密、密码、信道或 disabled；是否默认开启无线由上游决定。没有无线设备/接口时返回失败以便下次开机重试；应用后保存标记，保留配置升级时不重置个人 IP / SSID。写完执行 `wifi reload`。**LAN 首刷兜底写入后需执行一次 `/etc/init.d/network restart` 或重启路由器才能使正在运行的网络服务使用该值**。

## 产物、刷机与升级

源码产物目录固定为 `sources/<flavor>/bin/targets/qualcommax/ipq60xx/`，交付目录为 `artifacts/<flavor>/`。只收集名字含 `jdcloud_re-cs-02` 的镜像，至少要求非空 sysupgrade、manifest、正确单设备目标；检测到其他设备镜像或 LibWrt 丢失 NSS 11.4 就不交付。附 .config、manifest、上游与插件 SHA、语言对照表、警告日志、构建信息及 SHA256SUMS。**缺包警告不会终止编译，须检查 config-audit.txt 与 manifest，确认可以接受后再刷机。**

首次刷机：

1. 确认铭牌为雅典娜 RE-CS-02，备份现有配置、校准数据与 eMMC 重要数据，准备该机型已验证的恢复方式。
2. 下载正确 flavor 的成功 artifact，解压后执行 `sha256sum -c SHA256SUMS`，查看 manifest 和警告。不要使用日志 artifact 当固件。
3. 原厂到 OpenWrt 的引导方式、分区布局与 factory 镜像兼容性必须按此设备的上游说明核实。**本次未实机验证，不给出猜测的 dd / 分区写入命令**；无 factory 镜像时不能把 sysupgrade 当作原厂安装镜像。
4. 首刷后访问 `192.168.6.1`，若仍在旧网段，重启网络/路由器；设置管理密码，核对三个 SSID、网口和无线加密。默认不自动格式化 128G 数据盘；Docker 数据目录应放在已核实的独立 ext4 数据分区。

升级：同 flavor、同机型、已确认兼容布局时，在 LuCI「系统 → 备份/升级」上传 sysupgrade 镜像并核对设备提示。同一配置可按需保留；跨 LibWrt/ImmortalWrt 迁移建议不保留配置并手动恢复必要设置。若保留上游升级配置，SSID/IP 首刷标记会保留，脚本不会覆盖个人改动。不要强制忽略镜像设备检查。

LibWrt NSS 11.4 核对：

```bash
grep '^CONFIG_NSS_FIRMWARE_VERSION_11_4=y$' artifacts/libwrt/firmware.config
grep '^CONFIG_ATH11K_NSS_SUPPORT=y$' artifacts/libwrt/firmware.config
# 上述仅证明配置选择；刷机后再看 dmesg 中 NSS/ath11k 初始化，并实测 WiFi offload。
dmesg | grep -iE 'nss|ath11k'
```

## 已知风险与限制

- ImmortalWrt 线没有本仓库的 NSS 固件/WiFi offload；IPQ6018 平台完整 NSS 加速缺失时走常规/软转发，吞吐可能明显低于 LibWrt，幅度需实测。其稳定分支当前还缺雅典娜，不能出包。
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

1. 将 ImmortalWrt master 的完整雅典娜支持审核回移植到指定稳定分支，或由你明确决定改用其他已支持的分支；本次不猜测移植补丁。
2. 各 upstream-25.12 feed 中 cloudflared、Lua 运行时、内核选项及各插件依赖的最终 Kconfig/manifest；`CONFIG_KERNEL_BRIDGE_NETFILTER` 在此前 LibWrt 静态定义中不存在，实际内核依赖由 kmod-br-netfilter 提供，已保留你要求的候选并警告。
3. 两个 5g auto radio 的硬件 path 与实际高/低频对应关系、原厂首次安装与跨 flavor 升级布局、128G 数据分区；均需设备验证。
4. 动态包源的实际版本、Po/PKG_NAME 非标准变量写法、翻译别名、原生菜单，以及代理核心/UI 下载功能；源目录扫描不能代替运行验证。
5. mihomo / sing-box 等多源同名包的冲突与 Passwall 默认 dnsmasq 替换是否必要，需真实 defconfig 和编译日志判定。

## 静态自检

```bash
bash -n build.sh && bash -n scripts/*.sh
# Bash 对多文件参数只解析第一个，完整检查必须逐文件执行：
for script in build.sh scripts/*.sh files/etc/uci-defaults/*; do bash -n "$script" || exit; done
shellcheck build.sh scripts/*.sh
shellcheck -s sh files/etc/uci-defaults/*
python3 -c 'import ast,json,pathlib; [ast.parse(p.read_text()) for p in pathlib.Path("scripts").glob("*.py")]; [json.loads(p.read_text()) for p in pathlib.Path("files").rglob("*.json")]'
docker compose config --quiet
# 编译入口 patch 后，应针对实际发现的 config_generate 检查旧 LAN 地址。
```

本次真实输出、逐文件改动表与要求交付文件的完整内容见 [改造交付记录](docs/implementation-report.md)。环境已沿用 cloud-environment-onboarding:setup 配置静态工具；没有创建工作树、执行固件编译或推送到 GitHub。
