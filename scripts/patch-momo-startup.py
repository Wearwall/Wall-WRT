#!/usr/bin/env python3
"""Reject undecodable subscriptions before replacing the cached profile."""
from pathlib import Path
import sys


def patch(path):
    text = path.read_text()
    if '# Wall-WRT: validate subscription content' in text:
        return
    replacements = {
        '\t# check if success\n': '''\t# Wall-WRT: validate subscription content before replacing the cached profile.
\tif [ "$success" = 1 ]; then
\t\tif ! "$PROG" -c "$subscription_tmpfile" format > /dev/null 2>> "$CORE_LOG_PATH"; then
\t\t\tlog "Profile" "Downloaded content is not a decodable sing-box JSON profile; existing cache left unchanged. See core log."
\t\t\tsuccess=0
\t\tfi
\tfi
\t# check if success
''',
        '\t# mixin\n': '''\t# Decode before mixin so malformed downloads do not appear as missing inbounds.
\tif ! "$PROG" -c "$RUN_PROFILE_PATH" format > /dev/null 2>> "$CORE_LOG_PATH"; then
\t\tlog "Profile" "Cannot decode sing-box JSON profile; see core log."
\t\tlog "App" "Exit."
\t\treturn 1
\tfi
\t# mixin
''',
        '\t\tucode -S "$MIXIN_UC"\n': '''\t\tif ! ucode -S "$MIXIN_UC" >> "$CORE_LOG_PATH" 2>&1; then
\t\t\tlog "Mixin" "Config generation failed; see core log."
\t\t\tlog "App" "Exit."
\t\t\treturn 1
\t\tfi
''',
        '\t$PROG -c "$RUN_PROFILE_PATH" format -w\n': '''\tif ! "$PROG" -c "$RUN_PROFILE_PATH" format -w >> "$CORE_LOG_PATH" 2>&1; then
\t\tlog "Profile" "Cannot format generated sing-box profile; see core log."
\t\tlog "App" "Exit."
\t\treturn 1
\tfi
''',
    }
    for anchor, replacement in replacements.items():
        if text.count(anchor) != 1:
            raise ValueError(f'Momo startup layout changed: {anchor.strip()}')
        text = text.replace(anchor, replacement)
    path.write_text(text)


if __name__ == '__main__':
    patch(Path(sys.argv[1]))
