/* Yatagarasu Roost — the service.
 * Persistent and non-visual: runs her listener on the
 * notification bus and holds the mood of the moment — the
 * priority of the freshest scroll still standing, "" when
 * the wire is clear. The listener is hers alone (bin/
 * monitor.py); if it ever falls, she sends it out again.
 */
import QtQuick
import Quickshell.Io

Item {
    id: root

    property var pluginApi

    property string mood: ""
    property real lastArriveAt: 0

    Process {
        id: monitor
        command: ["python3", (root.pluginApi ? String(root.pluginApi.pluginDir) : "") + "/bin/monitor.py"]
        running: true

        stdout: SplitParser {
            onRead: line => {
                const p = String(line).trim()
                if (p.indexOf("MOOD ") === 0) {
                    const v = p.substring(5)
                    root.mood = v === "EMPTY" ? "" : v
                } else if (p.indexOf("ARRIVE ") === 0) {
                    root.lastArriveAt = Date.now()
                }
            }
        }
        onExited: restartTimer.start()
    }

    Timer {
        id: restartTimer
        interval: 4000
        onTriggered: monitor.running = true
    }
}
