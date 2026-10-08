# ImmortalWrt 雅典娜设备支持修复

原阻塞来自源码选择：官方 `immortalwrt/immortalwrt` 的 `openwrt-25.12` 未包含雅典娜，而参考仓库使用 `laipeng668/immortalwrt` 的同名分支。

本次参考 [openwrt-ci-roc 提交 2d2c471](https://github.com/laipeng668/openwrt-ci-roc/tree/2d2c4710ebf9b97c1d30eb63989e3eb69b3583b0)，切换为相同 fork/分支，并沿用 `CONFIG_TESTING_KERNEL=y`、512M ath11k 内存配置、NSS 12.5。没有复制参考库的多设备选择，仍只选择雅典娜。不是移植设备定义，也不是使用不存在的 Kconfig 符号伪造支持。

| 文件 | 修复 |
|---|---|
| configs/targets.conf | ImmortalWrt 改用参考 CI 的雅典娜 fork |
| configs/immortalwrt.config | 选择参考测试内核/NSS；明确关闭此线 WiFi NSS 和 mesh |
| scripts/common.sh | 允许专用目录从旧官方 origin 迁移到 fork；重建 feeds.conf，确保 NSS feed 不被旧清单遮蔽 |
| build.sh | feeds 处理前读取源码检查雅典娜集成，将 source-support.txt 随产物交付 |
| scripts/firmware-config.py | 新增源码预检；审计和产物检查核对 ImmortalWrt 测试内核/NSS 12.5/512M 和 WiFi NSS 关闭状态 |
| .github/workflows/build.yml | 失败日志也包含源码支持预检结果 |
| upstream-lock.txt | 更新为新 fork 和其两个 NSS 相关 feed 的真实只读远端 HEAD 快照 |
| README / implementation-report / static-checks | 纠正旧的“官方无 NSS、需设备回移植”描述，并保存真实检查输出 |

在 [fork 提交 0a98e09](https://github.com/laipeng668/immortalwrt/tree/0a98e096208584bf90982f59f6d5a43f89443276) 核对到：

- `target/linux/qualcommax/image/ipq60xx.mk`：Device/jdcloud_re-cs-02、EmmcImage、6144k 内核分区、ipq6010、校准固件依赖和 factory 规则。
- `target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq6010-re-cs-02.dts` 与共享 `ipq6010-re-cs.dtsi`：已有设备树，包含 NSS 平台依赖。
- `target/linux/qualcommax/ipq60xx/base-files/etc/board.d/02_network`：lan1～lan4 / wan。
- `.../etc/hotplug.d/firmware/11-ath11k-caldata`：从 eMMC 0:ART 读取无线校准。
- `.../lib/upgrade/platform.sh`：CI_KERNPART=0:HLOS、CI_ROOTPART=rootfs、emmc_do_upgrade / emmc_copy_config。
- `target/linux/qualcommax/Makefile`：默认内核 6.12，测试内核 6.18；include/kernel-version.mk 根据 CONFIG_TESTING_KERNEL 选择测试版本。
- `feeds.conf.default`：laipeng668/nss-packages 与 sqm_scripts_nss。前者提交 `0b692dc3540321427affe325cd17f14fae8c2133` 的 nss-firmware Makefile 确实定义 NSS_FIRMWARE_VERSION_12_5 和 IPQ60xx 固件包。

**配置差异：** 当前 ImmortalWrt 是带 NSS 的社区 fork；此线选择 12.5 并主动关闭 WiFi NSS，而 LibWrt 仍使用 11.4/WiFi NSS。不能继续称 ImmortalWrt 完全没有 NSS。已有生成源码目录若 origin 是此前配置的官方 URL，脚本会定向迁移；其他意外 origin 仍报错。生成目录中的个人 feeds.conf 修改不会保存，请在受版本控制的配置/脚本中定制。

**验证范围：** 以下全部是静态检查或只读源码检查。没有执行 make、固件编译、feeds update、Docker 镜像构建或刷机。设备定义阻塞已解决，但最终 Kconfig、APK 依赖、镜像构建和实机启动仍需后续验证。upstream-lock 初始条目是远端 HEAD 观察，不是已完成双线构建的证明。

## 真实静态输出

```text


ImmortalWrt follow-up fix: actual static outputs, 2026-10-08.
Source checks read files only; no make/build/feeds update/flash executed.

Reference CI source selection
$ git -C /workspace/.wall-wrt-env/diagnosis/roc-ci-reference rev-parse HEAD; grep -n 'repo_url:\|repo_branch:\|kernel_file:' /workspace/.wall-wrt-env/diagnosis/roc-ci-reference/.github/workflows/JDCloud-ImmortalWrt.yml; grep -n 'CONFIG_TESTING_KERNEL\|CONFIG_ATH11K_MEM_PROFILE_512M\|CONFIG_NSS_FIRMWARE_VERSION_12_5' /workspace/.wall-wrt-env/diagnosis/roc-ci-reference/configs/JDCloud.config
2d2c4710ebf9b97c1d30eb63989e3eb69b3583b0
20:      repo_url: https://github.com/laipeng668/immortalwrt.git
21:      repo_branch: openwrt-25.12
24:      kernel_file: kernel-6.18
8:CONFIG_TESTING_KERNEL=y
9:CONFIG_ATH11K_MEM_PROFILE_512M=y
10:CONFIG_NSS_FIRMWARE_VERSION_12_5=y
[exit 0]

Selected fork: read-only source integration check
$ python3 scripts/firmware-config.py check-source /workspace/.wall-wrt-env/diagnosis/immortal-jdcloud-reference immortalwrt
immortalwrt: Athena image/device-tree/network/calibration/eMMC integration found
Source commit: 0a98e096208584bf90982f59f6d5a43f89443276
ImmortalWrt testing kernel: 6.18; NSS feed present
[exit 0]

LibWrt: read-only source integration check
$ python3 scripts/firmware-config.py check-source /workspace/.wall-wrt-env/diagnosis/openwrt libwrt
libwrt: Athena image/device-tree/network/calibration/eMMC integration found
Source commit: 3a3d0b08595530070ad9cd8a20c0ae4ea3e77f70
[exit 0]

Every shell file
$ for script in build.sh scripts/*.sh files/etc/uci-defaults/*; do bash -n "$script" || exit; done
[exit 0]

ShellCheck
$ shellcheck build.sh scripts/*.sh
[exit 0]

Router POSIX shell check
$ shellcheck -s sh files/etc/uci-defaults/*
[exit 0]

Python source syntax
$ python3 -c 'import ast,pathlib; paths=list(pathlib.Path("scripts").glob("*.py")); [ast.parse(p.read_text(), filename=str(p)) for p in paths]; print("Python AST files checked:", len(paths))'
Python AST files checked: 1
[exit 0]

JSON syntax
$ python3 -c 'import json,pathlib; paths=list(pathlib.Path("files").rglob("*.json")); [json.loads(p.read_text()) for p in paths]; print("JSON files checked:", len(paths))'
JSON files checked: 0
[exit 0]

Actions workflow
$ /workspace/.wall-wrt-env/bin/actionlint .github/workflows/build.yml
[exit 0]

Docker Compose syntax only
$ docker compose config --quiet
[exit 0]

Whitespace
$ git diff --check
[exit 0]
```
