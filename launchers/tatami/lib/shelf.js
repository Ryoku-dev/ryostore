.pragma library

// The shelf Tatami lays out: every visible desktop entry, sorted by name and
// filed under one section, then narrowed by the chosen section and the query.

// Each section claims freedesktop categories. An entry files under the first
// of its own categories that a section claims, so an app lands where it lists
// itself first rather than wherever a secondary tag would put it.
var SECTIONS = [
    { id: "internet", label: "Internet", claims: ["Network", "WebBrowser", "Email", "Chat", "InstantMessaging", "IRCClient", "FileTransfer", "P2P"] },
    { id: "media", label: "Media", claims: ["AudioVideo", "Audio", "Video", "Music", "Player", "Recorder", "Midi", "Mixer"] },
    { id: "graphics", label: "Graphics", claims: ["Graphics", "Photography", "2DGraphics", "3DGraphics", "RasterGraphics", "VectorGraphics", "Scanning", "Viewer"] },
    { id: "develop", label: "Develop", claims: ["Development", "IDE", "Debugger", "RevisionControl", "WebDevelopment", "Building", "GUIDesigner"] },
    { id: "office", label: "Office", claims: ["Office", "WordProcessor", "Spreadsheet", "Presentation", "Calendar", "ContactManagement", "Finance", "Publishing"] },
    { id: "games", label: "Games", claims: ["Game", "ActionGame", "AdventureGame", "ArcadeGame", "BoardGame", "CardGame", "Emulator", "LogicGame", "Simulation", "StrategyGame"] },
    { id: "system", label: "System", claims: ["System", "Settings", "DesktopSettings", "HardwareSettings", "Monitor", "TerminalEmulator", "PackageManager", "Security"] },
    { id: "utility", label: "Utility", claims: ["Utility", "Accessories", "FileManager", "FileTools", "TextEditor", "Archiving", "Calculator", "Clock", "Education", "Science"] }
];

function sectionOf(entry) {
    var categories = entry && entry.categories ? entry.categories : [];
    for (var i = 0; i < categories.length; i++)
        for (var j = 0; j < SECTIONS.length; j++)
            if (SECTIONS[j].claims.indexOf(String(categories[i])) >= 0)
                return SECTIONS[j].id;
    return "other";
}

function nameOf(entry) {
    return String(entry && entry.name || "");
}

// collect files every displayable entry once, alphabetically. Pinned ids are
// marked so the filter can lift them above the rest.
function collect(entries, pinned) {
    var pins = {};
    var list = pinned ? Array.prototype.slice.call(pinned).map(String) : [];
    for (var p = 0; p < list.length; p++)
        pins[list[p]] = true;
    var shelf = [];
    for (var i = 0; i < entries.length; i++) {
        var entry = entries[i];
        if (!entry || entry.noDisplay || nameOf(entry).length === 0)
            continue;
        shelf.push({ entry: entry, name: nameOf(entry), key: nameOf(entry).toLowerCase(), section: sectionOf(entry), pinned: pins[String(entry.id)] === true });
    }
    shelf.sort(function (a, b) { return a.key.localeCompare(b.key); });
    return shelf;
}

// sections lists All, then each section with apps in it. order names section
// ids in the wanted sequence (any it leaves out follow in the shipped order);
// hidden drops a section's chip, its apps stay under All and in search.
function sections(shelf, order, hidden) {
    var counts = {};
    for (var i = 0; i < shelf.length; i++)
        counts[shelf[i].section] = (counts[shelf[i].section] || 0) + 1;
    var labels = { other: "Other" };
    var ids = [];
    for (var j = 0; j < SECTIONS.length; j++) {
        labels[SECTIONS[j].id] = SECTIONS[j].label;
        ids.push(SECTIONS[j].id);
    }
    ids.push("other");
    var wanted = order ? Array.prototype.slice.call(order).map(String) : [];
    var skip = hidden ? Array.prototype.slice.call(hidden).map(String) : [];
    var seq = [];
    for (var k = 0; k < wanted.length; k++)
        if (ids.indexOf(wanted[k]) >= 0 && seq.indexOf(wanted[k]) < 0)
            seq.push(wanted[k]);
    for (var m = 0; m < ids.length; m++)
        if (seq.indexOf(ids[m]) < 0)
            seq.push(ids[m]);
    var list = [{ id: "all", label: "All", count: shelf.length }];
    for (var n = 0; n < seq.length; n++)
        if (counts[seq[n]] && skip.indexOf(seq[n]) < 0)
            list.push({ id: seq[n], label: labels[seq[n]], count: counts[seq[n]] });
    return list;
}

// rank orders a match: the name starting with the query beats a word in it
// starting so, which beats the query anywhere in the name, which beats it in
// the generic name, keywords or comment. -1 is no match.
function rank(item, query) {
    if (query.length === 0)
        return 0;
    if (item.key.indexOf(query) === 0)
        return 0;
    var words = item.key.split(/[\s\-_.]+/);
    for (var i = 1; i < words.length; i++)
        if (words[i].indexOf(query) === 0)
            return 1;
    if (item.key.indexOf(query) >= 0)
        return 2;
    var entry = item.entry;
    var extra = [String(entry.genericName || ""), String(entry.comment || "")]
        .concat(entry.keywords ? Array.prototype.slice.call(entry.keywords).map(String) : [])
        .join("\n").toLowerCase();
    return extra.indexOf(query) >= 0 ? 3 : -1;
}

// filter narrows the shelf to one section and the query, best match first. A
// query searches every section, so typing never hides an app behind a tab.
function filter(shelf, section, query) {
    var q = String(query || "").trim().toLowerCase();
    var hits = [];
    for (var i = 0; i < shelf.length; i++) {
        var item = shelf[i];
        if (q.length === 0 && section !== "all" && item.section !== section)
            continue;
        var score = rank(item, q);
        if (score >= 0)
            hits.push({ item: item, score: score, order: i });
    }
    hits.sort(function (a, b) {
        return a.score - b.score || (b.item.pinned ? 1 : 0) - (a.item.pinned ? 1 : 0) || a.order - b.order;
    });
    return hits.map(function (hit) { return hit.item; });
}
