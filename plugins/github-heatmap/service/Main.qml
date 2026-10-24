pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// The heatmap's logic, no UI: the settings, the range on show and the parsed
// calendar, refreshed through bin/gh-contrib (the public GitHub contributions
// page, no token). The widget binds this through pluginApi.mainInstance.
Item {
    id: svc

    property var pluginApi
    readonly property var settings: pluginApi ? pluginApi.pluginSettings : null

    // ── settings ─────────────────────────────────────────────────────────────
    // A value set from the widget lands here at once and is persisted through
    // the host: saveSetting on the bar, ryoku-plugins-place (the same tool the
    // desktop's own menu writes with) on the wallpaper, which has no
    // saveSetting. A saved value read back from the host then agrees with it.
    property var _over: ({})
    function cfg(k, d) {
        if (_over[k] !== undefined) return _over[k];
        if (settings && settings[k] !== undefined && settings[k] !== null && settings[k] !== "") return settings[k];
        return d;
    }
    function setSetting(k, v) {
        var patch = ({});
        patch[k] = v;
        setSettings(patch);
    }
    // several keys in one write (a preset), not one process per key
    function setSettings(patch) {
        var o = JSON.parse(JSON.stringify(_over));
        for (var k in patch) o[k] = patch[k];
        _over = o;
        if (pluginApi && typeof pluginApi.saveSetting === "function") {
            for (var j in patch) pluginApi.saveSetting(j, patch[j]);
        } else {
            Quickshell.execDetached(["ryoku-plugins-place", "github-heatmap", "settings", JSON.stringify(patch)]);
        }
    }
    // Once the host reads a value back, it owns that key again: a later change
    // from the right-click menu must win over what the card set earlier.
    onSettingsChanged: {
        var o = ({}), dropped = false;
        for (var k in _over) {
            if (settings && settings[k] === _over[k]) dropped = true;
            else o[k] = _over[k];
        }
        if (dropped) _over = o;
    }

    readonly property string username: String(cfg("username", "")).trim()
    readonly property string range: cfg("range", "year")          // year | last
    readonly property int refreshMin: Math.max(10, Math.min(240, Number(cfg("refreshMin", 30))))

    function setUsername(name) { setSetting("username", String(name).trim()); }

    // ── designs: one-click looks, each sets several settings at once ──
    // `design` is a plain setting, so the desktop's right-click menu can pick
    // one too; a change (from either side) applies its values once, and any
    // option can be tuned on top afterwards.
    readonly property var designs: ({
        github: { monthGap: 0, cellSize: 11, cellGap: 3, cellShape: "rounded", palette: "github",
            showMonths: true, showWeekdays: true, showStats: false, showLegend: true, showToolbar: true,
            weekdayStyle: "alt", monthFormat: "short", background: "glass" },
        blocks: { monthGap: 6, cellSize: 13, cellGap: 3, cellShape: "rounded", palette: "mono",
            showMonths: false, showWeekdays: false, showStats: false, showLegend: false, showToolbar: true,
            colorScale: "github", showEmpty: true, background: "glass" },
        minimal: { monthGap: 4, cellSize: 10, cellGap: 2, cellShape: "circle", palette: "accent",
            showMonths: false, showWeekdays: false, showStats: false, showLegend: false, showToolbar: false,
            background: "none" },
        full: { monthGap: 8, cellSize: 12, cellGap: 3, cellShape: "rounded",
            showMonths: true, showWeekdays: true, showStats: true, showLegend: true, showToolbar: true,
            monthFormat: "cap", weekdayStyle: "alt", background: "glass" }
    })
    readonly property string design: cfg("design", "")
    // null until the saved settings have loaded, so loading never re-applies
    property var _design: null
    onDesignChanged: {
        if (_design === null) return;
        // applied a tick later: writing settings inside this handler would
        // re-enter the `design` binding
        var v = designs[design];
        if (design !== _design && v) Qt.callLater(function () { svc.setSettings(v); });
        _design = design;
    }

    // ── data ─────────────────────────────────────────────────────────────────
    // The clock the card reads "today" from, ticked each minute so the grid,
    // the today mark and the streak roll over at midnight (and after a resume).
    property date now: new Date()
    readonly property string todayIso: _iso(now)
    readonly property int thisYear: now.getFullYear()
    Timer {
        interval: 60 * 1000
        running: true
        repeat: true
        onTriggered: svc.now = new Date()
    }
    onTodayIsoChanged: refresh()
    // New Year: move on to the new year instead of staying on the old one.
    onThisYearChanged: if (year === thisYear - 1) { year = thisYear; refresh(); }
    property int year: thisYear

    // { "YYYY-MM-DD": { count, level } }, the total and the stats over it.
    property var days: ({})
    property int total: 0
    property int streak: 0
    property int bestStreak: 0
    property int bestDay: 0
    property string bestDate: ""
    property int activeDays: 0
    property bool loading: false
    property string error: ""
    property string _buf: ""
    property string _want: ""
    // a refresh asked for while one runs is queued, not raced: stopping and
    // restarting the process in one go can drop the new run
    property bool _again: false

    function prevYear() { if (year > 2008) { year -= 1; refresh(); } }
    function nextYear() { if (year < thisYear) { year += 1; refresh(); } }

    function refresh() {
        if (!pluginApi || username.length === 0) return;
        if (fetch.running) { _again = true; return; }
        error = "";
        loading = true;
        _buf = "";
        _want = range === "last" ? "last" : String(year);
        fetch.command = [pluginApi.pluginDir + "/bin/gh-contrib", username, _want];
        fetch.running = true;
    }

    function _iso(d) {
        var m = d.getMonth() + 1, dd = d.getDate();
        return d.getFullYear() + "-" + (m < 10 ? "0" : "") + m + "-" + (dd < 10 ? "0" : "") + dd;
    }

    function _apply(text) {
        var j;
        try { j = JSON.parse(text); } catch (e) { error = "bad response"; return; }
        if (j.error) { error = j.error; return; }
        if (j.user !== username || String(j.year) !== _want) return; // stale answer
        var map = {};
        var run = 0, best = 0, top = 0, topDate = "", active = 0;
        for (var i = 0; i < j.days.length; i++) {
            var d = j.days[i];
            map[d.date] = { count: d.count, level: d.level };
            if (d.count > 0) { run += 1; active += 1; } else run = 0;
            if (run > best) best = run;
            if (d.count > top) { top = d.count; topDate = d.date; }
        }
        // Current streak: back from today (or yesterday, if today is still 0).
        var cur = 0;
        var t = new Date(now);
        if (!(map[_iso(t)] && map[_iso(t)].count > 0)) t.setDate(t.getDate() - 1);
        while (map[_iso(t)] && map[_iso(t)].count > 0) { cur += 1; t.setDate(t.getDate() - 1); }
        days = map;
        total = j.total;
        streak = cur;
        bestStreak = best;
        bestDay = top;
        bestDate = topDate;
        activeDays = active;
    }

    Process {
        id: fetch
        stdout: StdioCollector { onStreamFinished: svc._buf = text }
        onExited: (code) => {
            svc.loading = false;
            svc._apply(svc._buf);
            svc._buf = "";
            if (svc._again) { svc._again = false; svc.refresh(); }
        }
    }

    // No username set: ask the GitHub CLI who is logged in and keep that.
    function detectUser() {
        if (!pluginApi || username.length > 0 || whoami.running) return;
        whoami.running = true;
    }
    Process {
        id: whoami
        command: ["gh", "api", "user", "--jq", ".login"]
        stdout: StdioCollector {
            onStreamFinished: {
                var login = text.trim();
                if (/^[A-Za-z0-9-]{1,39}$/.test(login)) svc.setUsername(login);
            }
        }
    }

    onUsernameChanged: { days = ({}); total = 0; refresh(); }
    onRangeChanged: refresh()
    onPluginApiChanged: {
        detectUser();
        refresh();
        Qt.callLater(function () { svc._design = svc.design; });
    }

    Timer {
        interval: svc.refreshMin * 60 * 1000
        running: true
        repeat: true
        onTriggered: svc.username.length > 0 ? svc.refresh() : svc.detectUser()
    }
}
