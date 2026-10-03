pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: svc
    property var pluginApi
    property var data: ({playing: false, available: false, title: "", artist: "",
                         position: 0, length: 0})
    property var lyricFrame: ({})
    readonly property string sockPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp")
        + "/ryoku-shell.sock"

    function refresh() {
        if (pluginApi && !probe.running)
            probe.running = true
    }
    function ingest(raw) {
        if (!raw || !raw.trim()) return
        try { data = JSON.parse(raw) }
        catch (e) { console.warn("nothing-media: invalid MPRIS output", e) }
    }
    function ingestLyrics(raw) {
        if (!raw || !raw.trim()) return
        try { lyricFrame = JSON.parse(raw) }
        catch (e) { console.warn("nothing-media: invalid lyric frame", e) }
    }
    function togglePlayback() {
        if (data.available && !toggle.running)
            toggle.running = true
    }
    onPluginApiChanged: refresh()
    Timer { interval: 2000; repeat: true; running: true; onTriggered: svc.refresh() }
    Process {
        id: probe
        command: svc.pluginApi ? [svc.pluginApi.pluginDir + "/bin/media.py"] : []
        stdout: StdioCollector { onStreamFinished: svc.ingest(this.text) }
    }
    Process {
        id: toggle
        command: ["playerctl", "play-pause"]
        onRunningChanged: if (!running) svc.refresh()
    }
    Socket {
        id: lyrics
        path: svc.sockPath
        parser: SplitParser { onRead: line => svc.ingestLyrics(line) }
        Component.onCompleted: connected = true
        onConnectionStateChanged: {
            if (connected) {
                write("subscribe music\n")
                flush()
            } else retry.restart()
        }
    }
    Timer {
        id: retry
        interval: 2000
        onTriggered: if (!lyrics.connected) lyrics.connected = true
    }
}
