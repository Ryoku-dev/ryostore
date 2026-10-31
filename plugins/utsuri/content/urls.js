.pragma library

// Dropped URLs -> absolute local paths. Pure, so tests/test_urls.py runs it in node.
// Accepts file:///p and file://localhost/p, percent-decodes, skips anything else
// (http links, a malformed %-escape) instead of throwing, and drops duplicates.
function toPaths(urls) {
    const out = [];
    for (let i = 0; i < (urls ? urls.length : 0); i++) {
        let u = String(urls[i]);
        if (u.indexOf("file://localhost/") === 0)
            u = "file://" + u.slice("file://localhost".length);
        if (u.indexOf("file:///") !== 0)
            continue;
        let p;
        try {
            p = decodeURIComponent(u.slice("file://".length));
        } catch (e) {
            continue;
        }
        if (p.length > 1 && out.indexOf(p) === -1)
            out.push(p);
    }
    return out;
}

// "/a/b/Photo 1.png" -> "Photo 1.png"
function baseName(p) {
    const s = String(p);
    return s.slice(s.lastIndexOf("/") + 1);
}
