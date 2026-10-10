#!/usr/bin/env python3
"""Remove DNS detours to plain direct outbounds rejected by sing-box."""
from pathlib import Path
import sys


def patch(path):
    text = path.read_text()
    if '// Wall-WRT: normalize DNS direct detours' in text:
        return
    anchor = "writefile(RUN_DIR + '/hiddify-c.json', sprintf('%.J\\n', removeBlankAttrs(config)));"
    if text.count(anchor) != 1:
        raise ValueError('HomeProxy config serialization changed')
    text = text.replace(anchor, '''// Wall-WRT: normalize DNS direct detours after removing blank attributes.
// Plain direct outbounds have no dialer settings. DNS must use its own dialer;
// route.default_mark still applies. Keep proxy and configured direct detours.
function wall_wrt_normalize_dns(config) {
\tlet plain_direct = {};
\tmap(config.outbounds || [], (outbound) => {
\t\tif (outbound.type === 'direct' && length(keys(outbound)) === 2)
\t\t\tplain_direct[outbound.tag] = true;
\t});
\tmap(config.dns?.servers || [], (server) => {
\t\tif (plain_direct[server.detour])
\t\t\tdelete server.detour;
\t});
\treturn config;
}

let wall_wrt_config = removeBlankAttrs(config);
if (is_singbox)
\twall_wrt_config = wall_wrt_normalize_dns(wall_wrt_config);
writefile(RUN_DIR + '/hiddify-c.json', sprintf('%.J\\n', wall_wrt_config));''')
    path.write_text(text)


if __name__ == '__main__':
    patch(Path(sys.argv[1]))
