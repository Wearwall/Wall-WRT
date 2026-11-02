#!/usr/bin/env python3
"""Move selected LuCI pages under a shared VPN menu before package compilation."""
import json
from pathlib import Path
import re

ROOT = Path.cwd()
APPS = {
    "luci-proto-wireguard": ("admin/status/wireguard", "admin/vpn/wireguard"),
    "luci-app-re-homeproxy": ("admin/services/homeproxy", "admin/vpn/homeproxy"),
    "luci-app-fchomo": ("admin/services/fchomo", "admin/vpn/fchomo"),
    "luci-app-openclash": ("admin/services/openclash", "admin/vpn/openclash"),
    "luci-app-nikki-rs": ("admin/services/nikki-rs", "admin/vpn/nikki-rs"),
    "luci-app-honk": ("admin/services/honk", "admin/vpn/honk"),
    "luci-app-daede": ("admin/services/daede", "admin/vpn/daede"),
}


def sources(name):
    for base in (ROOT / "package", ROOT / "feeds", ROOT / "honk-feed"):
        if base.exists():
            for path in base.rglob(name):
                if path.is_dir() and (path / "Makefile").is_file() and "package/feeds" not in str(path):
                    yield path


def move_json(path, old, new):
    data = json.loads(path.read_text())
    changed = False
    result = {}
    for key, value in data.items():
        target = key.replace(old, new, 1) if key == old or key.startswith(old + "/") else key
        if target != key:
            changed = True
        if target in result:
            raise ValueError(f"Duplicate LuCI menu route {target}: {path}")
        result[target] = value
    if changed:
        # LuCI actions may use route aliases; keep their route targets consistent.
        raw = json.dumps(result, ensure_ascii=False, indent=2)
        raw = raw.replace(old, new)
        path.write_text(raw + "\n")
    return changed


def move_lua(path, old, new):
    parts = old.split("/")
    replacement = new.split("/")
    text = path.read_text()
    pattern = re.compile(r'(["\'])admin\1\s*,\s*(["\'])' + re.escape(parts[1]) +
                         r'\2\s*,\s*(["\'])' + re.escape(parts[2]) + r'\3')
    def replace(match):
        return (f'{match[1]}admin{match[1]}, {match[2]}{replacement[1]}{match[2]}, '
                f'{match[3]}{replacement[2]}{match[3]}')
    updated, count = pattern.subn(replace, text)
    if count:
        path.write_text(updated)
    return bool(count)


for app, (old, new) in APPS.items():
    changed = []
    candidates = list(sources(app))
    if not candidates:
        raise SystemExit(f"Missing selected LuCI package source: {app}")
    for source in candidates:
        for path in source.glob("root/usr/share/luci/menu.d/*.json"):
            if move_json(path, old, new):
                changed.append(path)
        for path in source.glob("luasrc/controller/*.lua"):
            if move_lua(path, old, new):
                changed.append(path)
    if not changed:
        raise SystemExit(f"LuCI menu route changed upstream or missing: {app}: {old}")
    print(f"{app}: {old} -> {new} ({', '.join(map(str, changed))})")
