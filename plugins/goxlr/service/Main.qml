pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

// service/Main.qml: the plugin's logic, no UI. One instance per bar copy of
// this plugin polls the goxlr-utility daemon's HTTP API (the same interface
// its own web UI uses) over loopback with curl, and every view
// (content/Widget.qml, content/Panel.qml) reads the live state published
// here through pluginApi.mainInstance. The daemon stays the only owner of the
// hardware; this never touches the device directly.
Item {
    id: svc

    // Set by the host after this loads. Settings are declared in
    // manifest.json metadata.settings and read behind a default (R5); they
    // are written only through pluginApi.saveSetting, which this plugin never
    // calls since it has no editable panel state of its own to persist.
    property var pluginApi
    readonly property var settings: pluginApi ? pluginApi.pluginSettings : null

    readonly property string host: (settings && settings.host && String(settings.host).trim() !== "") ? String(settings.host).trim() : "localhost"
    readonly property int port: (settings && settings.port) ? Math.floor(settings.port) : 14564
    readonly property string baseUrl: "http://" + svc.host + ":" + svc.port

    readonly property var channelList: ["Mic", "LineIn", "Console", "System", "Game", "Chat", "Sample", "Music", "Headphones", "MicMonitor", "LineOut"]
    readonly property var faderList: ["A", "B", "C", "D"]

    // ── Live state, published for the widget and the panel ─────────────────
    property bool connected: false
    property string serial: ""
    property string deviceType: ""
    property var volumes: ({})
    property var faders: ({})
    property var cough: ({})
    property string profileName: ""
    property string micProfileName: ""
    property string lastError: ""

    // A change worth flashing on the bar: the channel that moved, its new
    // level, and whether it is muted. Mirrors the original plugin's OSD, but
    // rendered inside the bar capsule itself since a bar plugin only owns one
    // panel and it is reserved for the user's own click.
    property string flashChannel: ""
    property int flashVolume: 0
    property bool flashMuted: false
    property bool flashVisible: false
    property double flashUntil: 0

    readonly property bool panelOpen: pluginApi ? pluginApi.panelOpen : false

    property bool _inFlight: false
    property bool _pendingRefresh: false
    property var _lastVolumes: null
    property var _lastMutes: null
    property string _lastSerial: ""
    property double _lastStart: 0

    // A burst wider than this is a profile load rewriting every level at
    // once, not a deliberate change worth flashing.
    readonly property int _flashBurstLimit: 3
    readonly property int _minGapMs: 120

    onPanelOpenChanged: {
        pollTimer.interval = svc.pollInterval();
        svc.poll();
    }
    onSettingsChanged: {
        pollTimer.interval = svc.pollInterval();
        svc.poll();
    }

    Component.onCompleted: {
        pollTimer.interval = svc.pollInterval();
        svc.poll();
    }

    // ── Presentation helpers ────────────────────────────────────────────────

    function volumeIsRaw() {
        return settings && settings.volumeDisplay === "raw";
    }

    function volumePercent(raw) {
        var clamped = Math.max(0, Math.min(255, Number(raw) || 0));
        return Math.round(clamped / 255 * 100);
    }

    function percentToVolume(pct) {
        var clamped = Math.max(0, Math.min(100, Number(pct) || 0));
        return Math.round(clamped / 100 * 255);
    }

    function volumeText(raw) {
        if (svc.volumeIsRaw())
            return String(Math.round(Number(raw) || 0));
        return svc.volumePercent(raw) + "%";
    }

    // Mic mute lives on the cough button; every other channel is muted
    // through the fader it is assigned to, and a channel on no fader cannot
    // be muted at all.
    function channelMuted(channel) {
        if (!svc.connected)
            return false;
        if (channel === "Mic" || channel === "MicMonitor")
            return svc.cough && svc.cough.state !== undefined && svc.cough.state !== "Unmuted";
        var fader = svc.faderFor(channel);
        if (fader === null)
            return false;
        var entry = svc.faders[fader];
        return entry ? entry.mute_state !== "Unmuted" : false;
    }

    function faderFor(channel) {
        for (var i = 0; i < svc.faderList.length; i++) {
            var f = svc.faderList[i];
            var entry = svc.faders[f];
            if (entry && entry.channel === channel)
                return f;
        }
        return null;
    }

    // ── Transport ────────────────────────────────────────────────────────────
    // One throwaway curl process per request, run through an argv array (R9:
    // never a shell string built from settings or daemon output).

    Component {
        id: curlFactory
        Process {
            id: proc
            property var onDone: null
            stdout: StdioCollector {
                id: outCollector
                waitForEnd: true
            }
            onExited: (code, status) => {
                var text = outCollector.text;
                var cb = proc.onDone;
                proc.destroy();
                if (cb)
                    cb(code === 0 ? text : null);
            }
        }
    }

    function runCurl(body, onDone) {
        var obj = curlFactory.createObject(svc, {
            "command": ["curl", "-s", "-S", "--max-time", "3", "-X", "POST", svc.baseUrl + "/api/command", "-H", "Content-Type: application/json", "--data-binary", body],
            "onDone": onDone
        });
        if (!obj) {
            if (onDone)
                onDone(null);
            return;
        }
        obj.running = true;
    }

    // Every reply is JSON; a transport failure and a non-zero curl exit both
    // arrive here as a null value plus a code the callers translate.
    function post(body, onResult) {
        svc.runCurl(body, function (text) {
            if (!onResult)
                return;
            if (text === null || text === undefined || text === "") {
                onResult(null, "unreachable");
                return;
            }
            var decoded = null;
            try {
                decoded = JSON.parse(text);
            } catch (e) {
                onResult(null, "bad_response");
                return;
            }
            onResult(decoded, null);
        });
    }

    function errorText(decoded) {
        if (decoded && typeof decoded === "object" && typeof decoded.Error === "string")
            return decoded.Error;
        return null;
    }

    function status(onResult) {
        svc.post(JSON.stringify("GetStatus"), function (decoded, err) {
            if (decoded === null) {
                onResult(null, err);
                return;
            }
            if (decoded && decoded.Status !== undefined) {
                onResult(decoded.Status, null);
                return;
            }
            onResult(null, svc.errorText(decoded) || "bad_response");
        });
    }

    // A GoXLRCommand variant, encoded by arity the daemon expects: no args is
    // an empty array, one arg is the bare value, two or more is an array.
    function encodeCommand(name, args) {
        var o = {};
        if (args.length === 0)
            o[name] = [];
        else if (args.length === 1)
            o[name] = args[0];
        else
            o[name] = args;
        return o;
    }

    // A device command: svc.send(serial, "SetVolume", "Music", 200).
    function send(serial, name) {
        if (!serial)
            return;
        var args = Array.prototype.slice.call(arguments, 2);
        var body = JSON.stringify({
            "Command": [serial, svc.encodeCommand(name, args)]
        });
        svc.post(body, null);
    }

    // ── Polling ──────────────────────────────────────────────────────────────
    // The daemon is local and answers in single-digit milliseconds, so a slow
    // poll is about not spinning the CPU rather than about cost. The cadence
    // tightens while the panel is open, and again while watching for a flash.

    function pollInterval() {
        if (svc.panelOpen)
            return 300;
        var ms = Math.max(250, Math.min(10000, Number(svc.settings ? svc.settings.refreshMs : 1000) || 1000));
        if (svc.flashEnabled()) {
            var detect = Math.max(100, Math.min(1000, Number(svc.settings ? svc.settings.flashPollMs : 200) || 200));
            ms = Math.min(ms, detect);
        }
        return ms;
    }

    function flashEnabled() {
        return !(svc.settings && svc.settings.flashEnabled === false);
    }

    function flashTimeoutMs() {
        return Math.max(500, Math.min(5000, Number(svc.settings ? svc.settings.flashTimeoutMs : 1500) || 1500));
    }

    function serials(status) {
        var list = [];
        if (!status || !status.mixers)
            return list;
        for (var key in status.mixers)
            list.push(key);
        list.sort();
        return list;
    }

    function applyStatus(status) {
        var list = svc.serials(status);
        if (list.length === 0) {
            svc.connected = false;
            svc.serial = "";
            return;
        }
        var serial = list[0];
        var mixer = status.mixers[serial];
        var levels = mixer.levels || {};
        var faders = {};
        for (var i = 0; i < svc.faderList.length; i++) {
            var f = svc.faderList[i];
            var entry = (mixer.fader_status || {})[f];
            if (entry)
                faders[f] = {
                    "channel": entry.channel,
                    "mute_state": entry.mute_state,
                    "mute_type": entry.mute_type
                };
        }
        svc.connected = true;
        svc.serial = serial;
        svc.deviceType = (mixer.hardware || {}).device_type || "";
        svc.volumes = levels.volumes || {};
        svc.faders = faders;
        svc.cough = mixer.cough_button || {};
        svc.profileName = mixer.profile_name || "";
        svc.micProfileName = mixer.mic_profile_name || "";
    }

    function muteSnapshot() {
        var m = {};
        for (var i = 0; i < svc.channelList.length; i++) {
            var c = svc.channelList[i];
            m[c] = svc.channelMuted(c);
        }
        return m;
    }

    // Which single change to flash. A volume that moved wins over a mute
    // that flipped; among several volumes the largest move wins. Ties fall
    // back to channel order, which puts Mic ahead of MicMonitor when the
    // cough button mutes both at once.
    function changedChannel(volumes, mutes) {
        if (!svc._lastVolumes || !svc._lastMutes)
            return null;
        var moved = null, movedDelta = -1, muteFlipped = null, count = 0;
        for (var i = 0; i < svc.channelList.length; i++) {
            var c = svc.channelList[i];
            var value = volumes[c], previous = svc._lastVolumes[c];
            var changed = false;
            if (typeof previous === "number" && typeof value === "number" && previous !== value) {
                changed = true;
                var delta = Math.abs(value - previous);
                if (delta > movedDelta) {
                    moved = c;
                    movedDelta = delta;
                }
            }
            if (mutes[c] !== svc._lastMutes[c]) {
                changed = true;
                if (muteFlipped === null)
                    muteFlipped = c;
            }
            if (changed)
                count += 1;
        }
        if (count === 0 || count > svc._flashBurstLimit)
            return null;
        return moved || muteFlipped;
    }

    function showFlash(channel) {
        svc.flashChannel = channel;
        svc.flashVolume = (svc.volumes || {})[channel] || 0;
        svc.flashMuted = svc.channelMuted(channel);
        svc.flashUntil = Date.now() + svc.flashTimeoutMs();
        svc.flashVisible = true;
    }

    function trackChanges() {
        var volumes = svc.volumes || {};
        var mutes = svc.muteSnapshot();

        // A different device, or one that just came back, has no history
        // worth diffing against: everything would read as a change.
        if (svc.serial !== svc._lastSerial) {
            svc._lastSerial = svc.serial;
            svc._lastVolumes = Object.assign({}, volumes);
            svc._lastMutes = mutes;
            return;
        }

        // Nothing to flash while the panel is open: the control that
        // changed is already on screen.
        if (svc.flashEnabled() && !svc.panelOpen) {
            var channel = svc.changedChannel(volumes, mutes);
            if (channel !== null)
                svc.showFlash(channel);
        }

        svc._lastVolumes = Object.assign({}, volumes);
        svc._lastMutes = mutes;
    }

    function clearTracking() {
        svc._lastVolumes = null;
        svc._lastMutes = null;
        svc._lastSerial = "";
        svc.flashVisible = false;
    }

    function queueRefresh() {
        svc._pendingRefresh = true;
    }

    function poll() {
        if (svc._inFlight) {
            svc.queueRefresh();
            return;
        }
        var now = Date.now();
        if (svc._minGapMs - (now - svc._lastStart) > 0) {
            svc.queueRefresh();
            return;
        }

        svc._lastStart = now;
        svc._pendingRefresh = false;
        svc._inFlight = true;
        pollTimer.interval = svc.pollInterval();

        svc.status(function (status, err) {
            svc._inFlight = false;
            if (status === null) {
                svc.connected = false;
                svc.lastError = err === "unreachable" ? "unreachable" : (err || "failed");
                svc.clearTracking();
            } else {
                svc.applyStatus(status);
                svc.lastError = "";
                if (svc.connected)
                    svc.trackChanges();
                else
                    svc.clearTracking();
            }
            if (svc._pendingRefresh)
                svc.poll();
        });
    }

    Timer {
        id: pollTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: if (!svc._inFlight)
            svc.poll()
    }

    // The flash's lifetime rides on a plain timer rather than the poll tick,
    // so it clears promptly even if the daemon is slow to answer.
    Timer {
        interval: 150
        running: svc.flashVisible
        repeat: true
        onTriggered: if (svc.flashVisible && Date.now() >= svc.flashUntil)
            svc.flashVisible = false
    }

    // ── Actions ──────────────────────────────────────────────────────────────

    // Mic mute is the cough button on both device families. Toggling asks
    // for the opposite of the state the last poll saw, so a hold-to-talk
    // profile still ends up where the user expects.
    function toggleMicMute() {
        if (!svc.connected)
            return;
        var muted = svc.cough && svc.cough.state !== "Unmuted";
        svc.send(svc.serial, "SetCoughMuteState", muted ? "Unmuted" : "MutedToAll");
        svc.poll();
    }

    // Mutes any other channel through the fader it is currently assigned to.
    // A channel on no fader cannot be muted, matching the device itself.
    function toggleChannelMute(channel) {
        if (!svc.connected)
            return;
        if (channel === "Mic" || channel === "MicMonitor") {
            svc.toggleMicMute();
            return;
        }
        var fader = svc.faderFor(channel);
        if (fader === null)
            return;
        var entry = svc.faders[fader];
        var muted = entry ? entry.mute_state !== "Unmuted" : false;
        svc.send(svc.serial, "SetFaderMuteState", fader, muted ? "Unmuted" : "MutedToX");
        svc.poll();
    }

    function adjustVolume(channel, deltaPercent) {
        var current = (svc.volumes || {})[channel];
        if (typeof current !== "number")
            return;
        var target = Math.max(0, Math.min(255, Math.round(current + deltaPercent / 100 * 255)));
        svc.setVolume(channel, target);
    }

    function setVolume(channel, rawTarget) {
        if (!svc.connected)
            return;
        var current = (svc.volumes || {})[channel];
        var target = Math.max(0, Math.min(255, Math.round(rawTarget)));
        if (target === current)
            return;
        svc.send(svc.serial, "SetVolume", channel, target);

        // Publish the new level immediately so the UI tracks the wheel or
        // slider instead of waiting a poll; the next poll confirms or
        // corrects it.
        var volumes = Object.assign({}, svc.volumes || {});
        volumes[channel] = target;
        svc.volumes = volumes;
        svc.poll();
    }
}
