pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "."

Singleton {
    id: root

    readonly property alias running: props.running
    readonly property alias paused: props.paused
    readonly property alias elapsed: props.elapsed
    property int refCount: 0
    property bool needsStart
    property list<string> startArgs
    property bool needsStop
    property bool needsPause

    function start(extraArgs = []): void {
        needsStart = true;
        startArgs = extraArgs;
        checkProc.running = true;
    }

    function stop(): void {
        needsStop = true;
        checkProc.running = true;
    }

    function togglePause(): void {
        needsPause = true;
        checkProc.running = true;
    }

    function ryokuStartArgs(): list<string> {
        if (startArgs.includes("-sr"))
            return ["--region", "--with-desktop-audio"];
        if (startArgs.includes("-r"))
            return ["--region"];
        if (startArgs.includes("-s"))
            return ["--with-desktop-audio"];
        return [];
    }

    function reconcile(isRunning: bool): void {
        if (isRunning && needsStop) {
            commandProc.exec(["ryoku-shell", "record", "stop"]);
            props.running = false;
            props.paused = false;
        } else if (isRunning && needsPause) {
            commandProc.exec(["ryoku-shell", "record", props.paused ? "resume" : "pause"]);
            props.paused = !props.paused;
        } else if (!isRunning && needsStart) {
            commandProc.exec(["ryoku-shell", "record", "start", ...ryokuStartArgs()]);
            props.running = true;
            props.paused = false;
            props.elapsed = 0;
        } else if (isRunning !== props.running && !commandProc.running) {
            props.running = isRunning;
            props.paused = false;
            props.elapsed = 0;
        }
        needsStart = false;
        needsStop = false;
        needsPause = false;
    }

    PersistentProperties {
        id: props
        property bool running: false
        property bool paused: false
        property real elapsed: 0
        reloadableId: "recorder"
    }

    Process {
        id: checkProc
        running: true
        command: ["ryoku-shell", "record", "status"]
        stdout: StdioCollector {
            onStreamFinished: root.reconcile(text.trim() === "recording")
        }
    }

    Process {
        id: commandProc
        onExited: checkProc.running = true
    }

    Timer {
        interval: 1000
        running: root.refCount > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: checkProc.running = true
    }

    Connections {
        function onSecondsChanged(): void {
            props.elapsed++;
        }
        enabled: props.running && !props.paused
        target: Time
    }
}
