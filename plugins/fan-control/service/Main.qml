pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// The Fan Control plugin's `main` entry point: headless state and logic, no UI.
// The host keeps one instance alive across content mounts and hands it to every
// view as pluginApi.mainInstance, so the bar glyph and the bar panel bind the
// same live state.
//
// Reading is free: the plugin's own bin/fanctl reads the kernel's hwmon files
// and answers a JSON status. The only privileged step is the write, and it runs
// as `pkexec <pluginDir>/bin/fanctl set ...` from a panel button tap - never
// from the bar mark, never on a timer, never with a value the panel did not
// offer. The helper itself clamps every level and refuses to drive a fan below
// the kernel's documented safe floor.
Item {
    id: svc

    // Set by the host after this loads; the plugin's settings live behind it.
    property var pluginApi
    readonly property var settings: pluginApi ? pluginApi.pluginSettings : null

    // Settings resolver: every value read behind a default (settings are not
    // auto-seeded at runtime), and clamped to the manifest's range.
    function _has(k) {
        return settings && settings[k] !== undefined && settings[k] !== null && settings[k] !== "";
    }
    function _num(k, d) { return _has(k) ? Number(settings[k]) : d; }
    function _str(k, d) { return _has(k) ? String(settings[k]) : d; }
    function _clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, Math.round(v))); }

    // Seconds between two unprivileged status reads.
    readonly property int poll: _clamp(_num("poll", 5), 2, 60)
    // The fixed level "Performance" applies (the helper's safe floor is 128).
    readonly property int performanceLevel: _clamp(_num("performanceLevel", 200), 128, 255)
    // Where the panel's custom slider starts, and what APPLY remembers.
    readonly property int customLevel: _clamp(_num("customLevel", 191), 128, 255)
    // Above this the readout turns to the warning colour.
    readonly property int warnTemp: _clamp(_num("warnTemp", 90), 40, 110)
    // What rides beside the bar mark: nothing, the rpm, the profile or the
    // hottest temperature.
    readonly property string barMode: _str("barText", "rpm")
    // Which helper the privileged writes go through: "auto" (the root-owned
    // system copy when it is installed, else the bundled one), "system" or
    // "bundled".
    readonly property string helperMode: _str("helperMode", "auto")

    // ── the helper, and who may run it ───────────────────────────────────────
    // The plugin's own copy, inside the installed plugin folder (R6: bin/).
    readonly property string bundledHelper: pluginApi ? String(pluginApi.pluginDir) + "/bin/fanctl" : ""
    // A root-owned copy at a fixed path. A polkit rule can safely grant that one
    // passwordless (nobody but root can rewrite it); the bundled copy can never
    // be granted, because it lives in a folder the user can write.
    readonly property string systemHelper: "/usr/local/bin/ryoku-fanctl"
    FileView {
        id: systemHelperFile
        path: svc.systemHelper
        blockLoading: true
        watchChanges: true
        printErrors: false
    }
    readonly property bool systemHelperInstalled: systemHelperFile.text().length > 0
    readonly property bool helperIsSystem: helperMode === "system"
        || (helperMode === "auto" && systemHelperInstalled)
    readonly property string helper: helperIsSystem ? systemHelper : bundledHelper

    // ── live state ───────────────────────────────────────────────────────────
    property var state: ({})
    property bool haveState: false
    // True from the moment a write is handed to pkexec until it exits, so the
    // panel can show that it is waiting on the authorisation prompt.
    property bool busy: false
    // One line describing the last action and how it went.
    property string lastAction: ""

    // ── derived: what the views read ─────────────────────────────────────────
    readonly property var control: (haveState && state.control) ? state.control : null
    readonly property bool controllable: control ? control.available === true : false
    // The kernel refuses fan writes (thinkpad_acpi loaded with fan_control=N).
    readonly property bool restricted: control ? control.restricted === true : false
    readonly property string blockReason: control && control.reason ? String(control.reason) : ""
    readonly property string chip: control && control.chip ? String(control.chip) : ""

    // Every fan tacho the machine exposes, flattened across hwmon chips.
    readonly property var fans: {
        var out = [];
        var cs = (haveState && state.chips) ? state.chips : [];
        for (var i = 0; i < cs.length; i++) {
            var fs = cs[i].fans || [];
            for (var j = 0; j < fs.length; j++)
                out.push({ id: String(fs[j].id), rpm: Number(fs[j].rpm), chip: String(cs[i].name) });
        }
        return out;
    }
    // Hottest readable sensors first. A sensor reading 0 (or less) is one the
    // chip does not populate, so it is dropped rather than shown as 0 degrees.
    readonly property var temps: {
        var out = [];
        var cs = (haveState && state.chips) ? state.chips : [];
        for (var i = 0; i < cs.length; i++) {
            var ts = cs[i].temps || [];
            for (var j = 0; j < ts.length; j++) {
                var c = Number(ts[j].celsius);
                if (!(c > 0)) continue;
                var lab = String(ts[j].label || "");
                out.push({ label: lab.length > 0 ? lab : String(ts[j].id), chip: String(cs[i].name), celsius: c });
            }
        }
        out.sort(function (a, b) { return b.celsius - a.celsius; });
        return out.slice(0, 6);
    }
    readonly property var topTemps: temps.slice(0, 4)

    readonly property int rpm: fans.length > 0 ? fans[0].rpm : -1
    readonly property real maxTemp: temps.length > 0 ? temps[0].celsius : -1
    readonly property bool hot: maxTemp > 0 && maxTemp >= warnTemp
    readonly property int enable: control ? Number(control.enable) : -1
    readonly property int level: control ? Number(control.pwm) : -1
    readonly property real minLevel: control ? Number(control.minLevel) : 128
    readonly property real maxLevel: control ? Number(control.maxLevel) : 255

    // pwm1_enable speaks the kernel's language: 2 EC/firmware auto, 1 manual,
    // 0 full speed (disengaged).
    readonly property string profile: enable === 2 ? "auto"
        : enable === 0 ? "max"
        : enable === 1 ? "manual" : "unknown"
    readonly property string profileLabel: profile === "auto" ? qsTr("AUTO")
        : profile === "max" ? qsTr("MAX")
        : profile === "manual" ? qsTr("MANUAL")
        : qsTr("UNKNOWN")

    // What the bar mark carries.
    readonly property string barText: {
        if (barMode === "none") return "";
        if (barMode === "profile") return profileLabel;
        if (barMode === "temp") return maxTemp > 0 ? Math.round(maxTemp) + "\u00b0" : "";
        return rpm > 0 ? String(rpm) : "";
    }
    // The mark's tooltip: the whole picture in one line.
    readonly property string summary: {
        var parts = [];
        if (rpm > 0) parts.push(rpm + " rpm");
        if (fans.length > 1) parts.push(fans.length + " " + qsTr("fans"));
        parts.push(profile === "manual" ? qsTr("manual level %1").arg(level) : profileLabel.toLowerCase());
        if (maxTemp > 0) parts.push(Math.round(maxTemp) + "\u00b0C");
        return parts.join(" \u00b7 ");
    }

    // ── polling (unprivileged) ───────────────────────────────────────────────
    property string pollBuf: ""
    Process {
        id: pollRead
        command: [svc.helper, "status", "--json"]
        stdout: StdioCollector { onStreamFinished: svc.pollBuf = text }
        onExited: (code) => svc._afterPoll(code)
    }
    function refresh() {
        if (svc.helper.length === 0 || pollRead.running) return;
        svc.pollBuf = "";
        pollRead.running = true;
    }
    function _afterPoll(code) {
        if (code === 0) {
            var j = null;
            try { j = JSON.parse(svc.pollBuf); } catch (e) { j = null; }
            if (j && j.ok) {
                svc.state = j;
                svc.haveState = true;
            } else {
                svc.lastAction = qsTr("unreadable fan status");
            }
        } else {
            svc.lastAction = qsTr("the fan helper could not be run");
        }
        svc.pollBuf = "";
    }

    // Poll on the cadence, and take one reading on load.
    Timer {
        interval: svc.poll * 1000
        running: svc.helper.length > 0
        repeat: true
        onTriggered: svc.refresh()
    }
    Component.onCompleted: svc.refresh()

    // A single refresh a moment after a write, once the EC has begun to ramp.
    Timer {
        id: soon
        interval: 2500
        repeat: false
        onTriggered: svc.refresh()
    }

    // ── writing (privileged, panel taps only) ────────────────────────────────
    // The label of the action in flight, for the status line.
    property string _label: ""
    property string writeErr: ""
    Process {
        id: writeOp
        stderr: StdioCollector { onStreamFinished: svc.writeErr = text }
        onExited: (code) => svc._afterWrite(code)
    }

    function _apply(cmd, label) {
        if (svc.helper.length === 0 || writeOp.running) return;
        svc._label = label;
        svc.writeErr = "";
        svc.busy = true;
        svc.lastAction = qsTr("%1: waiting for authorisation").arg(label);
        writeOp.command = cmd;
        writeOp.running = true;
    }
    // Hand the fans back to the EC - the state a fresh boot comes up in.
    function applyAuto() { _apply(["pkexec", svc.helper, "set", "auto"], qsTr("Auto")); }
    // A fixed high level: louder and cooler than the EC's own curve.
    function applyPerformance() { _apply(["pkexec", svc.helper, "set", "level", String(svc.performanceLevel)], qsTr("Performance")); }
    // The full-speed (disengaged) level, for the heaviest load.
    function applyMax() { _apply(["pkexec", svc.helper, "set", "max"], qsTr("Max")); }
    // A level the user picked on the panel's slider. The slider is clamped to the
    // helper's range, and the helper clamps again before it writes.
    function applyCustom(level) {
        var v = _clamp(level, 128, 255);
        if (svc.pluginApi) svc.pluginApi.saveSetting("customLevel", v);
        _apply(["pkexec", svc.helper, "set", "level", String(v)], qsTr("Custom %1").arg(v));
    }

    function _afterWrite(code) {
        svc.busy = false;
        var err = String(svc.writeErr).trim();
        if (code === 0) {
            svc.lastAction = qsTr("%1 applied").arg(svc._label);
        } else if (code === 126) {
            svc.lastAction = qsTr("authorisation dismissed");
        } else if (code === 127) {
            svc.lastAction = qsTr("the elevation prompt could not run the fan helper");
        } else {
            var first = err.length > 0 ? err.split("\n")[0].replace(/^fanctl: /, "") : "exit " + code;
            svc.lastAction = qsTr("%1 failed: %2").arg(svc._label).arg(first);
        }
        svc.writeErr = "";
        soon.restart();
    }
}
