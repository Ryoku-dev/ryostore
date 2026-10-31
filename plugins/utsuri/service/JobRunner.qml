pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

// One background action from the radial menu: one bin/utsuri process, one
// reply. Created per drop (several can run at once, like Utsuri's thread
// pool) and destroyed after it reports. A job past ten minutes is stuck, not
// slow: SIGTERM, then SIGKILL; it reports either way, so a card never spins
// forever.
Item {
    id: runner

    property var command: []
    signal finished(var reply)
    signal slow()       // still running after 150 ms: time to show a spinner card

    property bool _done: false
    property string _out: ""

    function start() {
        proc.command = runner.command;
        slowTimer.start();
        watchdog.start();
        proc.running = true;
    }

    function _finish(reply) {
        if (runner._done)
            return;
        runner._done = true;
        slowTimer.stop();
        watchdog.stop();
        killTimer.stop();
        runner.finished(reply);
        runner.destroy();
    }

    function _parse(raw) {
        const text = (raw || "").trim();
        if (text.length === 0)
            return null;
        try {
            const lines = text.split("\n").filter(l => l.trim().length > 0);
            return JSON.parse(lines[lines.length - 1]);
        } catch (e) {
            return { ok: false, error: "Unreadable reply from bin/utsuri" };
        }
    }

    Process {
        id: proc
        stdout: StdioCollector { id: col; onStreamFinished: runner._out = text }
        onExited: (code) => {
            const d = runner._parse(col.text || runner._out);
            // a write is never retried: a missing reply might still have written a file
            runner._finish(d || { ok: false, error: "No reply from Utsuri (exit " + code + "). Check the folder before retrying." });
        }
    }

    Timer { id: slowTimer; interval: 150; onTriggered: runner.slow() }
    Timer {
        id: watchdog
        interval: 60 * 60 * 1000   // a long video encode is legitimate
        onTriggered: {
            proc.signal(15);
            killTimer.start();
        }
    }
    Timer {
        id: killTimer
        interval: 4000
        onTriggered: {
            proc.signal(9);
            runner._finish({ ok: false, error: "Stopped after 10 minutes with no answer" });
        }
    }
}
