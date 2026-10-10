/* Exercise the real LuCI view with lightweight form/DOM/RPC adapters. */
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const nodes = new Map();
const created = [];
const polls = [];
let rpcStatus;
String.prototype.format = function (...args) {
    let i = 0;
    return this.replace(/%s/g, () => String(args[i++]));
};
function E(tag, attrs = {}, children = []) {
    const node = { tag, attrs, children: Array.isArray(children) ? children : [children], events: {},
        value: '', addEventListener(name, fn) { this.events[name] = fn; },
        replaceChildren(...items) { this.children = items; } };
    created.push(node);
    if (attrs.id) nodes.set(attrs.id, node);
    return node;
}
class FormMap {
    constructor() { this.sections = []; }
    section() {
        const section = { options: [], tab() {}, taboption(tab, type, name) {
            const option = { name, deps: [], value() {}, depends() {} };
            this.options.push(option);
            return option;
        } };
        this.sections.push(section);
        return section;
    }
    render() {
        for (const s of this.sections) {
            if (s.render) s.render();
            for (const o of s.options) if (o.render) o.render();
        }
    }
}
const form = { Map: FormMap };
const L = { resolveDefault: promise => promise, Poll: { add(fn) { polls.push(fn); } } };
const document = { getElementById: id => nodes.get(id), getElementsByClassName: () => [] };
const localStorage = { getItem: () => JSON.stringify({timestamp: Date.now(), data: {test: 'Test'}}) };
const moduleView = new Function('view', 'form', 'rpc', 'ui', 'uci', 'widgets', '_', 'E', 'L',
    'document', 'localStorage', fs.readFileSync(process.argv[2], 'utf8'))(
    { extend: value => value }, form, { declare: () => () => Promise.resolve(rpcStatus) },
    { addNotification() {}, addTimeLimitedNotification() {} }, {}, {}, text => text, E, L, document, localStorage);
async function main() {
    moduleView.render([{ status: 'logout', peers: {} }, {}, {routes: []}]);
    const body = nodes.get('tailscale_devices_tbody');
    const filter = nodes.get('tailscale_devices_filter');
    assert.ok(body && filter, 'Device table and filter render');
    assert.equal(body.children.length, 1, 'Logged-out state renders a message');
    filter.events.input.call(filter);
    const headers = created.find(n => n.tag === 'thead');
    assert.equal(headers.children[0].children.length, 8, 'Device list has eight column headers');
    rpcStatus = { status: 'running', peers: {one: {hostname: 'Laptop', ip: '100.64.0.1',
        ostype: 'linux', rx: 1024, tx: 2048, lastseen: '', online: true}} };
    await polls[0]();
    assert.ok(JSON.stringify(body.children).includes('Laptop'), 'Poll renders peer details');
    filter.value = 'nonmatching';
    filter.events.input.call(filter);
    assert.ok(JSON.stringify(body.children).includes('No peer devices found.'), 'Filter uses cached poll status');
    filter.value = 'laptop';
    filter.events.input.call(filter);
    assert.ok(JSON.stringify(body.children).includes('Laptop'), 'Filter restores matching peer');
    await polls[0]();
    assert.ok(JSON.stringify(body.children).includes('Laptop'), 'Refresh retains active filter');
    console.log('Tailscale UI passed: initial render, peer polling, filtering and refresh');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
