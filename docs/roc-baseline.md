# AX6600 两分支参考基线

参考仓库： https://github.com/laipeng668/openwrt-ci-roc ，配置快照提交 `2d2c4710ebf9b97c1d30eb63989e3eb69b3583b0`。

| 构建名称 | 实际源码 | 分支 | 内核 / NSS |
| --- | --- | --- | --- |
| libwrt | laipeng668/openwrt-6.x | 25.12-nss | 6.12 / 11.4 |
| immortalwrt | laipeng668/immortalwrt | openwrt-25.12 | testing 6.18 / 12.5 |

每天及手动构建仍获取源码与 feeds 的最新提交；上述快照用于解释基础配置来源，并非固定全部依赖版本。每次构建的实际版本写入发布的 info.zip。

配置合并顺序：参考 `General.config` 快照 → AX6600 单设备配置 → 分支内核/NSS 配置 → 指南插件配置。最后根据真实上游 Kconfig 解析雅典娜设备名称，关闭多设备及每设备 rootfs。仅生成 `jdcloud_re-cs-02` 镜像。参考默认 Aurora 改为用户指定的 Argon，并包含 Argon 设置。

参考的 Go、DDNS、frp、UPnP、WOL 和 Argon 软件源也同步采用。屏幕 UI 使用 NONGFAH 项目；屏幕程序从 Go 源码编译，按实际 GPIO 控制器基址计算引脚，避免使用上游打包的固定基址二进制。

## 保留的指南功能

- Tailscale 与 community UI、Cloudflared、Re:HomeProxy、Momo、NikkiRS、FCHomo/Mihomo。
- OpenClash、Passwall、Passwall2。
- rufengsuixing 的 AdGuardHome Lua UI；核心仍按该 UI 原有流程安装。
- Docker、docker-compose、lisaac 的经典 Lua Dockerman 与独立 luci-lib-docker。
- 官方 linkease iStore 商城、终端以及原有常用管理功能。
- Open-Box 沿用指南的运行时安装方式，不将安装脚本塞入开机或编译流程。

关键插件在配置解析后必须为 built-in；镜像生成后还检查实际 manifest 中确实包含这些软件。缺少关键插件或非空 factory/sysupgrade 镜像则构建失败，不发布不完整固件。

## 网络初始化改动

删除局部 `/etc/config/network` overlay 和 `00-athena-network-merge`，生成目录中残留的同名文件也清除。取消首启脚本改写 DHCP、强制无线启用及额外重载。网桥、WAN、DHCP、无线启用、信道、带宽、国家码沿用参考分支的设备初始化逻辑。只在上游 `package/base-files/files/bin/config_generate` 修改默认主机名为 `Wall-WRT`，默认 LAN 地址为 `192.168.6.1`；首启脚本仅配置 Wall / Wall-5G / Wall-6E SSID，并在保留配置升级时尊重用户设置。Wall-6E 只是原有 SSID 名称，不代表该无线电支持 6 GHz。

这是针对已确认的源码差异和额外初始化覆盖作出的修正。缺少设备运行日志与实机，不能据此断言 DHCP、网口或高频无线故障已彻底解决。新固件继续包含只读 `athena-wifi-diagnose` 命令，方便后续实机定位。

## 发布规则

保留自动发布到 Releases、标题 `京东雅典娜AX6600 YYYY-MM-DD`，镜像命名 `JDCloud-Athena-分支名-YYYYMMDD-构建编号-固件类型`，以及 info.zip、SHA256SUMS。

## 验证

2026-10-10 在真实源码及完整 feeds 中完成 defconfig、设备符号解析、中文包生成和最终审计：

- LibWrt 源码提交 `3a3d0b08595530070ad9cd8a20c0ae4ea3e77f70`。
- ImmortalWrt 源码提交 `0a98e096208584bf90982f59f6d5a43f89443276`。
- 两条配置均只选择雅典娜，全部强制保留插件及参考常用功能为 built-in，Aurora 未启用，iw-full 与 iw 无冲突。
- 上游设备 02_network 和 mac80211.uc 与对应源码提交完全一致。
- SSID 模拟验证覆盖无线枚举不同于频段顺序，以及保留配置时重复执行：只修改三个 SSID，不写 DHCP、network、disabled 或信道。
- Bash/Sh 语法、ShellCheck、Python 语法、actionlint、git diff --check 通过。

feeds 的 jool/openvswitch 元数据有上游 `kmod-nf-conntrack6` 缺失警告；两者未选入镜像，因此不影响本次配置。Cloudflared 中文名称实际为 zh-cn，审计接受 zh_Hans 的有效别名；bridge netfilter 由 kmod-br-netfilter 的 KCONFIG 提供，不依赖不存在的顶层候选符号。

以上为源码/配置与脚本验证，不等同于完整固件编译或实机验证。实际编译由 GitHub Actions 执行，成功后按原规则自动发布。

本次改造提交：`c1d42df`；双分支构建：[GitHub Actions 38008436292](https://github.com/Wearwall/Wall-WRT/actions/runs/38008436292)。该链接用于核对本次实际编译与自动发布结果。

## 2026-10-10 构建末尾失败与修正

构建 `38008436292` 的两条分支均完成 make 并生成 factory/sysupgrade 镜像，随后产物检查报 `Required runtime packages missing: ['mihomo']`。Clashoo 的 Makefile 声明 `PROVIDES:=mihomo clash-meta`；APK 安装阶段可以用它满足 FCHomo 的 mihomo 依赖，因此配置里 mihomo=y 并不保证独立核心进入镜像。检查阻止了自动发布这次产物。

按用户新要求，彻底排除 Clashoo 核心与界面：配置禁用、删除克隆步骤、清理生成源码及 feed 残留，配置和产物检查拒绝 Clashoo。保留原始 FCHomo/mihomo 的源码和严格 manifest 检查。两条真实源码重新 defconfig 和审计通过，唯一 mihomo 提供者为独立核心。

Tailscale 界面核验：`Tokisaki-Galaxy/luci-app-tailscale-community` / master，核验提交 `aefd8a337cbc3a1496270bf6c4a79e65ce92ff35`；`luci-app-tailscale-community` 及 zh-cn 中文包均 built-in。daemon 来自指南的 `whzhni1/luci-app-tailscale` / main 中 tailscale 子目录，核验提交 `c45e596f028d0e95bdda4803f79f5e3c633814dd`。未选用普通 luci-app-tailscale。

默认值确认：主机名 `Wall-WRT`、LAN `192.168.6.1`、2.4G / 低频5G / 高频5G SSID 依次为 `Wall` / `Wall-5G` / `Wall-6E`。不增加首启网络重建或无线重载。
