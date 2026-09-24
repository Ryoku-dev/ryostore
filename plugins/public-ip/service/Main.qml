pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

// service/Main.qml is the plugin's logic: no UI. The host loads one instance
// and hands it to every view as pluginApi.mainInstance, so the widget reads
// the live state.
//
// Polls https://checkip.amazonaws.com/ on a timer through bin/poll.sh
// (R6/R9-clean: no shell string built from input, a fixed argv only) and
// copies the last reading to the clipboard through bin/copy.sh on demand,
// passing the address as its own argv element, never interpolated into a
// shell string.
Item {
    id: svc

    // Set by the host after this loads; the plugin's settings live behind it.
    property var pluginApi
    readonly property var settings: pluginApi ? pluginApi.pluginSettings : null
    readonly property int pollSeconds: settings && settings.pollSeconds ? settings.pollSeconds : 60

    // Live state, defaults until the first poll lands.
    property string ip: ""
    property bool lastPollFailed: false
    property bool copied: false

    Process {
        id: pollProc
        command: [(svc.pluginApi ? svc.pluginApi.pluginDir : "") + "/bin/poll.sh"]
        stdout: StdioCollector {
            id: pollOut
            onStreamFinished: {
                const text = pollOut.text.trim();
                if (text.length > 0) {
                    svc.ip = text;
                    svc.lastPollFailed = false;
                } else {
                    svc.lastPollFailed = true;
                }
            }
        }
    }

    function poll() {
        pollProc.running = false;
        pollProc.running = true;
    }

    Process {
        id: copyProc
        stdout: StdioCollector {}
    }

    // Copies the current reading to the clipboard. A no-op while there is no
    // reading yet. Briefly flips `copied` so the widget can flash feedback.
    function copyToClipboard() {
        if (svc.ip.length === 0)
            return;
        copyProc.command = [(svc.pluginApi ? svc.pluginApi.pluginDir : "") + "/bin/copy.sh", svc.ip];
        copyProc.running = false;
        copyProc.running = true;
        svc.copied = true;
        copiedResetTimer.restart();
    }

    Timer {
        id: copiedResetTimer
        interval: 1500
        onTriggered: svc.copied = false
    }

    Timer {
        interval: svc.pollSeconds * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: svc.poll()
    }
}
