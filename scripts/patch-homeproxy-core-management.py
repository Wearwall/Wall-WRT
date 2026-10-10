#!/usr/bin/env python3
"""Expose core updater failures and distinguish the bundled sing-box variant."""
from pathlib import Path
import sys


def replace_once(text, anchor, replacement):
    if text.count(anchor) != 1:
        raise ValueError(f'HomeProxy core management layout changed: {anchor[:70]}')
    return text.replace(anchor, replacement)


def patch_backend(path):
    text = path.read_text()
    if '// Wall-WRT: core update diagnostics' in text:
        return
    helper = '''// Wall-WRT: core update diagnostics; keep TLS and package verification settings.
function wall_wrt_release(core) {
\tconst url = core === 'hiddify'
\t\t? 'https://api.github.com/repos/1andrevich/hiddify-core/releases/latest'
\t\t: 'https://api.github.com/repos/shtorm-7/sing-box-extended/releases/latest';
\tconst logfile = '/tmp/homeproxy-core-api.log';
\tconst fd = popen(`if command -v curl >/dev/null 2>&1; then curl -fLsS --connect-timeout 5 --max-time 10 --retry 1 --retry-max-time 20 -H 'User-Agent: Wall-WRT-HomeProxy' ${shellquote(url)}; else wget -O- --timeout=20 -U Wall-WRT-HomeProxy ${shellquote(url)}; fi 2>${shellquote(logfile)}`);
\tif (!fd) return { error: 'Could not start GitHub release query' };
\tconst raw = trim(fd.read('all'));
\tconst rc = fd.close();
\tif (rc !== 0)
\t\treturn { error: 'GitHub release query failed: ' + substr(trim(readfile(logfile) || `exit ${rc}`), -600) };
\tlet data;
\ttry { data = json(raw); } catch(e) { data = null; }
\tif (!data?.tag_name)
\t\treturn { error: 'GitHub release response: ' + (data?.message || (length(raw) ? 'invalid release JSON' : 'empty response')) };
\treturn { data };
}

'''
    text = replace_once(text, 'const action = ARGV[0];', helper + 'const action = ARGV[0];')
    start = text.index("} else if (action === 'check_remote') {")
    end = text.index("} else if (action === 'prepare_install') {", start)
    text = text[:start] + '''} else if (action === 'check_remote') {
\tconst core = ARGV[1];
\tif (!(core in ['hiddify', 'singbox'])) {
\t\tresult = { error: 'illegal core' };
\t} else {
\t\tconst release = wall_wrt_release(core);
\t\tresult = release.error ? { error: release.error }
\t\t\t: { tag: release.data.tag_name, version: replace(release.data.tag_name, /^v/, '') };
\t}

''' + text[end:]
    # Both version lookup and package selection must use the same error-aware query.
    start = text.index("\t\t\t\t\t\tconst api_fd = popen(")
    end = text.index('\t\t\t\t\t\t\t\tlet dl_url = null;', start)
    text = text[:start] + '''\t\t\t\t\t\tconst release = wall_wrt_release(core);
\t\t\t\t\t\tif (release.error) {
\t\t\t\t\t\t\tresult = { error: release.error };
\t\t\t\t\t\t} else {
\t\t\t\t\t\t\tconst api_data = release.data;
''' + text[end:]
    # The replacement collapses one nested conditional in the original query.
    text = replace_once(text,
        '\t\t\t\t\t\t\t}\n\t\t\t\t\t\t}\n\t\t\t\t\t}\n\t\t\t\t}\n\t\t\t}\n\t\t}\n\t}\n\n} else if (action === \'download_pkg\') {',
        '\t\t\t\t\t\t}\n\t\t\t\t\t}\n\t\t\t\t}\n\t\t\t}\n\t\t}\n\t}\n\n} else if (action === \'download_pkg\') {')
    # Capture installer output without contaminating the JSON RPC response.
    start = text.index("} else if (action === 'install_pkg') {")
    end = text.index("} else if (action === 'install_kmods') {", start)
    install = text[start:end]
    install = replace_once(install, '\t\tlet exit_code;', "\t\tconst install_log = '/tmp/homeproxy-core-install.log';\n\t\tlet exit_code;")
    install = install.replace('>/dev/null 2>&1', '> ${shellquote(install_log)} 2>&1')
    # Keep failed packages for diagnosis/retry; only remove after success.
    install = install.replace('RC=$?; rm -f ${shellquote(tmp_path)}; exit $RC', 'RC=$?; [ "$RC" -ne 0 ] || rm -f ${shellquote(tmp_path)}; exit $RC')
    install = replace_once(install,
        "{ result: false, error: 'package installation failed' }",
        "{ result: false, error: 'Package installation failed: ' + substr(trim(readfile(install_log) || `exit ${exit_code}`), -1200), log_path: install_log }")
    text = text[:start] + install + text[end:]
    text = replace_once(text, '!!match(out, /amneziawg|with_amnezia/)', '!!match(out, /extended|amneziawg|with_amnezia/)')
    path.write_text(text)


def patch_ui(path):
    text = path.read_text()
    if '// Wall-WRT: label the installed core variant' in text:
        return
    text = replace_once(text, "\tconst name = isHiddify ? 'hiddify-core' : 'sing-box-extended';\n", '')
    text = replace_once(text,
        '\tconst coreData = (isHiddify ? coreInfo.hiddify : coreInfo.singbox) || {};',
        "\tconst coreData = (isHiddify ? coreInfo.hiddify : coreInfo.singbox) || {};\n\t// Wall-WRT: label the installed core variant, not only the update target.\n\tconst name = isHiddify ? 'hiddify-core' : (coreData.installed && !coreData.extended ? 'sing-box' : 'sing-box-extended');")
    text = replace_once(text,
        "\t\tconst prep = await L.resolveDefault(callCorePrepare(core, ''), {});\n\t\tif (prep.error) return fail(prep.error);",
        "\t\tconst prep = await L.resolveDefault(callCorePrepare(core, ''), {});\n\t\tif (prep.error || !prep.dl_url || !prep.tmp_path || !prep.pkg_manager)\n\t\t\treturn fail(prep.error || _('Unable to prepare core installation'));")
    # Make switching from the bundled standard core an explicit UI choice.
    start = text.index('function buildCoreCard(')
    end = text.index('\nreturn view.extend(', start)
    card = text[start:end]
    card = replace_once(card,
        ": _('Extended sing-box with additional protocols including AmneziaWG and TrustTunnel support. Created by shtorm-7.');",
        ": (coreData.installed && !coreData.extended ? _('Standard sing-box is installed. This installer switches to sing-box-extended.') : _('Extended sing-box with additional protocols including AmneziaWG and TrustTunnel support. Created by shtorm-7.'));")
    card = replace_once(card, "[ installed ? _('Update') : _('Install') ]",
        "[ installed ? (!isHiddify && !coreData.extended ? _('Install extended version') : _('Update')) : _('Install') ]")
    text = text[:start] + card + text[end:]
    path.write_text(text)


if __name__ == '__main__':
    root = Path(sys.argv[1])
    patch_backend(root / 'root/usr/share/homeproxy/scripts/core_mgmt.uc')
    patch_ui(root / 'htdocs/luci-static/resources/view/homeproxy/status.js')
    po = root / 'po/zh_Hans/homeproxy.po'
    entries = {
        'Standard sing-box is installed. This installer switches to sing-box-extended.': '当前安装的是普通 sing-box。此安装器将切换到 sing-box-extended。',
        'Install extended version': '安装扩展版',
        'Unable to prepare core installation': '无法准备核心安装，请查看请求错误。',
    }
    text = po.read_text()
    for source, translated in entries.items():
        if f'msgid "{source}"' not in text:
            text += f'\nmsgid "{source}"\nmsgstr "{translated}"\n'
    po.write_text(text)
