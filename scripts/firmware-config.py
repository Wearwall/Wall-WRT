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
            'kmod-br-netfilter', 'kmod-veth', 'kmod-nft-queue', 'luci-app-store', 'tailscale', 'luci-app-tailscale-community', 'cloudflared', 'luci-app-cloudflared',
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
    for feed in ("istore", "openclash", "passwall", "passwall2", "pw_packages"):
        if values.get(f"CONFIG_FEED_{feed}") == "y":
            raise ValueError(f"Build-only feed has no upstream binary repository: {feed}")
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
