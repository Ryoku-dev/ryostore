pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

// service/Main.qml is the plugin's logic: no UI. The host loads one instance
// and hands it to every view as pluginApi.mainInstance, so the widget and the
// panel read the same live state.
//
// Polls kdeconnectd over the session D-Bus (via bin/poll.sh, R6/R9-clean: no
// shell string built from input, a fixed argv only) on a timer. Read-only:
// the script only issues busctl Get/call on kdeconnectd's own properties and
// methods, it never sends a ping, file, or notification action.
Item {
    id: svc

    // Set by the host after this loads; the plugin's settings live behind it.
    property var pluginApi
    readonly property var settings: pluginApi ? pluginApi.pluginSettings : null
    readonly property int pollSeconds: settings && settings.pollSeconds ? settings.pollSeconds : 10

    // Live device state, defaults until the first poll lands.
    property bool found: false
    property string deviceName: ""
    property bool reachable: false
    property int charge: -1
    property bool charging: false
    property int notifCount: 0
    property bool lastPollFailed: false

    Process {
        id: pollProc
        command: [(svc.pluginApi ? svc.pluginApi.pluginDir : "") + "/bin/poll.sh"]
        stdout: StdioCollector {
            id: pollOut
            onStreamFinished: {
                try {
                    const data = JSON.parse(pollOut.text);
                    svc.lastPollFailed = false;
                    svc.found = !!data.found;
                    svc.deviceName = data.name || "";
                    svc.reachable = !!data.reachable;
                    svc.charge = (typeof data.charge === "number") ? data.charge : -1;
                    svc.charging = !!data.charging;
                    svc.notifCount = (typeof data.notifCount === "number") ? data.notifCount : 0;
                } catch (e) {
                    svc.lastPollFailed = true;
                    svc.found = false;
                }
            }
        }
    }

    function poll() {
        pollProc.running = false;
        pollProc.running = true;
    }

    Timer {
        interval: svc.pollSeconds * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: svc.poll()
    }
}
