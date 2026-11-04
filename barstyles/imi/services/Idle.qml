pragma Singleton

import QtQuick
import Quickshell
import "../modules/common"
import shell.services as HostServices

// Keep-awake for the bar's caffeine controls. The inhibition itself lives in the
// Ryoku daemon: flipping Flags.keepAwake is the whole manual path, so there is no
// Wayland inhibitor object here. Timed sessions are this file's own countdown on
// top of that flag, persisted like the original so a reload keeps the deadline.
Singleton {
    id: root

    // Not an alias: writing through this also runs the timed-session bookkeeping.
    property bool inhibit: false

    // Epoch ms at which a timed session ends; 0 means "indefinite".
    // Must be `real`: epoch ms is far past the range of QML's 32-bit int.
    property real expiresAt: 0
    readonly property bool timed: root.inhibit && root.expiresAt > 0
    // Recomputed from the wall clock rather than decremented: a Timer doesn't tick
    // through suspend, so anything counted down in software would be wrong after a resume.
    property real remainingMs: 0

    property real sessionMinutes: 0
    property bool _warned: false

    readonly property int extendMinutes: Config.options?.idle?.extendMinutes ?? 15
    readonly property var quickDurations: Array.from(Config.options?.idle?.quickDurations ?? []).slice(0, root.maxRecentDurations)
    readonly property int maxRecentDurations: 3
    readonly property var defaultDurations: [15, 30, 60]

    readonly property bool notifyOnExpiry: Config.options?.idle?.notifyOnExpiry ?? true
    readonly property int warnLeadSec: Config.options?.idle?.warnLeadSec ?? 60

    function formatMinutes(minutes) {
        if (minutes <= 0) return Translation.tr("Indefinite");
        if (minutes < 60) return Translation.tr("%1 min").arg(Math.round(minutes));
        const hours = Math.floor(minutes / 60);
        const mins = Math.round(minutes % 60);
        return mins > 0 ? Translation.tr("%1 h %2 min").arg(hours).arg(mins) : Translation.tr("%1 h").arg(hours);
    }

    readonly property string remainingText: {
        if (!root.timed || root.remainingMs <= 0) return "";
        const sec = Math.ceil(root.remainingMs / 1000);
        if (sec < 60) return Translation.tr("%1 s").arg(sec);
        // Seconds are zero-padded so the label doesn't jitter as 10 s ticks down to 9 s.
        if (sec < 600) {
            const wholeMin = Math.floor(sec / 60);
            const restSec = sec % 60;
            if (restSec === 0) return Translation.tr("%1 min").arg(wholeMin);
            return Translation.tr("%1 min %2 s").arg(wholeMin).arg(String(restSec).padStart(2, "0"));
        }
        const min = Math.ceil(sec / 60);
        if (min < 60) return Translation.tr("%1 min").arg(min);
        const hours = Math.floor(min / 60);
        const mins = min % 60;
        return mins > 0 ? Translation.tr("%1 h %2 min").arg(hours).arg(mins) : Translation.tr("%1 h").arg(hours);
    }

    // Plain on/off, always indefinite. Timed sessions go through inhibitFor()/extendBy().
    function toggleInhibit(active = null) {
        const next = active !== null ? active : !root.inhibit;
        root.expiresAt = 0;
        root.remainingMs = 0;
        root.sessionMinutes = 0;
        root._warned = false;
        root.inhibit = next;
        root._persist();
    }

    // minutes <= 0 means indefinite
    function inhibitFor(minutes) {
        if (minutes <= 0) {
            root.toggleInhibit(true);
            return;
        }
        root.expiresAt = Date.now() + minutes * 60000;
        root.sessionMinutes = minutes;
        root._warned = false;
        root.inhibit = true;
        root._recordDuration(minutes);
        root._persist();
        root._tick();
    }

    function extendBy(minutes) {
        if (minutes <= 0) return;
        if (root.inhibit && root.expiresAt <= 0) return;
        root.expiresAt = Math.max(Date.now(), root.expiresAt) + minutes * 60000;
        root.sessionMinutes = 0;
        root._warned = false;
        root.inhibit = true;
        root._persist();
        root._tick();
    }

    // Coarser the longer the duration, so the stepper stays quick to drive at either end
    function stepMinutes(minutes, direction) {
        const step = root._stepSizeFor(direction > 0 ? minutes : minutes - 1);
        const next = Math.round((minutes + direction * step) / step) * step;
        return Math.max(5, Math.min(1440, next));
    }

    function _stepSizeFor(minutes) {
        if (minutes < 60) return 5;
        if (minutes < 240) return 15;
        return 30;
    }

    // Durations are a most-recently-added list: a duration that isn't already
    // offered becomes a chip, pushing the oldest one off the end.
    function _recordDuration(minutes) {
        if (minutes <= 0) return;
        const current = root.quickDurations;
        if (current.indexOf(minutes) !== -1) return;
        Config.options.idle.quickDurations = [minutes].concat(current).slice(0, root.maxRecentDurations);
    }

    function _tick() {
        if (!root.timed) {
            root.remainingMs = 0;
            return;
        }
        const left = root.expiresAt - Date.now();
        root.remainingMs = Math.max(0, left);
        if (left <= 0) {
            root._expire();
            return;
        }
        if (!root._warned && root.notifyOnExpiry && root.warnLeadSec > 0 && left <= root.warnLeadSec * 1000) {
            root._warned = true;
            Quickshell.execDetached(["notify-send", "-a", "Keep awake", "-i", "hourglass_bottom", "-t", String(Math.max(5000, root.warnLeadSec * 1000)), "--hint=boolean:suppress-sound:true", Translation.tr("Keep awake ending"), Translation.tr("Sleep resumes in %1.").arg(root.remainingText)]);
        }
    }

    function _expire() {
        const shouldNotify = root.notifyOnExpiry;
        root.toggleInhibit(false);
        if (shouldNotify) {
            Quickshell.execDetached(["notify-send", "-a", "Keep awake", "-i", "bedtime", "-t", "5000", "--hint=boolean:suppress-sound:true", Translation.tr("Keep awake ended"), Translation.tr("The system can sleep again.")]);
        }
    }

    function _persist() {
        if (!Persistent.ready) return;
        Persistent.states.idle.inhibit = root.inhibit;
        Persistent.states.idle.expiresAt = root.expiresAt;
        Persistent.states.idle.durationMinutes = root.sessionMinutes;
    }

    // The daemon may restart under us and drop the flag; re-assert the session's state.
    onInhibitChanged: {
        if (HostServices.Flags.keepAwake !== root.inhibit)
            HostServices.Flags.keepAwake = root.inhibit;
    }

    Component.onCompleted: {
        root.inhibit = HostServices.Flags.keepAwake;
        root._restore();
    }

    Connections {
        target: HostServices.Flags
        function onKeepAwakeChanged() {
            // A toggle from another surface (or the daemon) with no live timer here
            // must still be reflected; one with a timer keeps its own deadline.
            if (HostServices.Flags.keepAwake !== root.inhibit) {
                root.expiresAt = 0;
                root.remainingMs = 0;
                root.sessionMinutes = 0;
                root.inhibit = HostServices.Flags.keepAwake;
            }
        }
    }

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        running: root.timed
        onTriggered: root._tick()
    }

    // Persistent may already be ready when this singleton loads, in which case
    // the ready signal never fires; the zero-interval timer catches that case.
    Timer {
        interval: 0
        running: true
        repeat: false
        onTriggered: root._restore()
    }

    function _restore() {
        if (!Persistent.ready)
            return;
        const storedInhibit = Persistent.states.idle.inhibit ?? false;
        const storedExpiry = Persistent.states.idle.expiresAt ?? 0;
        // A deadline that elapsed while the shell was down stays elapsed.
        if (storedInhibit && storedExpiry > 0 && storedExpiry <= Date.now()) {
            root._expire();
            return;
        }
        if (storedInhibit) {
            root.expiresAt = storedExpiry;
            root.sessionMinutes = Persistent.states.idle.durationMinutes ?? 0;
            root._warned = false;
            root.inhibit = true;
            root._tick();
            return;
        }
        if (!root.inhibit)
            Persistent.states.idle.expiresAt = 0;
    }

    Connections {
        target: Persistent
        function onReadyChanged() {
            root._restore();
        }
    }
}
