function validAddress(address) { return /^0x[0-9a-f]+$/i.test(String(address)); }
function wrap(index, step, length) { return length ? ((index + step) % length + length) % length : 0; }
function touch(history, address) { return [address].concat(history.filter(function(a) { return a !== address; })).slice(0, 256); }
// lastIpcObject can be empty until Quickshell refreshes a newly opened client.
// Its typed address/workspace/title are already live; never drop that window.
function clientFromToplevel(toplevel) {
    var client = Object.assign({}, toplevel.lastIpcObject || {});
    if (toplevel.address) client.address = '0x' + String(toplevel.address).replace(/^0x/, '');
    client.workspace = toplevel.workspace ? {id:toplevel.workspace.id, name:toplevel.workspace.name} : null;
    if (toplevel.title) client.title = toplevel.title;
    if (!client.class && toplevel.wayland) client.class = toplevel.wayland.appId || '';
    return client;
}
function snapshot(clients, history, active, workspaceId) {
    var result = clients.filter(function(c) {
        return c && validAddress(c.address) && c.mapped !== false && !c.hidden
            // A real Hyprland client must belong to a normal workspace.
            // Empty placeholder objects are not background apps or usable windows.
            && c.workspace && typeof c.workspace.id === 'number' && c.workspace.id > 0
            && String(c.workspace.name || '').indexOf('special:') !== 0
            && (workspaceId === undefined || c.workspace.id === workspaceId);
    });
    function rank(c) {
        if (c.address === active) return -1;
        var pos = history.indexOf(c.address);
        if (pos >= 0) return pos;
        var f = c.focusHistoryID;
        return history.length + ((f !== undefined && f >= 0) ? f : 100000);
    }
    result.sort(function(a,b) { return rank(a) - rank(b); });
    return result;
}
