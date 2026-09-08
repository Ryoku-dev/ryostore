// apptime — today's app usage, tracked from Hyprland focus events.
//
// service/Main.qml is the plugin's logic and carries no UI. It watches the raw
// Hyprland event stream for focus changes (the same source the built-in dock
// and bar particles use), banks per-app foreground seconds for the current
// local day, pauses while the user is idle (Wayland ext-idle-notify), archives
// each finished day to stateDir/usage-YYYY-MM-DD.json and lets the panel
// browse the archive. Live state is persisted to stateDir/today.json, atomic
// writes, every 15 s and on unload. The glyph and the panel read the same live
// state through pluginApi.mainInstance.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Item {
    id: svc

    // set by the host after this file loads
    property var pluginApi

    // ---- today's tally (local time) ----
    property string dateKey: ""              // YYYY-MM-DD this tally belongs to
    property var tally: ({})                 // app class -> banked foreground seconds
    property var addrClass: ({})             // window address -> app class (cache)
    property string curAddr: ""              // focused window address
    property string curClass: ""             // focused window class ("" = none/excluded)
    property double curSince: 0              // epoch ms the current segment began
    property string pendingAddr: ""          // focus addr waiting on the toplevel list
    property bool seeded: false              // warm-start focus resolved

    // ---- idle pause ----
    property int idleMinutesV: 5             // from settings, refreshed each tick
    property bool paused: false              // true while the user is idle
    property string resumeAddr: ""           // window to resume counting after idle
    property string resumeCls: ""

    // ---- history / day browsing ----
    property var dates: []                   // archived date keys, ascending
    property int selIndex: 0                 // 0 = today; n > 0 = dates[n-1]
    property string selDate: "today"
    property var selTally: ({})              // archived tally of the browsed day
    property int selTotalSeconds: 0
    property var selTopList: []              // ranked top list of the browsed day
    readonly property bool selIsToday: svc.selIndex === 0
    readonly property bool canOlder: svc.selIndex < svc.dates.length
    readonly property bool canNewer: svc.selIndex > 0
    readonly property string selLabel: svc.selIsToday ? "TODAY" : svc.fmtDate(svc.selDate)

    // ---- derived, refreshed once a second for the views ----
    property int totalSeconds: 0
    property var topList: []                 // { label, seconds, fraction, text }

    property bool initialized: false
    readonly property var settings: pluginApi ? pluginApi.pluginSettings : null

    // ------------------------------------------------------------------
    // helpers
    // ------------------------------------------------------------------
    function pad2(n) { return String(n).padStart(2, "0") }

    function todayKey() {
        const d = new Date();
        return d.getFullYear() + "-" + svc.pad2(d.getMonth() + 1) + "-" + svc.pad2(d.getDate());
    }

    function fmtDate(key) {
        const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        const parts = String(key || "").split("-");
        if (parts.length !== 3) return String(key || "");
        const m = parseInt(parts[1], 10);
        const d = parseInt(parts[2], 10);
        if (m < 1 || m > 12 || !d) return String(key || "");
        return MONTHS[m - 1] + " " + d;
    }

    function normAddr(a) {
        return String(a || "").trim().replace(/^0x/, "").toLowerCase();
    }

    // windows that should never count as "using an app"
    function excluded(cls) {
        const c = String(cls || "").toLowerCase();
        return c === "" || c === "hyprlock"
            || c.indexOf("org.quickshell") === 0   // shell surfaces (launcher, settings, store)
            || c.indexOf("xdg-desktop-portal") === 0;
    }

    // drop keys that are excluded now (e.g. legacy org.quickshell seconds)
    function purgeExcluded() {
        for (const k in svc.tally)
            if (svc.excluded(k)) delete svc.tally[k];
    }

    // class -> readable label ("org.mozilla.firefox" -> "Firefox")
    function prettyLabel(cls) {
        const s = String(cls || "").trim();
        if (s === "") return "Unknown";
        const last = s.split(".").pop();
        const out = [];
        const words = last.split(/[-_]/);
        for (let i = 0; i < words.length; i++) {
            const w = words[i];
            if (!w) continue;
            out.push(w[0].toUpperCase() + w.slice(1));
        }
        return out.length ? out.join(" ") : s;
    }

    // hours + minutes only, never seconds ("2h 05m", "45m", "<1m")
    function fmtHM(sec) {
        const s = Math.max(0, Math.floor(Number(sec) || 0));
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        if (h > 0) return h + "h " + svc.pad2(m) + "m";
        if (m > 0) return m + "m";
        return s > 0 ? "<1m" : "0m";
    }

    function topN() {
        const raw = svc.settings ? svc.settings.topCount : undefined;
        return Math.max(1, Math.min(10,
            (raw === undefined || raw === null) ? 5 : (parseInt(raw, 10) || 5)));
    }

    // ------------------------------------------------------------------
    // focus tracking
    // ------------------------------------------------------------------
    function classForAddr(addr) {
        const a = svc.normAddr(addr);
        if (a === "") return "";
        const tls = Hyprland.toplevels ? Hyprland.toplevels.values : [];
        for (let i = 0; i < tls.length; i++) {
            const o = tls[i] && tls[i].lastIpcObject;
            if (o && svc.normAddr(o.address) === a)
                return String(o.class || o.initialClass || "");
        }
        return "";
    }

    function closeSegment(now) {
        if (svc.curClass !== "" && svc.curSince > 0 && !svc.excluded(svc.curClass)) {
            const secs = (now - svc.curSince) / 1000;
            if (secs > 0)
                svc.tally[svc.curClass] = (svc.tally[svc.curClass] || 0) + secs;
        }
        svc.curAddr = "";
        svc.curClass = "";
        svc.curSince = 0;
    }

    // the still-open segment's seconds, if it belongs to `cls`
    function liveSeconds(cls) {
        if (svc.curClass === "" || svc.curClass !== cls || svc.curSince <= 0)
            return 0;
        return (Date.now() - svc.curSince) / 1000;
    }

    // start counting a known window (used by warm-start seed and idle resume)
    function beginSegment(addr, cls, now) {
        svc.closeSegment(now);
        const a = svc.normAddr(addr);
        if (a === "") return;
        svc.curAddr = a;
        if (cls !== "") svc.addrClass[a] = cls;
        if (svc.excluded(cls)) return;   // keep addr, count nothing
        svc.curClass = cls;
        svc.curSince = now;
    }

    function onFocus(addrRaw) {
        const now = Date.now();
        const addr = svc.normAddr(addrRaw);
        svc.closeSegment(now);            // bank the previous app
        if (addr === "") return;          // nothing focused now
        svc.seeded = true;
        const cached = svc.addrClass[addr];
        if (cached !== undefined && cached !== "") {
            if (!svc.excluded(cached)) {
                svc.curAddr = addr;
                svc.curClass = cached;
                svc.curSince = now;
            } else {
                svc.curAddr = addr;
            }
            return;
        }
        svc.curAddr = addr;
        svc.pendingAddr = addr;
        resolveTimer.restart();
    }

    // the toplevel list may lag a focus event by a tick; retry once it is fresh
    function resolvePending() {
        const addr = svc.pendingAddr;
        svc.pendingAddr = "";
        if (addr === "") return;
        const cls = svc.classForAddr(addr);
        if (cls === "") return;           // give up; the next event retries
        svc.addrClass[addr] = cls;
        if (svc.excluded(cls)) return;
        svc.curClass = cls;
        svc.curSince = Date.now();
    }

    // warm start: hyprctl marks the focused window focusHistoryID 0, but
    // Quickshell only moves that marker when the list is re-read, and the
    // refresh itself is async, so retry a few times before giving up.
    function seedFocus() {
        const tls = Hyprland.toplevels ? Hyprland.toplevels.values : [];
        for (let i = 0; i < tls.length; i++) {
            const o = tls[i] && tls[i].lastIpcObject;
            if (o && o.focusHistoryID === 0) {
                svc.beginSegment(o.address, String(o.class || o.initialClass || ""), Date.now());
                return o.class || o.initialClass || "";
            }
        }
        return "";
    }

    function trySeed() {
        if (svc.seeded) return;
        try { Hyprland.refreshToplevels(); } catch (e) {}
        Qt.callLater(function () {
            if (svc.seeded) return;
            const cls = svc.seedFocus();
            if (cls !== "" && !svc.excluded(cls)) { svc.seeded = true; return; }
            if (cls === "") seedRetryTimer.restart();   // list not fresh yet
        });
    }

    Timer {
        id: seedRetryTimer
        interval: 800
        repeat: false
        onTriggered: svc.trySeed()
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const name = event && event.name !== undefined ? String(event.name) : "";
            const data = event && event.data !== undefined ? String(event.data) : "";
            if (name === "activewindowv2") {
                svc.onFocus(data.split(",")[0].trim());
                Qt.callLater(function () { try { Hyprland.refreshToplevels(); } catch (e) {} });
            } else if (name === "closewindow") {
                const addr = svc.normAddr(data);
                if (addr === "") return;
                if (addr === svc.pendingAddr) { svc.pendingAddr = ""; resolveTimer.stop(); }
                if (addr === svc.curAddr) svc.closeSegment(Date.now());
                delete svc.addrClass[addr];
            }
        }
    }

    Timer {
        id: resolveTimer
        interval: 220
        repeat: false
        onTriggered: svc.resolvePending()
    }

    // ------------------------------------------------------------------
    // idle pause (Wayland ext-idle-notify; the compositor tracks real input)
    // ------------------------------------------------------------------
    IdleMonitor {
        id: idleMon
        enabled: svc.idleMinutesV > 0
        timeout: svc.idleMinutesV * 60000
        respectInhibitors: true
        onIsIdleChanged: svc.onIdleChanged()
    }

    function onIdleChanged() {
        if (svc.idleMinutesV <= 0) return;
        if (idleMon.isIdle && !svc.paused) {
            // freeze: bank up to the idle onset, remember what to resume
            const now = Date.now();
            if (svc.curClass !== "") {
                svc.resumeAddr = svc.curAddr;
                svc.resumeCls = svc.curClass;
                svc.closeSegment(now);
            }
            svc.paused = true;
            svc.save();
        } else if (!idleMon.isIdle && svc.paused) {
            svc.unpause();
        }
    }

    function unpause() {
        if (!svc.paused) return;
        svc.paused = false;
        if (svc.resumeCls !== "") {
            svc.beginSegment(svc.resumeAddr, svc.resumeCls, Date.now());
            svc.resumeAddr = "";
            svc.resumeCls = "";
        }
    }

    // ------------------------------------------------------------------
    // persistence: stateDir/{today.json, usage-*.json, history.json}
    // ------------------------------------------------------------------
    function save() {
        if (!svc.initialized || !svc.pluginApi || svc.dateKey === "") return;
        try {
            stateFile.setText(JSON.stringify({ date: svc.dateKey, apps: svc.tally, saved: Date.now() }));
        } catch (e) {}
    }

    function load() {
        if (!svc.pluginApi || svc.dateKey === "") return;
        try {
            const raw = stateFile.text();
            if (!raw) return;
            const obj = JSON.parse(raw);
            if (!obj || !obj.date || !obj.apps || typeof obj.apps !== "object") return;
            if (obj.date === svc.dateKey) {
                svc.tally = obj.apps;
            } else {
                // stale day: the shell was off across midnight -> archive + reset
                svc.archiveDay(obj.date, obj.apps);
                svc.tally = {};
            }
        } catch (e) {}
    }

    function archiveDay(dateK, apps) {
        if (!svc.pluginApi) return;
        try {
            archiveFile.path = svc.pluginApi.stateDir + "/usage-" + dateK + ".json";
            archiveFile.setText(JSON.stringify({ date: dateK, apps: apps || {}, saved: Date.now() }));
        } catch (e) {}
        svc.noteDate(dateK);
    }

    function noteDate(dateK) {
        if (svc.dates.indexOf(dateK) >= 0) return;
        const d = svc.dates.slice();
        d.push(dateK);
        d.sort();
        svc.dates = d;
        try {
            indexFile.setText(JSON.stringify({ dates: svc.dates, saved: Date.now() }));
        } catch (e) {}
    }

    // returns the tally object of an archived day (or {})
    function loadDay(dateK) {
        if (!svc.pluginApi) return {};
        try {
            archiveFile.path = svc.pluginApi.stateDir + "/usage-" + dateK + ".json";
            const raw = archiveFile.text();
            if (!raw) return {};
            const o = JSON.parse(raw);
            if (o && o.apps && typeof o.apps === "object") return o.apps;
        } catch (e) {}
        return {};
    }

    FileView {
        id: stateFile
        path: ""
        blockLoading: true
        watchChanges: false
        printErrors: false
        atomicWrites: true
    }

    FileView {
        id: archiveFile
        path: ""
        blockLoading: true
        watchChanges: false
        printErrors: false
        atomicWrites: true
    }

    FileView {
        id: indexFile
        path: ""
        blockLoading: true
        watchChanges: false
        printErrors: false
        atomicWrites: true
    }

    // ------------------------------------------------------------------
    // day browsing
    // ------------------------------------------------------------------
    function selectDay(idx) {
        const n = svc.dates.length;
        svc.selIndex = Math.max(0, Math.min(n, idx));
        svc.refreshSelection();
    }

    function stepDay(delta) { svc.selectDay(svc.selIndex + delta) }
    function goToday() { svc.selectDay(0) }

    function refreshSelection() {
        if (svc.selIndex === 0) {
            svc.selDate = "today";
            svc.selTally = {};
            return;
        }
        const k = svc.dates[svc.selIndex - 1];
        svc.selDate = k;
        svc.selTally = svc.loadDay(k);
    }

    // ------------------------------------------------------------------
    // lifecycle: init, midnight rollover, periodic save + view refresh
    // ------------------------------------------------------------------
    function initialize() {
        if (svc.initialized) return;
        svc.initialized = true;
        svc.dateKey = svc.todayKey();
        stateFile.path = svc.pluginApi.stateDir + "/today.json";
        indexFile.path = svc.pluginApi.stateDir + "/history.json";
        try {
            const raw = indexFile.text();
            if (raw) {
                const o = JSON.parse(raw);
                if (o && Array.isArray(o.dates)) svc.dates = o.dates;
            }
        } catch (e) {}
        svc.load();
        svc.purgeExcluded();            // clean any excluded seconds from older runs
        Qt.callLater(svc.save);         // persist the clean tally right away
        saveTimer.restart();
        midnightTimer.interval = svc.msToMidnight();
        midnightTimer.running = true;
        svc.trySeed();
    }

    onPluginApiChanged: if (svc.pluginApi) svc.initialize()

    Timer {
        id: saveTimer
        interval: 15000
        repeat: true
        running: false
        onTriggered: svc.save()
    }

    function msToMidnight() {
        const d = new Date();
        const n = new Date(d);
        n.setHours(24, 0, 0, 60);
        return Math.max(1000, n.getTime() - d.getTime());
    }

    function rollover() {
        const oldKey = svc.dateKey;
        svc.closeSegment(Date.now());       // bank the last pre-midnight stretch
        svc.archiveDay(oldKey, svc.tally);  // keep yesterday for the archive
        svc.dateKey = svc.todayKey();
        svc.tally = {};
        svc.seeded = false;
        svc.save();
        svc.trySeed();                      // keep counting the focused app
        midnightTimer.interval = svc.msToMidnight();
        midnightTimer.restart();
    }

    Timer {
        id: midnightTimer
        interval: 1
        repeat: false
        running: false
        onTriggered: svc.rollover()
    }

    // rank one day's tally; includeLive folds the open segment in for today
    function ranked(tallyLike, includeLive) {
        const now = Date.now();
        const map = {};
        let total = 0;
        for (const k in tallyLike) {
            if (svc.excluded(k)) continue;
            let secs = tallyLike[k];
            if (includeLive && k === svc.curClass && svc.curSince > 0)
                secs += (now - svc.curSince) / 1000;
            if (secs > 0) { map[k] = secs; total += secs; }
        }
        if (includeLive && svc.curClass !== "" && !svc.excluded(svc.curClass)
            && svc.curSince > 0 && map[svc.curClass] === undefined) {
            const lv = (now - svc.curSince) / 1000;
            map[svc.curClass] = lv;
            total += lv;
        }
        const arr = [];
        for (const k in map) arr.push({ key: k, seconds: map[k] });
        arr.sort((a, b) => b.seconds - a.seconds);
        const top = arr.slice(0, svc.topN());
        const mx = top.length ? top[0].seconds : 0;
        const out = [];
        for (let i = 0; i < top.length; i++) {
            const t = top[i];
            out.push({
                label: svc.prettyLabel(t.key),
                seconds: Math.round(t.seconds),
                fraction: mx > 0 ? Math.max(0.02, Math.min(1, t.seconds / mx)) : 0,
                text: svc.fmtHM(t.seconds)
            });
        }
        return { total: Math.round(total), list: out };
    }

    function refreshViews() {
        // settings -> idle timeout
        const rawIdle = svc.settings ? svc.settings.idleMinutes : undefined;
        const iv = (rawIdle === undefined || rawIdle === null)
            ? 5 : Math.max(0, Math.min(60, parseInt(rawIdle, 10) || 0));
        if (iv !== svc.idleMinutesV) {
            svc.idleMinutesV = iv;
            if (iv === 0 && svc.paused) svc.unpause();
        }

        const today = svc.ranked(svc.tally, true);
        svc.totalSeconds = today.total;
        svc.topList = today.list;
        if (svc.selIndex === 0) {
            svc.selTotalSeconds = today.total;
            svc.selTopList = today.list;
        } else {
            const v = svc.ranked(svc.selTally, false);
            svc.selTotalSeconds = v.total;
            svc.selTopList = v.list;
        }
    }

    Timer {
        id: tickTimer
        interval: 1000
        repeat: true
        running: true
        onTriggered: svc.refreshViews()
    }

    Component.onDestruction: {
        svc.closeSegment(Date.now());   // bank the open segment first
        svc.save();
    }
}
