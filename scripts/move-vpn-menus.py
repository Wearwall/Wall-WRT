#!/usr/bin/env python3
"""Move selected LuCI package menus into the VPN top-level menu."""
import json
from pathlib import Path
import re

ROOT = Path.cwd()
APPS = {
    "luci-proto-wireguard": ("admin/status/wireguard", "admin/vpn/wireguard"),
    "luci-app-re-homeproxy": ("admin/services/homeproxy", "admin/vpn/homeproxy"),
    "luci-app-fchomo": ("admin/services/fchomo", "admin/vpn/fchomo"),
    "luci-app-openclash": ("admin/services/openclash", "admin/vpn/openclash"),
    "luci-app-nikki-rs": ("admin/services", "admin/vpn"),
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
    result = {}
    for key, value in data.items():
        target = key.replace(old, new, 1) if key.startswith(old + "/") else key
        if target in result:
            raise ValueError(f"Duplicate LuCI route {target}: {path}")
        result[target] = value
    if result == data:
        return False
    raw = json.dumps(result, ensure_ascii=False, indent=2).replace(old, new)
    path.write_text(raw + "\n")
    return True


def move_lua(path, old, new):
    parts = old.split("/")
    text = path.read_text()
    # Match LuCI entry()/alias() route arrays, retaining their quote style.
    pattern = re.compile(r'(["\'])admin\1\s*,\s*(["\'])' + re.escape(parts[1]) + r'\2')
    def substitute(match):
        return f'{match[1]}admin{match[1]}, {match[2]}vpn{match[2]}'
    updated, count = pattern.subn(substitute, text)
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
