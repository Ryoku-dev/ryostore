pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// The tile's own audio analyser. A plugin may not reach into the shell's
// services, so this is the sanctioned shape (the same one the ricelin bar
// style ships): the service owns a headless cava on the PipeWire playback
// monitor, and the content view reads it through pluginApi.mainInstance.
//
// cava runs only while something can actually be heard: a live playback stream
// exists on the public Pipewire graph. Silence stops the analyser instead of
// feeding it, and levels settle flat when frames stop arriving, so the bars
// fall to their rest slivers rather than freezing on the last peak.
//
// cava is optional: the store updater merges files and never installs
// packages, so a box without cava must degrade to a resting tile, not a dead
// one. The binary is probed once and only ever spawned when it is present.
Item {
    id: svc

    property var pluginApi

    readonly property int bars: 40
    readonly property int fps: 30

    // 0..1 per band, plus the mean: the honest play/pause signal, which covers
    // browser and game audio that no MPRIS player announces.
    property var levels: svc.flat()
    property real energy: 0
    property real lastReadMs: 0

    property bool available: false

    // A live playback stream is the gate: no stream, nothing to analyse. The
    // graph is re-scanned on every node change and snapshotted, because a
    // binding that walked Pipewire.nodes during a removal dispatch could
    // observe a node being torn down.
    property bool sounding: false
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
    Connections {
        target: Pipewire
        function onReadyChanged() { svc.scan(); }
        function onNodeAdded() { svc.scan(); }
        function onNodeRemoved() { svc.scan(); }
    }
    Component.onCompleted: svc.scan()

    readonly property bool analysing: svc.sounding && svc.available

    // cava's raw ascii frames: one line of `bars` semicolon-joined 0..100
    // values. The config is a plain string handed to the shell as an argv
    // positional (never interpolated into the `sh -c` body) and piped to cava's
    // stdin, so nothing is written to disk. exec makes quickshell's SIGTERM
    // reach cava: no orphaned analyser survives the tile being removed.
    readonly property string config: "[general]\n"
        + "framerate = " + svc.fps + "\nbars = " + svc.bars + "\n\n"
        + "[input]\nmethod = pipewire\nsource = auto\n\n"
        + "[output]\nmethod = raw\nraw_target = /dev/stdout\n"
        + "data_format = ascii\nascii_max_range = 100\nchannels = mono\nmono_option = average\n\n"
        + "[smoothing]\nnoise_reduction = 45\n"

    Process {
        running: true
        command: ["sh", "-c", "command -v cava >/dev/null 2>&1"]
        onExited: (code) => svc.available = (code === 0)
    }

    Process {
        id: cavaProc
        command: ["sh", "-c", "printf '%s' \"$1\" | exec cava -p /dev/stdin", "_", svc.config]
        // Bound, never assigned: an imperative `running = true` from the retry
        // timer would destroy this binding, and cava would then outlive every
        // gate meant to stop it. The backoff below expresses the same retry
        // without taking the binding away.
        running: svc.analysing && !cavaProc.backoff
        property bool backoff: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => svc.readBars(line)
        }
        // cava dying while it is still wanted (a transient PipeWire hiccup)
        // earns one paced retry, never a tight respawn loop.
        onExited: if (svc.analysing) {
            cavaProc.backoff = true;
            restartTimer.restart();
        }
    }

    Timer {
        id: restartTimer
        interval: 1200
        onTriggered: cavaProc.backoff = false
    }

    // cava sleeps once playback idles, so settle back to flat when frames stop.
    Timer {
        interval: 120
        running: svc.analysing
        repeat: true
        onTriggered: if (Date.now() - svc.lastReadMs > 260) {
            svc.levels = svc.flat();
            svc.energy = 0;
        }
    }

    onAnalysingChanged: {
        levels = flat();
        energy = 0;
        if (analysing)
            lastReadMs = 0;
    }

    function flat() {
        var a = [];
        for (var i = 0; i < svc.bars; i++)
            a.push(0);
        return a;
    }

    function norm(v) {
        var n = parseInt(v);
        if (isNaN(n))
            return 0;
        return Math.max(0, Math.min(1, n / 100));
    }

    function readBars(line) {
        var t = line.trim();
        if (!t)
            return;
        var parts = t.split(/[;\s]+/);
        if (parts.length < svc.bars)
            return;
        var out = [];
        var sum = 0;
        for (var i = 0; i < svc.bars; i++) {
            var v = svc.norm(parts[i]);
            out.push(v);
            sum += v;
        }
        svc.levels = out;
        svc.energy = sum / svc.bars;
        svc.lastReadMs = Date.now();
    }
}
