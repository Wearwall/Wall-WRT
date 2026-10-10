# 首轮实机反馈修复

反馈：屏幕控制缺失、Argon 主题及设置缺失、高频 radio 重启停滞、客户端 DHCP 无租约。

## 已落实的代码

- 真正使用的 configs/packages.txt 增加 Argon、Argon 设置、雅典娜屏幕程序/设置及完整 iw。旧 configs/Packages.config 中的主题选项不参与当前固件合并。
- Argon 通过独立首次升级脚本设置为默认，配置菜单由 luci-app-argon-config 提供；一次应用后保留后续手动主题选择。
- 屏幕 UI 使用 NONGFAH/luci-app-athena-led，守护程序从 NONGFAH/athena-led 源码交叉编译，不安装仓库中附带的二进制。修正 UI 状态检测，启用进程日志；原始配置 enable=1。
- 屏幕 GPIO 根据实际 IPQ6018 TLMM 控制器 base 加 69/70/73/74 获取，不再根据发行版名字硬编码 581 等编号。找不到唯一控制器就报错，不写入未知 GPIO。两条上游内核均开启 GPIO sysfs；ImmortalWrt 6.18 还开启 legacy sysfs。
- 网络首次生成后仅设置 LAN 地址，不再导入不完整的 LAN interface 段，并检查 br-lan 绑定。
- 全新设置明确启用 LAN DHCP，地址池 192.168.6.100–249，租期 12h，dnsmasq authoritative=1。不设置 force=1，以保留检测同网段其他 DHCP 服务的机制。
- 全新设置明确启用 wifi-device/wifi-iface，去掉 uci-defaults 阶段额外的 wifi reload，由正常 network 启动流程启动无线，减少启动竞争。
- 固件收集要求 manifest 包含 dnsmasq-full、Argon/设置、屏幕程序/设置；缺少这些包会失败，不发布缺包镜像。
- 修复本次更新的 Clashoo UI 和其中文包之间的 Kconfig 循环依赖；中文仍由语言扫描选择。

## 验证与边界

已用真实双分支源码执行插件准备与 make defconfig，六个运行包均选择 =y；iw-full 与精简 iw 不同时选择，没有 Kconfig 循环。屏幕程序已交叉编译为 ARM64 ELF，并通过不同 GPIO base 与缺少控制器的测试。此外已用真实 OpenWrt SDK 构建并生成 `athena-led-1.0-r1.apk` 与新的 `luci-app-athena-led-0.0.7-r2.apk`，两个构建命令退出码均为 0。ShellCheck、Python 语法和 actionlint 通过。

用户暂时不能提供无线/网络日志。截图只能确认无线启动未完成及客户端没收到 DHCP 租约，不能证明具体驱动、校准数据、信道或 dnsmasq 错误。上述配置/启动修改不能当作实机根因已解决的证据，也没有据此改动 NSS 驱动、屏蔽固件崩溃或强制使用信道。

保留配置升级会保留旧无线/DHCP设置；新的全新默认设置不会自动重置它们。验证全新默认设置时先备份旧配置，并通过有线连接操作。Argon 的首次迁移独立于旧默认设置标记。

新固件提供只读诊断命令 `athena-wifi-diagnose`，包含无线运行状态、PHY/监管域、LAN 网桥、dnsmasq 状态、租约及日志；不输出无线 UCI 密钥。日志本身可能包含服务运行信息。拿到设备输出后再区分无线链路、DHCP 服务或代理/防火墙干扰。

当前机器暂时没有 DHCP 时，可以先通过有线连接，给电脑设置同网段静态地址（例如 192.168.6.2/24、网关 192.168.6.1）访问路由器；这只恢复管理通道，不修复 DHCP。

补充反馈：手动设置同网段静态 IP 也难以访问 192.168.6.1，因此诊断还需区分无线二层链路与有线 LAN 网桥/系统运行状态；不能将问题归为单独 DHCP 故障。

用户随后确认：网线连接 LAN 口也不稳定，因此问题不限于无线。当前无法读取设备日志或访问路由器，不能确认网桥、驱动、系统负载或其他服务中哪一项是根因。修复提交 `ed99437` 已同步 master；新构建 [37949247297](https://github.com/Wearwall/Wall-WRT/actions/runs/37949247297) 已启动，记录时还未完成，不能视作实机问题已解决。

## 参考基线重构取代部分首启改动

2026-10-10：用户要求直接基于 openwrt-ci-roc 的两个源码分支改造。本文此前的 network overlay、网络重建及 DHCP/disabled 首启写入不再用于新构建；详见 [参考基线说明](roc-baseline.md)。屏幕源码编译、Argon 与诊断命令继续保留。

## Tailscale 社区界面 ReferenceError

2026-10-10 实机反馈：打开 Tailscale 页面报 `lastDevicesStatus is not defined`。核查社区界面提交 `aefd8a337cbc3a1496270bf6c4a79e65ce92ff35`：严格模式下设备列表初始渲染和轮询赋值使用了未声明的 lastDevicesStatus，表头 peerTableHeaders 也未定义。

共享插件准备脚本调用 `patch-tailscale-ui.py` 补齐模块级状态与八列标题；已存在定义时不会重复插入。保留 Tokisaki-Galaxy 社区界面、中文包及指南的 daemon 来源，不改变路由配置、登录方式或主题。

`check-tailscale-ui.js` 加载真实上游界面，使用 LuCI 表单、DOM 和 RPC 模拟器执行初始渲染、设备轮询、筛选和刷新。原始源码重现 lastDevicesStatus 异常；只修第一个变量时重现 peerTableHeaders 异常；完整修正后两条分支的真实文件均通过测试，重复应用补丁无重复定义。每次克隆后执行相同检查，界面回归会在耗时编译前失败。CI 与 Docker 增加 Node.js 工具依赖。

这是界面逻辑验证，未连接用户的路由器或实际 Tailnet。新固件刷入后需强制刷新浏览器，避免使用缓存的旧 tailscale.js。
