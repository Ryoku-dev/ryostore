pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io

Item {
    id: svc
    property var pluginApi
    property var data: ({volume: 0, muted: false})

    function refresh() {
        if (pluginApi && !probe.running)
            probe.running = true
    }
    function ingest(raw) {
        try { data = JSON.parse(raw) }
        catch (e) { console.warn("nothing-audio: invalid volume output", e) }
    }
    function toggleMute() {
        if (!toggle.running)
            toggle.running = true
    }
    onPluginApiChanged: refresh()
    Timer { interval: 3000; repeat: true; running: true; onTriggered: svc.refresh() }
    Process {
        id: probe
        command: svc.pluginApi ? [svc.pluginApi.pluginDir + "/bin/audio.py"] : []
        stdout: StdioCollector { onStreamFinished: svc.ingest(this.text) }
    }
    Process {
        id: toggle
        command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
        onRunningChanged: if (!running) svc.refresh()
    }
}
