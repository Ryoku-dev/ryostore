pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Pinned apps, quick commands and the chosen widgets (all live in the plugin's settings),
// the app and widget lists to pick from, notes, an icon index, and a CPU / memory sample.
Item {
    id: svc

    property var pluginApi
    readonly property var settings: pluginApi && pluginApi.pluginSettings ? pluginApi.pluginSettings : ({})

    // A save takes a moment to round-trip through plugins.json. Until it lands, `pending`
    // holds the new value so the panel shows it at once and a quick second edit builds on
    // it instead of on the stale setting (which made reorders snap back).
    property var pending: ({})
    function get(key, def) {
        const v = svc.pending[key];
        return v !== undefined ? v : (svc.settings[key] ?? def);
    }
    function save(key, value) {
        const p = Object.assign({}, svc.pending);
        p[key] = value;
        svc.pending = p;
        pendingExpiry.restart();
        pluginApi.saveSetting(key, value);
    }
    onSettingsChanged: {
        const p = {};
        for (const k in svc.pending)
            if (JSON.stringify(svc.settings[k]) !== JSON.stringify(svc.pending[k])) p[k] = svc.pending[k];
        svc.pending = p;
    }
    // a save that never lands (tool failed) stops masking the real setting
    Timer { id: pendingExpiry; interval: 5000; onTriggered: svc.pending = ({}) }

    // apps: space-separated desktop ids, e.g. "firefox kitty org.gnome.Nautilus"
    readonly property var appIds: String(get("apps", "")).split(/\s+/).filter(x => x.length)
    // allApps is read so this re-resolves once the desktop entries load (heuristicLookup
    // alone is not reactive, so pins came up empty after a shell restart)
    readonly property var pinned: allApps.length >= 0 ? appIds.map(id => DesktopEntries.heuristicLookup(id)).filter(e => !!e) : []
    readonly property var allApps: DesktopEntries.applications.values
        .filter(e => !e.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))

    // commands: "Label=command ; Label=command"
    readonly property var commands: String(get("commands", "")).split(";")
        .map(c => c.trim()).filter(c => c.includes("="))
        .map(c => ({ label: c.slice(0, c.indexOf("=")).trim(), cmd: c.slice(c.indexOf("=") + 1).trim() }))

    property var icons: ({})
    property real cpu: 0        // 0..1
    property real mem: 0        // 0..1
    property real swap: 0       // 0..1
    property string memText: ""
    property var load: [0, 0, 0]
    property real uptime: 0     // seconds
    property var _lastCpu: null

    function icon(entry) {
        const n = entry ? String(entry.icon || "") : "";
        if (n.startsWith("/")) return "file://" + n;
        return svc.icons[n] ? "file://" + svc.icons[n] : "";
    }
    function isPinned(entry) { return svc.appIds.includes(entry.id); }
    function togglePin(entry) {
        const ids = svc.isPinned(entry) ? svc.appIds.filter(x => x !== entry.id) : svc.appIds.concat([entry.id]);
        svc.save("apps", ids.join(" "));
    }
    // list with the item at `from` moved to `to`; null when nothing changes
    function movedTo(list, from, to) {
        if (from < 0 || to < 0 || from >= list.length || to >= list.length || from === to) return null;
        const a = list.slice();
        a.splice(to, 0, a.splice(from, 1)[0]);
        return a;
    }
    function moveApp(from, to) {
        const a = svc.movedTo(svc.pinned.map(e => e.id), from, to);
        if (a) svc.save("apps", a.join(" "));
    }
    function moveCommand(from, to) {
        const a = svc.movedTo(svc.commands, from, to);
        if (a) svc.saveCommands(a);
    }

    // sections: the panel order, "widgets pinned commands"; unknown keys drop,
    // missing ones append, so a new section shows up for old settings
    readonly property var allSections: ["widgets", "pinned", "commands"]
    readonly property var sectionOrder: {
        const o = String(get("sectionOrder", "")).split(/\s+/).filter(k => allSections.includes(k));
        return o.concat(allSections.filter(k => !o.includes(k)));
    }
    function moveSection(from, to) {
        const a = svc.movedTo(svc.sectionOrder, from, to);
        if (a) svc.save("sectionOrder", a.join(" "));
    }

    function launch(entry) {
        entry.execute();
        pluginApi.closePanel();
    }

    function addCommand(label, cmd) {
        label = label.replace(/[=;]/g, " ").trim();
        cmd = cmd.replace(/;/g, " ").trim();
        if (!label || !cmd) return;
        svc.saveCommands(svc.commands.concat([{ label, cmd }]));
    }
    function removeCommand(i) { svc.saveCommands(svc.commands.filter((_, j) => j !== i)); }
    function saveCommands(list) {
        svc.save("commands", list.map(c => c.label + "=" + c.cmd).join(" ; "));
    }
    // ponytail: argv split with simple quotes, no shell (no pipes / && / $VARS); wrap a
    // script in bin/ or your PATH if you need those.
    function argv(cmd) {
        return (cmd.match(/"[^"]*"|'[^']*'|\S+/g) || []).map(a => a.replace(/^(["'])(.*)\1$/, "$2"));
    }
    function run(c) {
        Quickshell.execDetached(["ryoku-app", "terminal", "--"].concat(svc.argv(c.cmd)));
        pluginApi.closePanel();
    }
    // installed desktop-widget plugins, hosted in the panel's Widgets section
    property var deskPlugins: []

    // widgets: the chosen widget keys in panel order, e.g. "calendar notes plugin:awe-git-dashboard"
    readonly property var availableWidgets: [
        { key: "clock", label: "Clock" },
        { key: "calendar", label: "Calendar" },
        { key: "music", label: "Music" },
        { key: "aio", label: "All-in-one" },
        { key: "stats", label: "System stats" },
        { key: "weather", label: "Weather" },
        { key: "notes", label: "Notes" },
        { key: "visualizer", label: "Visualizer" }
    ].concat(deskPlugins.map(p => ({ key: "plugin:" + p.id, label: p.name, plugin: p })))
    readonly property var widgetKeys: String(get("widgetList", "calendar music notes")).split(/\s+/).filter(x => x.length)
    readonly property var chosenWidgets: widgetKeys.map(k => availableWidgets.find(w => w.key === k)).filter(w => !!w)
    function moveWidget(from, to) {
        const a = svc.movedTo(svc.chosenWidgets.map(w => w.key), from, to);
        if (a) svc.save("widgetList", a.join(" "));
    }
    function toggleWidget(key) {
        const ks = widgetKeys.includes(key) ? widgetKeys.filter(k => k !== key) : widgetKeys.concat([key]);
        svc.save("widgetList", ks.join(" "));
    }
    Process {
        id: plugList
        command: ["ryoku", "plugin", "list", "--json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    svc.deskPlugins = JSON.parse(this.text)
                        .filter(p => (p.hosts || []).includes("desktopWidget") && p.id !== "launchpad");
                } catch (e) {}
            }
        }
    }

    // notes: one plain-text file in stateDir, saved shortly after typing stops
    property string notes: notesFile.loaded ? notesFile.text() : ""
    FileView {
        id: notesFile
        path: svc.pluginApi ? svc.pluginApi.stateDir + "/notes.txt" : ""
        printErrors: false
        property bool loaded: false
        onLoaded: loaded = true
        onLoadFailed: loaded = true   // first run: no file yet
    }
    Timer { id: notesSave; interval: 600; onTriggered: notesFile.setText(svc.notes) }
    function setNotes(t) { if (t === svc.notes) return; svc.notes = t; notesSave.restart(); }

    // re-list desktop-widget plugins each time the panel opens
    readonly property bool panelOpen: pluginApi ? pluginApi.panelOpen : false
    onPanelOpenChanged: if (panelOpen && !plugList.running) plugList.running = true

    Process {
        command: ["ryoku-shell", "icons"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try { svc.icons = JSON.parse(this.text).icons || {}; } catch (e) {}
            }
        }
    }

    FileView { id: stat; path: "/proc/stat"; blockAllReads: true; printErrors: false }
    FileView { id: loadavg; path: "/proc/loadavg"; blockAllReads: true; printErrors: false }
    FileView { id: uptimeFile; path: "/proc/uptime"; blockAllReads: true; printErrors: false }
    FileView { id: meminfo; path: "/proc/meminfo"; blockAllReads: true; printErrors: false }

    // sampled only while the panel is open
    Timer {
        interval: 2000
        repeat: true
        triggeredOnStart: true
        running: svc.pluginApi ? svc.pluginApi.panelOpen : false
        onTriggered: {
            stat.reload();
            meminfo.reload();
            const f = (stat.text().split("\n")[0] || "").trim().split(/\s+/).slice(1).map(Number);
            if (f.length >= 4) {
                const idle = f[3] + (f[4] || 0), total = f.reduce((a, b) => a + b, 0);
                if (svc._lastCpu && total > svc._lastCpu.total)
                    svc.cpu = 1 - (idle - svc._lastCpu.idle) / (total - svc._lastCpu.total);
                svc._lastCpu = { idle, total };
            }
            const m = meminfo.text();
            const kb = k => Number((m.match(new RegExp("^" + k + ":\\s+(\\d+)", "m")) || [0, 0])[1]);
            if (kb("MemTotal") > 0) {
                svc.mem = 1 - kb("MemAvailable") / kb("MemTotal");
                svc.memText = ((kb("MemTotal") - kb("MemAvailable")) / 1048576).toFixed(1) + " / " + (kb("MemTotal") / 1048576).toFixed(1) + " GiB";
            }
            svc.swap = kb("SwapTotal") > 0 ? 1 - kb("SwapFree") / kb("SwapTotal") : 0;
            loadavg.reload();
            svc.load = loadavg.text().trim().split(/\s+/).slice(0, 3).map(Number);
            uptimeFile.reload();
            svc.uptime = Number(uptimeFile.text().split(" ")[0]) || 0;
        }
    }

    // weather: the shell daemon's public `weather` feed (it owns the fetch, location and
    // units, set in Ryoku Hub), so this plugin makes no network call of its own
    property var weather: null
    Socket {
        id: wx
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryoku-shell.sock"
        parser: SplitParser {
            onRead: line => {
                try { const f = JSON.parse(line); if (f.status) svc.weather = f; } catch (e) {}
            }
        }
        onConnectedChanged: if (connected) { write("subscribe weather\n"); flush(); }
    }
    Timer {
        interval: 5000
        running: svc.panelOpen && !wx.connected
        repeat: true
        triggeredOnStart: true
        onTriggered: wx.connected = true
    }

    // visualizer: a cava spectrum, run only while a panel widget asks for it
    property int vizUsers: 0
    property var bars: []
    readonly property string cavaConf: pluginApi ? pluginApi.stateDir + "/cava.conf" : ""
    FileView { id: cavaFile; path: svc.cavaConf; printErrors: false }
    Process {
        id: cava
        command: ["cava", "-p", svc.cavaConf]
        running: svc.vizUsers > 0 && svc.panelOpen && svc.cavaConf.length > 0
        onRunningChanged: if (!running) svc.bars = []
        stdout: SplitParser {
            onRead: line => svc.bars = line.split(";").filter(x => x.length).map(x => Number(x) / 100)
        }
    }
    onCavaConfChanged: if (cavaConf) Qt.callLater(() => cavaFile.setText("[general]\nframerate = 30\nbars = 32\n\n[input]\nmethod = pipewire\nsource = auto\n\n"
            + "[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\nascii_max_range = 100\nchannels = mono\nmono_option = average\n\n"
            + "[smoothing]\nnoise_reduction = 45\n"))
}
