#!/usr/bin/env python3
"""Restore missing device-list state/header declarations in the community UI."""
from pathlib import Path
import re
import sys


def patch(path):
    text = path.read_text()
    additions = []
    if 'lastDevicesStatus' in text and not re.search(r'\b(?:let|const|var)\s+lastDevicesStatus\b', text):
        additions.append('let lastDevicesStatus = null;')
    if 'peerTableHeaders' in text and not re.search(r'\b(?:let|const|var)\s+peerTableHeaders\b', text):
        additions.append("const peerTableHeaders = [\n" + ',\n'.join(
            f"\t{{ text: _('{title}') }}" for title in
            ('Status', 'Hostname', 'Tailscale IP', 'OS', 'Connection Info', 'RX', 'TX', 'Last Seen')
        ) + '\n];')
    if additions:
        if text.count('let map;') != 1:
            raise ValueError('Community UI layout changed; inspect module declarations')
        text = text.replace('let map;', 'let map;\n' + '\n'.join(additions), 1)
        path.write_text(text)
    print(f'Tailscale community UI: {len(additions)} missing declarations restored')


if __name__ == '__main__':
    patch(Path(sys.argv[1]))
