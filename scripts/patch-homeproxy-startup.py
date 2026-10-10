#!/usr/bin/env python3
"""Capture generator errors and validate sing-box before changing router DNS."""
from pathlib import Path
import sys


def patch(path):
    text = path.read_text()
    if '# Wall-WRT: capture generator failures' in text:
        return
    anchor = '\t\tucode "$HP_DIR/scripts/generate_client.uc"\n'
    if text.count(anchor) != 1:
        raise ValueError('HomeProxy generator invocation changed')
    text = text.replace(anchor, '''\t\t# Wall-WRT: capture generator failures in the diagnostics-visible log.
\t\tif ! ucode "$HP_DIR/scripts/generate_client.uc" >> "$LOG_PATH" 2>&1; then
\t\t\tlog "Error: client config generator exited unsuccessfully; see details above."
\t\t\treturn 1
\t\tfi
''')
    anchor = '\t# DNSMasq rules\n'
    if text.count(anchor) != 1:
        raise ValueError('HomeProxy DNS setup layout changed')
    text = text.replace(anchor, '''\t# Reject invalid configs before redirecting DNS or installing routing rules.
\tif [ ! -s "$RUN_DIR/hiddify-c.json" ]; then
\t\tlog "Error: generated client config is empty."
\t\treturn 1
\tfi
\tif [ "$CORE_TYPE" = "singbox" ]; then
\t\tif ! "$PROG" check --config "$RUN_DIR/hiddify-c.json" >> "$LOG_PATH" 2>&1; then
\t\t\tlog "Error: sing-box config validation failed; see details above."
\t\t\treturn 1
\t\tfi
\tfi

''' + anchor)
    path.write_text(text)


if __name__ == '__main__':
    patch(Path(sys.argv[1]))
