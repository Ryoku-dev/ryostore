pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../content"
import Quickshell.Io
import Quickshell.Services.Pipewire

// Persistent service for the tile. The content reads everything from here
// through pluginApi.mainInstance when a widget needs a live object that
// survives the tile being hidden or re-mounted.
Item {
    id: svc

    property var pluginApi

    // per-plugin service logic

// Visualizer feed: the tile's own audio analyser. A plugin may not reach into
// the shell's services, so this is the sanctioned shape: a headless cava on the
// PipeWire playback monitor, frames pushed into GlobalStates.visualizerPoints
// that VisualizerWidget/VisualizerEngine consume. cava is optional: a box
// without it keeps a resting tile, not a dead one.
property bool sounding: false

readonly property int barCount: 50

function scan() {
    if (!Pipewire.ready) {
        svc.sounding = false;
        return;
    }
    var nodes = Pipewire.nodes ? Pipewire.nodes.values : [];
    var playing = false;
    for (var i = 0; i < nodes.length; i++) {
        var n = nodes[i];
        if (!n || !n.isStream || !n.audio)
            continue;
        var t = (typeof PwNodeType !== "undefined") ? PwNodeType.toString(n.type) : "";
        if (t.indexOf("In") < 0) {
            playing = true;
            break;
        }
    }
    svc.sounding = playing;
}

// Quickshell's Pipewire singleton exposes no node add/remove signals; poll
// the graph lightly so the gate opens the moment a stream appears.
Connections {
    target: Pipewire
    function onReadyChanged() { svc.scan(); }
}

Timer {
    interval: 500
    running: true
    repeat: true
    onTriggered: svc.scan()
}
Component.onCompleted: svc.scan()

property bool available: false
readonly property bool analysing: svc.sounding && svc.available

readonly property string cavaConfig: "[general]\n"
    + "framerate = 60\nbars = " + svc.barCount + "\n\n"
    + "[input]\nmethod = pipewire\nsource = auto\n\n"
    + "[output]\nmethod = raw\nraw_target = /dev/stdout\n"
    + "data_format = ascii\nascii_max_range = 100\nchannels = mono\nmono_option = average\n\n"
    + "[smoothing]\nnoise_reduction = 20\n"

Process {
    running: true
    command: ["sh", "-c", "command -v cava >/dev/null 2>&1"]
    onExited: (code) => svc.available = (code === 0)
}

Process {
    id: cavaProc
    command: ["sh", "-c", "printf '%s' \"$1\" | exec cava -p /dev/stdin", "_", svc.cavaConfig]
    // bound, never assigned: an imperative stop would destroy this binding and
    // leak a live cava. the backoff timer expresses the pause the same way.
    running: svc.analysing && !cavaProc.paused
    property bool paused: false
    stdout: SplitParser {
        splitMarker: "\n"
        onRead: (line) => {
            var t = line.trim();
            if (!t)
                return;
            var parts = t.split(/[;\s]+/);
            if (parts.length < svc.barCount)
                return;
            var out = [];
            for (var i = 0; i < svc.barCount; i++) {
                var v = parseInt(parts[i]);
                out.push(isNaN(v) ? 0 : Math.max(0, Math.min(100, v)));
            }
            GlobalStates.visualizerPoints = out;
            svc.lastReadMs = Date.now();
        }
    }
    onExited: if (svc.analysing && !paused) {
        cavaProc.paused = true;
        restartTimer.restart();
    }
}

Timer {
    id: restartTimer
    interval: 1200
    onTriggered: cavaProc.paused = false
}

// nothing playing: drain the feed so the visualizer settles instead of
// freezing on the last peak.
onAnalysingChanged: {
    GlobalStates.visualizerPoints = [];
    cavaProc.paused = false;
}

property real lastReadMs: 0

// cava sleeps once playback idles, so settle back to rest when frames stop.
Timer {
    interval: 120
    running: svc.analysing
    repeat: true
    onTriggered: if (Date.now() - svc.lastReadMs > 260)
        GlobalStates.visualizerPoints = [];
}

}
