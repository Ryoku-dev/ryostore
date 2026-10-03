pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io

Item {
    id: svc
    property var pluginApi
    property var data: ({seconds: 0, available: false})

    function refresh() {
        if (pluginApi && !probe.running)
            probe.running = true
    }
    function ingest(raw) {
        if (!raw || !raw.trim()) return
        try { data = JSON.parse(raw) }
        catch (e) { console.warn("nothing-screen-time: invalid activity output", e) }
    }
    onPluginApiChanged: refresh()
    Timer { interval: 10000; repeat: true; running: true; onTriggered: svc.refresh() }
    Process {
        id: probe
        command: svc.pluginApi
            ? [svc.pluginApi.pluginDir + "/bin/activity.py"]
            : []
        stdout: StdioCollector { onStreamFinished: svc.ingest(this.text) }
    }
}
