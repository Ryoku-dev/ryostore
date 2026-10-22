pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Radio Atlas service.
//
// Ported from akshar.radio-atlas (Omarchy bar widget). The Ryoku plugin
// contract splits persistent logic from UI: this file owns the station
// directory and the saved state (favourites, history, volume, audio output),
// while content/Panel.qml owns the live player session — the same split the
// Omarchy original had between its panel and its bar widget.
//
// Everything that runs is the upstream code under bin/; the only changes are
// the runtime paths, which are namespaced under this plugin instead of under
// Omarchy.
Item {
    id: svc

    property var pluginApi
    readonly property var settings: pluginApi ? pluginApi.pluginSettings : null

    // pluginApi.pluginDir is the one handle the host guarantees (R2/R8), but it
    // arrives empty on the very first load, so fall back to the resolved URL of
    // this file's own directory before giving up.
    readonly property string pluginRoot: pluginApi && pluginApi.pluginDir
        ? String(pluginApi.pluginDir) : ""
    readonly property string binDir: pluginRoot !== "" ? pluginRoot + "/bin" : ""

    // pluginApi.pluginDir can arrive empty on the first load; retry until the
    // host has handed it over rather than caching a wrong path.

    // R8: the plugin's own state dir is the only place it may write. The CLI
    // reads the same variable, so this service and bin/radio-state agree.
    readonly property string stateDir: pluginApi && pluginApi.stateDir
        ? String(pluginApi.stateDir) : ""

    readonly property bool allowFakeIp: {
        var s = svc.settings;
        return s ? s.allowFakeIp === true : false;
    }

    // --- saved state -----------------------------------------------------
    property var favorites: []
    property var recent: []
    property int volume: 70
    property string output: ""
    property string stateError: ""

    // --- the directory ---------------------------------------------------
    property var results: []
    property var worldStations: []
    property string fetchError: ""
    property var countries: ({})

    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR")
        + "/ryoku-radio-atlas"

    function bin(name) { return svc.binDir + "/" + name; }

    function readState() {
        if (stateProc.running) return;
        stateProc.command = [svc.bin("radio-state"), "get"];
        stateProc.running = true;
    }

    function toggleFavorite(uuid) {
        if (stateProc.running) return;
        stateProc.command = [svc.bin("radio-state"), "favorite", String(uuid)];
        stateProc.running = true;
    }

    function recordPlayed(uuid, selection) {
        if (stateProc.running) return;
        var argv = [svc.bin("radio-state"), "played", String(uuid)];
        if (selection === true) argv.push("selection");
        stateProc.command = argv;
        stateProc.running = true;
    }

    function chooseOutput(id) {
        if (stateProc.running) return;
        stateProc.command = [svc.bin("radio-state"), "output", String(id)];
        stateProc.running = true;
    }

    function setVolume(value) {
        if (stateProc.running) return;
        stateProc.command = [svc.bin("radio-state"), "volume", String(value)];
        stateProc.running = true;
    }

    function listOutputs() {
        if (outputsProc.running) return;
        outputsProc.command = [svc.bin("radio-player"), "outputs"];
        outputsProc.running = true;
    }

    function fetchWorld() {
        if (fetchProc.running) return;
        fetchProc.command = [svc.bin("radio-fetch"), "world"];
        fetchProc.running = true;
    }

    function search(query) {
        if (fetchProc.running) return;
        fetchProc.command = [svc.bin("radio-fetch"), "search", String(query)];
        fetchProc.running = true;
    }

    function browseCountry(code) {
        if (fetchProc.running) return;
        fetchProc.command = [svc.bin("radio-fetch"), "country", String(code)];
        fetchProc.running = true;
    }

    // Look a station up across every list the plugin holds, so a favourite can
    // be resolved even after its directory page has scrolled away.
    function findStation(uuid) {
        var wanted = String(uuid);
        var pools = [svc.results, svc.worldStations, svc.favorites, svc.recent];
        for (var i = 0; i < pools.length; i++) {
            var rows = pools[i] || [];
            for (var j = 0; j < rows.length; j++) {
                if (String(rows[j].uuid) === wanted) return rows[j];
            }
        }
        return null;
    }

    // --- processes -------------------------------------------------------
    Process {
        id: stateProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var state = JSON.parse(text);
                    svc.favorites = Array.isArray(state.favorites) ? state.favorites : [];
                    svc.recent = Array.isArray(state.recent) ? state.recent : [];
                    var next = Math.round(Number(state.volume === undefined ? 70 : state.volume));
                    svc.volume = isFinite(next) ? Math.max(0, Math.min(100, next)) : 70;
                    svc.output = String(state.output || "");
                    svc.stateError = "";
                } catch (error) {
                    svc.stateError = "Radio Atlas saved state could not be read";
                }
            }
        }
        onExited: function(exitCode) {
            if (exitCode !== 0) svc.stateError = "Radio Atlas could not save state";
        }
    }

    Process {
        id: outputsProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text);
                    svc.audioOutputs = Array.isArray(parsed.outputs) ? parsed.outputs : [];
                } catch (error) {
                    svc.audioOutputs = [];
                }
            }
        }
        onExited: function(exitCode) {
            if (exitCode !== 0) svc.audioOutputs = [];
        }
    }

    property var audioOutputs: []

    Process {
        id: fetchProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var payload = JSON.parse(text);
                    var rows = payload && typeof payload === "object"
                        && Array.isArray(payload.stations) ? payload.stations : payload;
                    if (Array.isArray(rows)) {
                        svc.results = rows;
                        if (rows.length > svc.worldStations.length)
                            svc.worldStations = rows;
                        svc.fetchError = "";
                    }
                } catch (error) {
                    svc.fetchError = "Radio Atlas could not read the station directory";
                }
            }
        }
        onExited: function(exitCode) {
            if (exitCode !== 0) svc.fetchError = "Radio Browser is unreachable";
        }
    }

    // The country names ship with the plugin as data.
    FileView {
        path: decodeURIComponent(Qt.resolvedUrl("../assets/countries.json").toString().replace(/^file:\/\//, ""))
        printErrors: false
        onLoaded: {
            try { svc.countries = JSON.parse(text() || "{}"); } catch (error) { svc.countries = ({}); }
        }
    }

    // The host assigns pluginApi after the object is created, so watch the
    // assignment and start as soon as the directory is real.
    property bool started: false
    onPluginApiChanged: svc.retryStart()
    onBinDirChanged: svc.retryStart()

    function retryStart() {
        if (svc.started || svc.binDir === "") return;
        svc.started = true;
        svc.readState();
        svc.fetchWorld();
    }

    Component.onCompleted: svc.retryStart()
}
