# 实际构建记录（2026-10-08）

用户授权真实编译后，通过普通 push 触发 GitHub 双线矩阵；没有依赖页面的 Run workflow 按钮。

- [第一次实际构建](https://github.com/Wearwall/Wall-WRT/actions/runs/37794756878)：两条线在 Build Athena only 阶段失败，尚未产出固件。
- 找到脚本中的确定性错误：lang/golang 是工具链集合目录，根目录没有 Makefile。真正的包位于 lang/golang/golang/Makefile，共用 include 为 golang-package.mk。错误校验会在任何包编译前退出。
- 提交 beb52e9 修正 Go 目录校验；[第二次构建](https://github.com/Wearwall/Wall-WRT/actions/runs/37795451532) 已启动，记录时尚在运行，不能视为成功。
- 提交 a967a14 将未来失败日志尾部写入 GitHub job summary，未另外触发构建。

本地使用真实源码/feeds 完整执行两条线的插件准备、feeds install、设备配置重置、make defconfig、语言扫描与最终配置审计；两个准备命令退出码都为 0。以下仅证明配置阶段，不代表镜像或运行功能。

| 分支 | 实际源码 HEAD | 设备 | 请求包的未保留符号 |
|---|---|---|---|
| libwrt | `3a3d0b08595530070ad9cd8a20c0ae4ea3e77f70` | 雅典娜单设备 | 1：`CONFIG_PACKAGE_luci-i18n-cloudflared-zh_Hans` |
| immortalwrt | `0a98e096208584bf90982f59f6d5a43f89443276` | 雅典娜单设备 | 1：`CONFIG_PACKAGE_luci-i18n-cloudflared-zh_Hans` |

两条线中 Dockerman、iStore、Tailscale 与 Re:HomeProxy 都为 =y；NSS/测试内核/512M/关闭 WiFi NSS 的分支要求也核对通过。未保留的 Cloudflared zh_Hans 候选是预期结果，实际 zh-cn 翻译已选择。CONFIG_KERNEL_BRIDGE_NETFILTER 候选未定义，kmod-br-netfilter 为 =y。仍需最终内核配置/manifest 验证。

API 状态：GH_TOKEN 已安全注入，但 api.github.com 被当前环境网络策略拦截。只确认变量存在，未打印值。已将该域名追加到环境配置草稿，保存不代表当前网络生效；需要在环境设置保存/发布。公开 GitHub run/job 页面可读取任务状态，完整日志端点当前不可读取。

没有成功固件的结论；最终状态及 artifact 以第二次构建页面为准。
