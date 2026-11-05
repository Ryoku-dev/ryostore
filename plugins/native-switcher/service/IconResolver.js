// Same path-index semantics as the dock; no private shell imports.
function resolve(name, index) {
    var n = name === undefined || name === null ? '' : String(name);
    if (n.indexOf('/run/media/mydata') >= 0) return '';
    if (n.indexOf('file://') === 0) return n;
    if (n.charAt(0) === '/') return 'file://' + n;
    if (n.indexOf('image://icon/') === 0) n = n.substring(13);
    var hit = index[n];
    return hit && hit.indexOf('/run/media/mydata') !== 0 ? 'file://' + hit : '';
}
function forWindow(window, index, lookup) {
    var cls = window.class || '';
    var identities = {'Ryoku Settings':'ryoku-hub','Ryostore':'ryostore','ryovm':'ryovm'};
    if (cls === 'org.quickshell' && identities[window.title]) cls = identities[window.title];
    var candidates = [cls, window.initialClass || ''];
    for (var i = 0; i < candidates.length; i++) {
        if (!candidates[i]) continue;
        var entry = lookup(candidates[i]);
        var byEntry = entry && entry.icon ? resolve(entry.icon, index) : '';
        if (byEntry) return byEntry;
        var byClass = resolve(String(candidates[i]).toLowerCase(), index);
        if (byClass) return byClass;
    }
    return resolve('application-x-executable', index);
}
