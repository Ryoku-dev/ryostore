// apptime — today's app usage, tracked from the Wayland toplevel protocol.
//
// service/Main.qml is the plugin's logic and carries no UI. It follows the
// focused window through Quickshell.Wayland ToplevelManager
// (zwlr_foreign_toplevel_management) and idle through IdleMonitor
// (ext-idle-notify), so it runs on any compositor Ryoku supports and never
// touches a compositor-specific IPC. It banks per-app foreground seconds for
// the current local day, pauses while the user is idle, archives each finished
// day to stateDir/usage-YYYY-MM-DD.json and lets the panel browse the archive.
// Live state is persisted to stateDir/today.json, atomic writes, every 15 s and
// on unload. The glyph and the panel read the same live state through
// pluginApi.mainInstance.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import Quickshell.Wayland

Item {
    id: svc

    // set by the host after this file loads
    property var pluginApi

    // ---- today's tally (local time) ----
    property string dateKey: ""              // YYYY-MM-DD this tally belongs to
    property var tally: ({})                 // app id -> banked foreground seconds
    property string curApp: ""               // focused app id ("" = none/excluded)
    property double curSince: 0              // epoch ms the current segment began

    // ---- idle pause ----
    property int idleMinutesV: 5             // from settings, refreshed each tick
    property bool paused: false              // true while the user is idle

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

    // windows that should never count as "using an app"
    function excluded(app) {
        const c = String(app || "").toLowerCase();
        return c === ""
            || c.indexOf("org.quickshell") === 0   // shell surfaces (launcher, settings, store, lock)
            || c.indexOf("xdg-desktop-portal") === 0;
    }

    // drop keys that are excluded now (e.g. legacy org.quickshell seconds)
    function purgeExcluded() {
        for (const k in svc.tally)
            if (svc.excluded(k)) delete svc.tally[k];
    }

    // app id -> readable label ("org.mozilla.firefox" -> "Firefox")
    function prettyLabel(cls) {
        const s = String(cls || "").trim();
        if (s === "") return "Unknown";
        // skip the generic reverse-DNS tail (org.kde.kdeconnect.app -> kdeconnect)
        const GENERIC = ["app", "application", "client", "desktop", "gui",
                         "main", "bin", "binaries", "run", "start", "startup"];
        const parts = s.split(".");
        let last = "";
        for (let i = parts.length - 1; i >= 0; i--) {
            const p = String(parts[i] || "").trim();
            if (p === "" || GENERIC.indexOf(p.toLowerCase()) >= 0) continue;
            last = p;
            break;
        }
        if (last === "") last = s.split(".").pop();
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
    // focus tracking (compositor-neutral)
    // ------------------------------------------------------------------
    function closeSegment(now) {
        if (svc.curApp !== "" && svc.curSince > 0 && !svc.excluded(svc.curApp)) {
            const secs = (now - svc.curSince) / 1000;
            if (secs > 0)
                svc.tally[svc.curApp] = (svc.tally[svc.curApp] || 0) + secs;
        }
        svc.curApp = "";
        svc.curSince = 0;
    }

    // bank the current segment and start one for `app` ("" banks only)
    function beginSegment(app, now) {
        svc.closeSegment(now);
        const c = String(app || "");
        if (c === "" || svc.excluded(c)) return;
        svc.curApp = c;
        svc.curSince = now;
    }

    // The focused app id, read from the activated toplevel. The activation flag
    // is what the protocol marks the focused window with on every compositor, so
    // this binding re-evaluates on a focus change and on a window closing.
    readonly property string focusedAppId: {
        const tls = ToplevelManager.toplevels ? ToplevelManager.toplevels.values : [];
        for (let i = 0; i < tls.length; i++) {
            const t = tls[i];
            if (t && t.activated === true)
                return String(t.appId || "");
        }
        return "";
    }

    onFocusedAppIdChanged: svc.onFocus()

    function onFocus() {
        if (svc.paused) return;             // resume happens explicitly on wake
        svc.beginSegment(svc.focusedAppId, Date.now());
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
            // freeze: bank up to the idle onset, remember what to resume.
            // isIdle fires `idleMinutes` after the last real input, so the
            // segment must stop that far back, not at Date.now(), or every
            // idle period is billed to the app as if it were still in use.
            const now = Date.now();
            const idleMs = svc.idleMinutesV * 60000;
            if (svc.curApp !== "")
                svc.closeSegment(Math.max(svc.curSince, now - idleMs));
            svc.paused = true;
            svc.save();
        } else if (!idleMon.isIdle && svc.paused) {
            svc.unpause();
        }
    }

    function unpause() {
        if (!svc.paused) return;
        svc.paused = false;
        // resume whichever window is focused now (the same one, normally; a
        // window that closed or lost focus while idle does not accrue time)
        svc.onFocus();
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
        // selIndex 1 = the most recent archive (yesterday); dates is ascending
        const k = svc.dates[svc.dates.length - svc.selIndex];
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
        svc.onFocus();                  // count whatever already has focus
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
        svc.save();
        svc.onFocus();                      // keep counting the focused app
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
            if (includeLive && k === svc.curApp && svc.curSince > 0)
                secs += (now - svc.curSince) / 1000;
            if (secs > 0) { map[k] = secs; total += secs; }
        }
        if (includeLive && svc.curApp !== "" && !svc.excluded(svc.curApp)
            && svc.curSince > 0 && map[svc.curApp] === undefined) {
            const lv = (now - svc.curSince) / 1000;
            map[svc.curApp] = lv;
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
