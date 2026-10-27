pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../content/Logic.js" as Logic

// Smart Brightness service: watch the focused Wayland toplevel; when it is
// compositor-fullscreen and looks like media, bump the backlight to 100% and
// restore the saved level on exit. Detection uses ToplevelManager only — never
// hyprctl / niri / swaymsg — so it works on every Ryoku compositor. Brightness
// keys still work during a film: we do not re-clamp while video mode is active.
Item {
    id: svc

    property var pluginApi
    readonly property var settings: pluginApi ? pluginApi.pluginSettings : null

    function _has(k) {
        return settings && settings[k] !== undefined && settings[k] !== null && settings[k] !== "";
    }
    function _bool(k, d) {
        if (!settings || settings[k] === undefined || settings[k] === null)
            return d;
        return settings[k] === true || settings[k] === "true";
    }
    function _str(k, d) {
        return _has(k) ? String(settings[k]) : d;
    }

    // Settings (R5): enabled is the master switch; barLabel is glyph chrome.
    readonly property bool enabled: _bool("enabled", true)
    readonly property string barLabel: _str("barLabel", "state")

    // Live focus snapshot from foreign-toplevel.
    property bool focusedFullscreen: false
    property string focusedAppId: ""
    property string focusedTitle: ""

    readonly property bool wantVideo: Logic.shouldActivate(
        focusedFullscreen, focusedAppId, focusedTitle)

    // True while we have raised the backlight for a media fullscreen window.
    property bool videoActive: false
    // Last brightness percent we observed (informational).
    property int brightnessPercent: -1
    property string lastAction: ""

    readonly property string statusText: Logic.statusLabel(enabled, videoActive)
    readonly property string barText: {
        if (barLabel === "none")
            return "";
        return statusText.toUpperCase();
    }
    readonly property string focusSummary: {
        if (!focusedAppId && !focusedTitle)
            return "";
        var bits = [];
        if (focusedAppId.length > 0)
            bits.push(focusedAppId);
        if (focusedFullscreen)
            bits.push("fullscreen");
        return bits.join(" · ");
    }

    readonly property string _bin: {
        var dir = pluginApi ? pluginApi.pluginDir : "";
        return dir.length > 0 ? (dir + "/bin/brightness") : "";
    }
    readonly property string _stateDir: pluginApi ? pluginApi.stateDir : ""

    function setEnabled(on) {
        if (!pluginApi || !pluginApi.saveSetting)
            return;
        pluginApi.saveSetting("enabled", !!on);
        // Setting change rebinds `enabled`; tick after a beat so video mode
        // exits (or re-enters) against the new value.
        Qt.callLater(svc.tick);
    }

    function toggleEnabled() {
        setEnabled(!enabled);
    }

    function _run(proc, args) {
        if (!_bin || proc.running)
            return;
        proc.command = [_bin].concat(args);
        proc.running = true;
    }

    function enterVideoMode() {
        if (videoActive)
            return;
        if (_stateDir.length > 0)
            _run(saveProc, ["save", _stateDir]);
        videoActive = true;
        _run(setProc, ["set", "100"]);
        lastAction = "video: max backlight";
        refreshBrightness();
    }

    function exitVideoMode() {
        if (!videoActive)
            return;
        videoActive = false;
        if (_stateDir.length > 0)
            _run(restoreProc, ["restore", _stateDir]);
        lastAction = "restore backlight";
        refreshBrightness();
    }

    function tick() {
        _syncFocus();
        if (!enabled) {
            exitVideoMode();
            return;
        }
        if (wantVideo)
            enterVideoMode();
        else
            exitVideoMode();
    }

    function _syncFocus() {
        var tl = null;
        try {
            tl = ToplevelManager.activeToplevel;
        } catch (e) {
            tl = null;
        }
        if (!tl) {
            focusedFullscreen = false;
            focusedAppId = "";
            focusedTitle = "";
            return;
        }
        focusedFullscreen = !!tl.fullscreen;
        focusedAppId = String(tl.appId || "");
        focusedTitle = String(tl.title || "");
    }

    function refreshBrightness() {
        if (!_bin || getProc.running)
            return;
        getProc.command = [_bin, "get"];
        getProc.running = true;
    }

    Process {
        id: getProc
        stdout: StdioCollector {
            id: getOut
            waitForEnd: true
            onStreamFinished: {
                var n = parseInt(String(text).trim(), 10);
                if (!isNaN(n))
                    svc.brightnessPercent = n;
            }
        }
    }

    Process { id: setProc }
    Process { id: saveProc }
    Process { id: restoreProc }

    // Follow the focused toplevel and its identity / fullscreen changes.
    Connections {
        target: typeof ToplevelManager !== "undefined" ? ToplevelManager : null
        function onActiveToplevelChanged() { svc.tick(); }
    }

    Connections {
        target: {
            try {
                return typeof ToplevelManager !== "undefined"
                    ? ToplevelManager.activeToplevel : null;
            } catch (e) {
                return null;
            }
        }
        ignoreUnknownSignals: true
        function onFullscreenChanged() { svc.tick(); }
        function onAppIdChanged() { svc.tick(); }
        function onTitleChanged() { svc.tick(); }
    }

    // Backup poll: subscribe can miss a frame across compositor reloads.
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: svc.tick()
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: svc.refreshBrightness()
    }

    onEnabledChanged: Qt.callLater(svc.tick)

    Component.onCompleted: {
        tick();
        refreshBrightness();
    }

    Component.onDestruction: exitVideoMode()
}
