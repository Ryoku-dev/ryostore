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
//
// Enter is sequenced (get → remember → set 100) so a raced save cannot capture
// the already-maxed level and leave restore with nothing useful.
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

    readonly property bool enabled: _bool("enabled", true)
    readonly property string barLabel: _str("barLabel", "state")

    property bool focusedFullscreen: false
    property string focusedAppId: ""
    property string focusedTitle: ""

    readonly property bool wantVideo: Logic.shouldActivate(
        focusedFullscreen, focusedAppId, focusedTitle)

    property bool videoActive: false
    // True while we are mid get→save→set enter sequence.
    property bool entering: false
    // In-memory restore target; file under stateDir is the durable twin.
    property int savedPercent: -1
    property int brightnessPercent: -1
    property string lastAction: ""
    // After an exit, ignore re-enter for a beat so a flaky fullscreen signal
    // cannot immediately re-max and race the restore.
    property bool exitLatch: false

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
        Qt.callLater(svc.tick);
    }

    function toggleEnabled() {
        setEnabled(!enabled);
    }

    function _run(proc, args) {
        if (!_bin || proc.running)
            return false;
        proc.command = [_bin].concat(args);
        proc.running = true;
        return true;
    }

    function enterVideoMode() {
        if (videoActive || entering || exitLatch)
            return;
        if (!_bin) {
            videoActive = true;
            lastAction = "video: no brightness helper";
            return;
        }
        entering = true;
        lastAction = "video: reading backlight";
        // Always re-read: brightnessPercent may be stale or already 100.
        if (getProc.running) {
            // Busy; try again on the next tick.
            entering = false;
            return;
        }
        getProc._purpose = "enter";
        getProc.command = [_bin, "get"];
        getProc.running = true;
    }

    function _finishEnter(pct) {
        if (pct >= 0 && pct < 99)
            savedPercent = pct;
        if (_stateDir.length > 0 && savedPercent >= 0 && savedPercent < 99)
            _run(saveProc, ["save", _stateDir, String(savedPercent)]);
        videoActive = true;
        entering = false;
        _run(setProc, ["set", "100"]);
        lastAction = savedPercent >= 0
            ? ("video: max (was " + savedPercent + "%)")
            : "video: max backlight";
        brightnessPercent = 100;
    }

    function exitVideoMode() {
        if (!videoActive && !entering)
            return;
        entering = false;
        videoActive = false;
        exitLatch = true;
        exitLatchTimer.restart();

        var pct = savedPercent;
        if (pct >= 0 && pct < 99) {
            _run(setProc, ["set", String(pct)]);
            lastAction = "restore " + pct + "%";
            brightnessPercent = pct;
        } else if (_stateDir.length > 0) {
            _run(restoreProc, ["restore", _stateDir]);
            lastAction = "restore backlight";
            refreshBrightness();
        } else {
            lastAction = "restore skipped (no saved level)";
        }
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
        if (!_bin || getProc.running || entering)
            return;
        getProc._purpose = "poll";
        getProc.command = [_bin, "get"];
        getProc.running = true;
    }

    Process {
        id: getProc
        property string _purpose: "poll"
        stdout: StdioCollector {
            id: getOut
            waitForEnd: true
        }
        onExited: function(code) {
            var n = parseInt(String(getOut.text).trim(), 10);
            if (isNaN(n))
                n = -1;
            if (getProc._purpose === "enter") {
                if (!svc.wantVideo || !svc.enabled) {
                    // Left fullscreen while we were reading — abort enter.
                    svc.entering = false;
                    return;
                }
                svc._finishEnter(n);
                return;
            }
            if (n >= 0)
                svc.brightnessPercent = n;
        }
    }

    Process { id: setProc }
    Process { id: saveProc }
    Process { id: restoreProc }

    Timer {
        id: exitLatchTimer
        interval: 400
        repeat: false
        onTriggered: {
            svc.exitLatch = false;
            // Re-evaluate in case fullscreen media is still focused.
            svc.tick();
        }
    }

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
        // Warm brightnessPercent so a fast first enter still has a fallback.
        refreshBrightness();
        tick();
    }

    Component.onDestruction: exitVideoMode()
}
