pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

Item {
    id: svc
    property var pluginApi
    property var data: ({level: -1, charging: false})

    function refresh() {
        if (pluginApi && !probe.running)
            probe.running = true
    }

    function ingest(raw) {
        try { data = JSON.parse(raw) }
        catch (e) { console.warn("nothing-dashboard: invalid battery output", e) }
    }

    onPluginApiChanged: refresh()

    Timer {
        interval: 10000
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
