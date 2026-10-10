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

## 代理启动失败：2026-10-10 设备日志

本次提供的日志明确显示三个不同状态：Momo 在启动核心前因缺少带 dns-in 标签和 listen_port 的 DNS 入站而退出；HomeProxy 在生成客户端配置时失败，没有生成运行配置文件；Nikki RS 的本次 app.log 表示插件已禁用。这些证据不足以认定 sing-box 或 clash-rs 二进制崩溃。

HomeProxy 上游启动脚本未捕获生成器 stderr。本仓库新增 patch-homeproxy-startup.py，把生成器错误写入界面诊断使用的 homeproxy.log，并在 DNS/路由修改之前检查非空配置、执行 sing-box check。保留 hiddify 的原有启动方式，不擅自改写用户节点或订阅。

临时启动测试覆盖生成器失败、核心配置校验失败和成功三种路径：错误信息保留到日志，失败路径不会进入后续 DNS/路由设置；有效配置可以继续启动流程。Shell 语法、ShellCheck 和 actionlint 通过。此修改增强错误呈现和失败处理，实际配置生成失败的根因仍需设备上的生成器/配置校验输出定位。没有据此更换核心版本或宣称实机代理已恢复。

后续设备输出进一步定位：HomeProxy 生成器返回 `no main_node configured`，未读取到已保存的主节点；Momo 的 `sing-box check -c /etc/momo/run/config.json` 返回第 1 行第 1 列非法字符 `a`，说明运行文件无法解码为 JSON。此前缺少 DNS 入站的提示不能作为当前根因，需先纠正订阅内容。无法仅凭首字符判断具体服务器错误正文。

共享插件准备新增 `patch-momo-startup.py`：下载成功后用 sing-box format 解码临时文件，失败时标记更新失败并保留已有缓存；启动时在混入之前解码输入，捕获混入与格式化失败并写入 core.log。保留用户的订阅、节点和核心版本，不自动转换 Clash YAML 或改写 DNS 入站。

两条分支的真实上游启动脚本均成功应用补丁，重复应用不改变文件。隔离测试使用模拟下载和核心，验证 HTTP 成功但返回文本/YAML 时不覆盖缓存、有效 JSON 正常更新、解码/混入/格式化失败提前退出、正常路径继续。Shell 语法、仓库 ShellCheck、Python 语法与 actionlint 通过；这些检查不代表已在路由器上运行代理。

现有设备可先在 HomeProxy 中选择主节点并保存应用；Momo 改用供应方提供的 sing-box 完整 JSON 配置订阅并重新更新，随后检查所选透明代理模式要求的入站。测试时一次只启用一个透明代理插件。Nikki RS 最近日志为 Disabled，若单独启用后仍退出，需要该次 app.log/core.log 才能定位。

### HomeProxy DNS 兼容错误已定位

后续用户确认已选择主节点，系统日志在 22:54–23:01 多次出现 `start dns/udp[default-dns]: detour to an empty direct outbound makes no sense`，随后 procd 报 crash loop。这确认启动配置的 DNS 兼容错误；此前 no main_node 输出只代表此前那次状态。当前诊断快照中运行文件不存在、服务没有实例，也不能单独用于判断主节点是否保存。

生成器把 DNS 的 detour 指向只有 type/tag 的普通 direct 出口，新核心拒绝这个配置。新增 `patch-homeproxy-dns.py`，在清理空属性后，仅针对 sing-box 移除 DNS 指向这类普通 direct 出口的 detour。保留代理 DNS、带 mark/interface 等设置的直连出口、route.default_mark 和 hiddify 核心路径。

下载官方 sing-box 1.14.3 Linux AMD64 构建并核对 GitHub 资产 SHA256，使用本机编译的真实 ucode 执行新增逻辑。最小原配置实际运行复现设备的 DNS fatal；修正后的配置正常启动。回归验证代理/带标记/绑定接口的 detour、default_mark 保留及重复转换不改变结果；双分支补丁幂等、Python/ShellCheck/actionlint 通过。此处是同版本核心的本机配置验证，不是用户设备的完整运行验证。

日志还记录过 `unknown transport type: xhttp`：当前固件的 SagerNet sing-box 不支持该传输，不能通过修正 DNS 得到支持。应使用当前核心支持的节点传输，或另行选择确实支持 XHTTP 的核心；本次未更换共享核心或伪造传输类型。用户要求暂停 GitHub 构建，本次修正提交跳过 CI。

### 核心管理查询和安装错误反馈

用户确认 DNS 热修后 HomeProxy 能运行。核心管理截图显示 hiddify 的 `package installation failed`、sing-box 的 `could not determine latest version from GitHub`，设备终端查询又返回 `no response from GitHub API`；433 MB 临时空间和 1730 MB overlay 空间不符合脚本的容量不足分支。hiddify 安装失败的具体原因仍待 APK 输出，不能据此认定是签名、依赖或文件冲突。

新增 `patch-homeproxy-core-management.py`：版本检查和安装准备共享 GitHub 查询逻辑，优先 curl，缺少 curl 时用 wget，保持 TLS 校验，捕获 HTTP/连接错误并呈现 API 错误消息。安装器输出写入 `/tmp/homeproxy-core-install.log`，错误末尾反馈到页面；失败时保留临时包，成功后清理。安装器已有的包校验参数没有放宽，也没有执行真实核心替换。

页面按检测到的核心变体区分普通 sing-box 和 extended；普通核心的按钮明确标为“安装扩展版”，并说明会切换变体。修复 RPC 准备返回空对象时继续下载的逻辑。补充对应中文翻译。

真实 ucode 执行上游脚本已成功查询在线 GitHub release；受控命令模拟覆盖 HTTP 403、API 限流消息、非法 JSON、有效版本和 APK 安装失败/成功，验证失败信息返回、失败包保留及成功清理。真实界面核心卡片测试覆盖普通/扩展/hiddify 标识、空准备响应不触发下载且恢复按钮。双分支补丁幂等、JS/Python 语法、ShellCheck/actionlint 通过。这些是查询和错误处理验证，不代表设备网络或 hiddify 安装已修好。

设备后续重新执行 DNS 热修时报告 no main_node。生成器只有在当前 UCI 读取结果为空或 nil 时出现此消息；已有订阅更新和删除节点流程可能改变这个值，应检查当前保存值，不能只根据旧页面截图推断，也没有据此自动选取用户节点。

### GitHub 限流与 hiddify 缺少内核模块已确认

进一步输出确认 GitHub API 的响应为 HTTP 403 rate limit exceeded，而 GitHub 发布资产下载正常；不是容量不足，也不能归为所有 GitHub 连接都失败。hiddify-core 4.1.0 包下载成功，APK 模拟安装明确缺少 kmod-nft-queue。此次 main_node 查询已经有非空节点标识，不能继续认定主节点未保存。

新增 `homeproxy-release.uc` 作为准备脚本注入的共享函数。API 查询失败后读取 GitHub releases/latest 页面取得实际标签；安装准备还读取 expanded_assets 页面取得真实 APK/IPK 下载链接，再按原有架构和包格式筛选，不猜测文件名，不要求用户提供 GitHub 令牌，不关闭 TLS 校验。版本检查只读取标签，减少额外请求；回退也失败时保留两条路径的错误信息。

在两种固件的共享配置中选入 kmod-nft-queue，并加入配置与成品 manifest 的强制检查。两条真实源码分别执行 make defconfig 和配置审计，kmod-nft-queue、kmod-nfnetlink-queue、kmod-nft-core 都为 y。尚未编译新模块或在设备上安装；现有 snapshot 固件必须从匹配其 kernel 依赖的仓库取得模块，不能强制忽略依赖。

真实 ucode 测试在模拟 API 403 的情况下访问真实 GitHub 发布页面，正确取得当前标签和 aarch64_cortex-a53 APK 链接；额外覆盖正常回退、资产缺失、API 与页面都失败。此前 API 查询、安装器错误捕获和界面状态测试仍通过，ShellCheck/actionlint/Python 语法通过。按用户要求，代码同步继续跳过 CI，未发起新固件构建。

### 失效的自定义 feed 地址

用户设备 apk update 成功读取主 target/base/luci/packages/routing/telephony 和 iStore compat 索引，但 istore/openclash/passwall/passwall2/pw_packages 被生成到上游镜像默认路径，下载失败；更新索引后 kmod-nft-queue 仍无候选包。清理无效地址只能修复软件源报错，不能产生缺失的内核包。

上游 tmp/.config-feeds.in 明确说明 CONFIG_FEED_* 仅控制生成的二进制仓库地址；本地插件是否编译由 CONFIG_PACKAGE_* 决定。共享配置禁用这五个默认仓库地址，保留全部已授权插件及 iStore 独立的 compat 地址，配置审计拒绝重新启用不存在的默认二进制源。

两条分支执行 make defconfig 和配置审计通过，插件和已补入的 kmod-nft-queue 仍为内置包。直接调用真实上游 include/feeds.mk 的 FeedSourcesAppendAPK，验证五个错误地址不再生成、标准 feeds 均保留。源配置修改尚未应用到用户现有固件；该固件安装 hiddify 仍需要与其 kernel 依赖匹配的模块，后续构建已配置内置该模块。继续跳过 CI。
