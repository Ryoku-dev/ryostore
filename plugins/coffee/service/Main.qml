pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "../content/Logic.js" as Logic

// Coffee's `main` entry point: headless state and logic, no UI. The host keeps
// one instance alive and hands it to every view as pluginApi.mainInstance, so
// the bar glyph, the bar panel and the desktop card all bind the same live
// state. State is polled from the host's own caffeine bridge
// (~/.config/hypr/scripts/ryoku-cmd-caffeine, the same script the shell's
// Keep-Awake toggle drives), so Coffee never forks the truth: the deck toggle,
// the quick settings tile and this plugin always agree, and a hold started
// here survives a shell reload exactly like the native one.
Item {
    id: svc
    // NOTE: no member may be named "poll" — `svc.poll()` from Timers would
    // resolve to the property (a number) and throw "not a function".

    // Set by the host after this loads; the plugin's settings live behind it.
    // Read settings through pluginApi.pluginSettings, always behind a default,
    // and write them only through pluginApi.saveSetting(key, value) (R5).
    property var pluginApi
    readonly property var settings: pluginApi ? pluginApi.pluginSettings : null

    // ── settings, each read behind its default ───────────────────────────────
    function _has(k) {
        return settings && settings[k] !== undefined && settings[k] !== null && settings[k] !== "";
    }
    function _num(k, d) { return _has(k) ? Number(settings[k]) : d; }
    function _str(k, d) { return _has(k) ? String(settings[k]) : d; }

    // Poll cadence in seconds, clamped to the manifest's range.
    readonly property int pollSeconds: Math.max(3, Math.min(60, Math.round(_num("poll", 10))))
    // What rides beside the bar mark: nothing or the ON/OFF state.
    readonly property string barLabel: _str("barLabel", "none")
    // Blank = the host's own caffeine bridge; set to point at an equivalent
    // script (same start/stop/status contract) on a system that lacks it.
    readonly property string helperPath: _str("helperPath", "")

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string script: Logic.resolveScript(helperPath, home)

    // ── aggregate state the views bind ───────────────────────────────────────
    // True while an idle inhibitor is held. Between a toggle and the first
    // confirmed status this is the optimistic expectation, so the glyph flips
    // instantly; the poll then confirms or corrects it.
    readonly property bool on: expected !== null ? expected : observed
    property bool observed: false
    // null when the settled state is unknown; set by the optimistic toggle.
    property var expected: null
    property real expectedUntil: 0
    // True until the first status poll lands: views show a neutral face.
    readonly property bool known: expected !== null || statusProc.ran
    // "" when all is quiet; otherwise the last action/poll failure.
    property string error: ""
    // Whether the panel's primary action is firing right now.
    readonly property bool busy: actionProc.running
    // Epoch ms Coffee last turned the inhibitor on, kept in the plugin's own
    // stateDir (R8) so "Awake for" survives a shell reload. 0 when unknown.
    property real since: 0
    // Ticked once a second while `on` so elapsed bindings refresh.
    property real nowMs: Date.now()

    // ── actions ──────────────────────────────────────────────────────────────
    // The one deliberate mutation, wired to the panel's primary button.
    function toggle() {
        if (actionProc.running)
            return;
        var target = !on;
        svc.expected = target;
        svc.expectedUntil = Infinity;
        _run(actionProc, target ? "start" : "stop");
    }

    function poll() {
        _run(statusProc, "status");
    }

    function _run(proc, action) {
        if (proc.running)
            return;
        proc.command = Logic.argvFor(svc.script, action);
        proc.running = true;
    }

    // Writes are confined to the plugin's stateDir (R8); a tiny shipped helper
    // keeps the audit clean (R9): bin/state-write writes the epoch to $1/since.
    function _markSince() {
        svc.since = Date.now();
        var dir = pluginApi ? pluginApi.stateDir : "";
        if (dir)
            Quickshell.execDetached([svc.pluginApi.pluginDir + "/bin/state-write", dir]);
    }

    // Restore the persisted start time so "Awake for" survives a shell reload.
    Process {
        id: sinceProc
        command: ["cat", (svc.pluginApi ? svc.pluginApi.stateDir : "/nonexistent") + "/since"]
        running: true
        stdout: StdioCollector { id: sinceOut; waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: function(code) {
            if (code === 0) {
                var secs = parseInt(String(sinceOut.text).trim(), 10);
                if (!isNaN(secs) && secs > 0)
                    svc.since = secs * 1000;
            }
        }
    }

    // ── processes ────────────────────────────────────────────────────────────
    // status: exit 0 = inhibitor held, non-zero = not held (empty stdout).
    Process {
        id: statusProc
        property bool ran: false
        property bool lastOk: false
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { id: statusErr; waitForEnd: true }
        onExited: function(code, status) {
            ran = true;
            lastOk = status === 0 && code === 0;
            svc.error = status === 0 && code <= 1 ? "" : Logic.commandError(code, status, statusErr.text);
            var exp = Logic.settleExpected(svc.expected, svc.expectedUntil, Date.now());
            if (exp === null) {
                svc.observed = lastOk;
                if (!lastOk)
                    svc.since = 0;
            } else {
                svc.observed = exp;
            }
        }
    }

    // start/stop: the process exits as soon as systemd-run has accepted (or
    // rejected) the job; the fast settle poll below confirms the real state.
    Process {
        id: actionProc
        stdout: StdioCollector { id: actionOut; waitForEnd: true }
        stderr: StdioCollector { id: actionErr; waitForEnd: true }
        onExited: function(code, status) {
            // exp = the optimistic state this action was driving toward.
            var err = Logic.commandError(code, status, actionErr.text);
            var exp = svc.expected;
            if (err) {
                svc.error = err;
                svc.expected = null;          // fall back to the next real poll
            } else {
                svc.error = "";
                svc.expectedUntil = Date.now() + 3000;
                if (exp === true)
                    svc._markSince();
                else if (exp === false)
                    svc.since = 0;
            }
            settleTimer.restart();
        }
    }

    // First confirmation right after an action lands, then the steady cadence.
    Timer {
        id: settleTimer
        interval: 800
        repeat: false
        onTriggered: svc.poll()
    }

    Timer {
        interval: svc.pollSeconds * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: svc.poll()
    }

    // 1 Hz heartbeat so "Awake for Xm" bindings refresh without a repoll.
    Timer {
        interval: 1000
        running: svc.on
        repeat: true
        onTriggered: svc.nowMs = Date.now()
    }
}
