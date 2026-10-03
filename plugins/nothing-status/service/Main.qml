pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

Item {
    id: svc
    property var pluginApi
    property var data: ({network: "unknown", volume: 0, muted: false,
                         battery: -1, charging: false, cpu: 0, memory: 0,
                         media: ""})

    function refresh() {
        if (pluginApi && !probe.running)
            probe.running = true
    }

    function ingest(raw) {
        try { data = JSON.parse(raw) }
        catch (e) { console.warn("nothing-status: invalid probe output", e) }
    }

    onPluginApiChanged: refresh()

    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: svc.refresh()
    }

    Process {
        id: probe
        command: svc.pluginApi ? [svc.pluginApi.pluginDir + "/bin/status.py"] : []
        stdout: StdioCollector { onStreamFinished: svc.ingest(this.text) }
    }
}
