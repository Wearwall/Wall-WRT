# Wall-WRT — 雅典娜 AX6600 云编译

目标设备固定为京东云雅典娜 RE-CS-02（jdcloud_re-cs-02），目标平台 qualcommax/ipq60xx。本仓库只出这一款机型的固件，插件来源抽为共用脚本，保留原 Bash 脚本、Kconfig 配置与 Actions 工作方式。

## 双分支

| FLAVOR | 仓库 | 跟踪分支 | 包格式 | 内核 / NSS | WiFi offload |
|---|---|---|---|---|---|
| libwrt | LiBwrt/LibWrt | 25.12-nss | apk | NSS 11.4 | 开启（ATH11K_NSS_SUPPORT） |
| immortalwrt | laipeng668/immortalwrt | openwrt-25.12 | apk | 测试内核 6.18 + NSS 12.5 | 关闭（IPQ60xx 的 NSS 12.5 不提供 WiFi offload，走正常 ath11k） |

两者均已包含 RE-CS-02 的镜像、设备树、网口、无线校准数据与 eMMC 升级集成。构建在 feeds 下载前静态检查雅典娜源码集成，上游若删除支持会提前报错；缺少生成的 Kconfig profile 时拒绝编译其他机型。

## 默认值

| 项目 | 默认值 |
|---|---|
| LAN | 192.168.6.1/24 |
| 2.4 GHz SSID | Wall |
| 5 GHz SSID（低频 / 高频） | Wall-5G / Wall-6E |
| 登录用户名 | root |
| 密码 / WiFi 加密 | 沿用上游默认，本仓库不写密码，首次登录请设置 |

LAN 三处冗余：构建时替换 config_generate 中的旧地址、overlay 提供完整静态 LAN 段、99 首刷脚本再次 UCI 写入。单独预置 network 会挡住上游生成网桥/WAN，故新增 00 脚本——仅当发现本仓库 overlay 标记时，先重新生成上游硬件默认网络，再用 `uci import -m` 合并 LAN 配置，保留其余段；用户恢复旧配置后无标记，不会被重置。

SSID 变量位于 `files/etc/uci-defaults/99-athena-defaults` 顶部，按 band 识别 2g、两条 5g 按信道排序（auto 时按硬件 path 排序），不写死 radio 编号。脚本不写加密、密码、信道或 disabled，无无线设备时返回失败以便下次开机重试，应用后保存标记，保留配置的升级不会重置个人设置。

## 插件矩阵

| 分类 | 插件 | 来源 | 菜单位置 |
|---|---|---|---|
| 容器 | Docker（dockerd / docker / docker-compose） | 官方 packages feed | 命令行 / 容器 |
| 容器 | Dockerman | lisaac/luci-app-dockerman + luci-lib-docker | 顶级「容器」 |
| 商城 | iStore | linkease/istore（main） | 顶级「商店」 |
| VPN | RE:HomeProxy | 1andrevich/homeproxy-hiddify | 原生（服务） |
| VPN | momo | nikkinikki-org/OpenWrt-momo | 原生 |
| VPN | Clashoo | kenzok8/openwrt-clashoo | 原生 |
| VPN | Nikki RS | CHKayanami/OpenWrt-nikki-rs | 原生 |
| VPN | FullCombo Shark | fcshark-org/openwrt-fchomo | 原生 |
| VPN | OpenClash | vernesong/OpenClash | 原生 |
| VPN | Passwall | OpenWrt-Passwall/openwrt-passwall | 原生 |
| VPN | Passwall2 | OpenWrt-Passwall/openwrt-passwall2 | 原生 |
| VPN | 共同依赖 | OpenWrt-Passwall/openwrt-passwall-packages | 无独立菜单 |
| 服务 | Tailscale | whzhni1/luci-app-tailscale（feed 原位替换，ts_omit_ssh） | 原生 |
| 服务 | Tailscale 社区前端 | Tokisaki-Galaxy/luci-app-tailscale-community | 服务 |
| 服务 | Cloudflare | 官方 packages / luci feed | 服务 |
| 服务 | AdGuardHome | rufengsuixing/luci-app-adguardhome（仅 Lua 管理页） | 服务 |

- 「VPN」仅为功能分类，未新增统一顶级节点，保留各插件原生路径与子菜单；代理核心（hiddify-core / sing-box / clash-rs / mihomo）均为刷机后或构建期从 Release 下载，不覆盖系统 sing-box。
- 八个透明代理插件可同时勾选，但依赖兼容性未经编译验证；运行时只启用一个，防火墙规则可能互相覆盖。
- 全局开启 `CONFIG_LUCI_LANG_zh_Hans=y`，由 gen-i18n.sh 在首次 defconfig 后扫描已选中的 `luci-app-*` 实际 po 目录与 luci.mk 的 LUCI_LC_ALIAS 生成映射，不硬编码清单；缺翻译仅告警。中文界面仍须实机核对。
- iStore UI 需联网访问 istore.linkease.com；官方说明仅覆盖 x86_64/arm64，本机型运行与应用兼容未验证。

## 产物

源码产物在 `sources/<flavor>/bin/targets/qualcommax/ipq60xx/`，交付目录 `artifacts/<flavor>/`。只收集名字含 `jdcloud_re-cs-02` 的镜像，且必须满足：非空 sysupgrade、manifest 齐备、目标为单设备；检测到其他设备镜像，或 LibWrt 丢失 NSS 11.4、ImmortalWrt 丢失测试内核 / NSS 12.5 / 512M 设定 / 错误打开 WiFi NSS，均不交付。

附件包含 `.config`、manifest、上游与插件 SHA、语言对照表、config-audit 警告日志、构建信息与 `SHA256SUMS`。缺包警告不终止编译，刷机前务必先看审计与 manifest 再判断。

Actions 产物命名 `Athena-<flavor>-<日期>-<run_id>`，保留 14 天；全部所选分支成功后自动发布 Release（标签 `athena-YYYYMMDD-<run_id>`，日期沿用原始构建日期）。失败也保留日志，并可凭 run ID 补发，无需重新编译。

## 刷机与升级

**首次刷机**

1. 确认铭牌为 RE-CS-02，备份现有配置、校准数据与 eMMC 重要数据，确认该机型已验证的恢复方式。
2. 从 Releases 下载对应 flavor 固件与 `SHA256SUMS` 并校验；同分支 info.zip 查看 manifest 与配置审计。Actions artifact 解压后执行 `sha256sum -c SHA256SUMS`，不要用日志 artifact 当固件。
3. 原厂 → OpenWrt 的引导方式、分区布局与 factory 镜像兼容性必须按该设备上游说明核实；无 factory 镜像时不能把 sysupgrade 当原厂安装镜像。
4. 访问 192.168.6.1；若仍在旧网段，重启网络/路由器。设置管理密码，核对三个 SSID、网口与无线加密。
5. 默认不自动格式化 128G 数据盘，Docker 数据目录放在已核实的独立 ext4 分区。

**升级**

同 flavor、同机型、已确认布局兼容时，在 LuCI「系统 → 备份/升级」上传 sysupgrade 并核对设备提示，不要强制忽略镜像设备检查。同 flavor 可按需保留配置；跨 LibWrt/ImmortalWrt 建议不保留配置并手动恢复。保留配置时首刷标记仍在，个人 IP / SSID 不会被覆盖。

**刷机后核对 NSS**

```bash
grep '^CONFIG_NSS_FIRMWARE_VERSION_11_4=y$' artifacts/libwrt/firmware.config
dmesg | grep -iE 'nss|ath11k'
```

配置只证明选项被选中，实际 offload 生效仍需实测。

**待实机验证**：ImmortalWrt fork 的内核 6.18 / NSS 12.5 与正常 ath11k 无线、以太网 NSS 驱动的整合；两个 5g auto radio 的硬件 path 与高低频对应关系（`Wall-6E` 只是 SSID，AX6600 第三频段仍是 5 GHz）；原厂首次安装布局与 128G 数据分区；kmod 必须与本机内核 ABI 一致，不可在线安装其他构建的 kmod。

源码位于 `sources/<flavor>/`，每次执行会 fetch + `reset --hard` 到跟踪分支最新提交——这是专用生成目录，不要把 SOURCE_ROOT 指向有个人修改的源码目录，也不要在其中保存个人 feed 修改。详细构建命令、缓存策略、静态自检脚本见仓库 README。

## 感谢上游各位大神
https://github.com/LiBwrt/LibWrt       ##上游WRT分支
https://github.com/fishand73/JDBoxFlashTool   ##刷机uBoot工具   
https://github.com/laipeng668/openwrt-ci-roc   ##基于构建服务修改
