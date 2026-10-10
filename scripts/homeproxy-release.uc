// Wall-WRT: core update diagnostics; keep TLS and package verification settings.
// Wall-WRT: release page fallback avoids dependence on the unauthenticated API quota.
function wall_wrt_request(url) {
	const logfile = '/tmp/homeproxy-core-api.log';
	const fd = popen(`if command -v curl >/dev/null 2>&1; then curl -fLsS --connect-timeout 5 --max-time 8 -H 'User-Agent: Wall-WRT-HomeProxy' ${shellquote(url)}; else wget -O- --timeout=8 -U Wall-WRT-HomeProxy ${shellquote(url)}; fi 2>${shellquote(logfile)}`);
	if (!fd) return { error: 'Could not start GitHub request' };
	const body = trim(fd.read('all'));
	const rc = fd.close();
	if (rc !== 0)
		return { error: substr(trim(readfile(logfile) || `exit ${rc}`), -600) };
	return { body };
}

function wall_wrt_release(core, require_assets) {
	const repo = core === 'hiddify' ? '1andrevich/hiddify-core' : 'shtorm-7/sing-box-extended';
	const api = wall_wrt_request(`https://api.github.com/repos/${repo}/releases/latest`);
	let data;
	try { data = json(api.body || ''); } catch(e) { data = null; }
	if (!api.error && data?.tag_name && (!require_assets || length(data.assets || [])))
		return { data };
	const api_error = api.error || data?.message || 'invalid release JSON';
	const page = wall_wrt_request(`https://github.com/${repo}/releases/latest`);
	if (page.error)
		return { error: `GitHub API: ${api_error}; release page: ${page.error}` };
	const tag_match = match(page.body, /property="og:url"[[:space:]]+content="[^"<>]*\/releases\/tag\/([^"<>]+)"/)
		|| match(page.body, /\/releases\/expanded_assets\/([A-Za-z0-9._+-]+)/);
	const tag = tag_match ? tag_match[1] : null;
	if (!tag || !match(tag, /^[A-Za-z0-9._+-]+$/))
		return { error: `GitHub API: ${api_error}; could not read release tag from page` };
	data = { tag_name: tag, assets: [] };
	if (!require_assets) return { data };
	const assets = wall_wrt_request(`https://github.com/${repo}/releases/expanded_assets/${tag}`);
	if (assets.error)
		return { error: 'Could not read release assets: ' + assets.error };
	const prefix = `/${repo}/releases/download/${tag}/`;
	for (let chunk in split(assets.body, 'href="')) {
		const path = split(chunk, '"')[0];
		if (index(path, prefix) !== 0) continue;
		const name = substr(path, length(prefix));
		if (!match(name, /^[A-Za-z0-9._+-]+\.(apk|ipk)$/)) continue;
		push(data.assets, { name, browser_download_url: 'https://github.com' + path });
	}
	if (!length(data.assets))
		return { error: 'No APK/IPK assets found on the release page' };
	return { data };
}
