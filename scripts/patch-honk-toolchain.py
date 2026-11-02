#!/usr/bin/env python3
"""Keep honk's pinned Rust toolchain ahead of OpenWrt's host Rust binaries."""
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
marker = "# Wall-WRT: use honk's pinned toolchain for the core build."
if marker in text:
    print(f"Already patched: {path}")
    sys.exit(0)
anchor = 'echo "honk: building honk-core"\nenv \\\n'
if text.count(anchor) != 1:
    raise SystemExit(f"Unexpected honk build.sh layout: {path}")
replacement = '''# Wall-WRT: use honk's pinned toolchain for the core build.
core_toolchain="$(sed -n 's/^channel = "\\([^"]*\\)"/\\1/p' rust-toolchain.toml)"
[ -n "$core_toolchain" ] || { echo "honk: missing pinned Rust toolchain" >&2; exit 1; }
echo "honk: building honk-core with Rust ${core_toolchain}"
env \\
  "PATH=${HOME}/.cargo/bin:${PATH}" \\
  "RUSTUP_TOOLCHAIN=${core_toolchain}" \\
'''
path.write_text(text.replace(anchor, replacement))
print(f"Patched honk Rust toolchain selection: {path}")
