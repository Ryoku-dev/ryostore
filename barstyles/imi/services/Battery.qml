pragma Singleton
pragma ComponentBehavior: Bound

import "."
import "../modules/common"
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import shell.services as HostServices

Singleton {
    id: root

    // The physical battery the host picked: the synthetic display device omits
    // capacity and health, so the adapter reads through shell.services Battery.
    readonly property var device: HostServices.Battery.batDev

    // A battery that has not reported yet lies: 0 %, state Unknown. Anything that acts on the level
    // (automatic suspend) waits for this instead of trusting cold-start values.
    readonly property bool deviceReady: (device?.ready ?? false) && (device?.isPresent ?? false)

    readonly property bool available: HostServices.Battery.present
    readonly property var chargeState: HostServices.Battery.state
    readonly property bool isCharging: HostServices.Battery.charging
    readonly property bool isFullyCharged: HostServices.Battery.full

    // The AC line, not the battery state, is what says whether a charger is attached: a pack held at
    // its charge limit reports Discharging or PendingCharge at ~0 W with the charger plugged in.
    readonly property bool onAc: HostServices.Battery.onAc
    readonly property bool isPluggedIn: onAc || isCharging || isFullyCharged
        || chargeState === UPowerDeviceState.PendingCharge

    readonly property real percentage: HostServices.Battery.frac
    readonly property int percent: HostServices.Battery.pct

    // W, signed away from the cell in the host read; the UI takes magnitudes.
    readonly property real energyRate: Math.abs(HostServices.Battery.rateW)
    readonly property real timeToEmpty: device?.timeToEmpty ?? 0
    readonly property real timeToFull: device?.timeToFull ?? 0

    // How far the level must recover before the suspend request re-arms
    readonly property int rearmMargin: 3

    readonly property bool isLow: available && (percentage <= Config.options.battery.low / 100)
    readonly property bool isCritical: available && (percentage <= Config.options.battery.critical / 100)
    readonly property bool isFull: available && (percentage >= Config.options.battery.full / 100)

    readonly property bool isLowAndUnplugged: isLow && !isPluggedIn
    readonly property bool isCriticalAndUnplugged: isCritical && !isPluggedIn

    // Plugged in and still losing charge: the supply cannot keep up with what the machine is drawing.
    readonly property bool drainingOnAc: available && onAc && !isCharging && !chargeLimitReached
        && chargeState === UPowerDeviceState.Discharging && energyRate > 0.5

    // As charged as this pack is going to get right now, whether that is 100 % or a firmware limit.
    readonly property bool atChargeCeiling: available
        && (chargeLimitReached || (isPluggedIn && (isFullyCharged || percent >= 100)))

    // Full on AC: UPower says fully charged, or the pack reads 100 %. The full threshold is left out on
    // purpose: its default of 101 means "never full", which is the case the Battery settings option is for.
    readonly property bool fullOnAc: available && isPluggedIn && (isFullyCharged || percent >= 100)
    // Opt-in: at full, the indicators drop the charging look (bolt, green fill) for the default one.
    readonly property bool showDefaultWhenFull: Config.options.battery.defaultStateWhenFull && fullOnAc

    readonly property real health: HostServices.Battery.healthSupported ? HostServices.Battery.health : 0

    property string batteryNativePath: device?.nativePath ?? ""

    property int cycles: -1

    // ── Charge limit ────────────────────────────────────────────────────────────────────────────
    // Standard kernel ABI first, then known vendor-specific locations (TLP-style). UPower exposes
    // charge thresholds of its own but caches them past the point of being wrong, so sysfs only.
    readonly property var chargeLimitCandidates: {
        const paths = [];
        if (!available) return paths;
        if (batteryNativePath) {
            const base = `/sys/class/power_supply/${batteryNativePath}`;
            paths.push({ path: `${base}/charge_control_end_threshold`, type: "plain",
                start: `${base}/charge_control_start_threshold` });
            paths.push({ path: `${base}/charge_stop_threshold`, type: "plain",
                start: `${base}/charge_start_threshold` });
            paths.push({ path: `/sys/devices/platform/smapi/${batteryNativePath}/stop_charge_thresh`,
                type: "plain",
                start: `/sys/devices/platform/smapi/${batteryNativePath}/start_charge_thresh` });
        }
        paths.push({ path: "/sys/devices/platform/huawei-wmi/charge_control_thresholds", type: "last",
            startInline: true });
        paths.push({ path: "/sys/devices/platform/lg-laptop/battery_care_limit", type: "plain" });
        paths.push({ path: "/sys/devices/platform/sony-laptop/battery_care_limiter", type: "plain" });
        paths.push({ path: "/sys/devices/platform/samsung/battery_life_extender", type: "bool80" });
        return paths;
    }
    property int chargeLimitCandidateIndex: 0
    property bool chargeLimitResolved: false // a candidate answered; stop walking the list on refresh
    property int chargeLimit: 100 // 0 or 100 = no limit
    property int chargeLimitStart: -1 // firmware recharge threshold, -1 when it exposes none
    property bool chargeLimitStartMissing: false // stop re-reading a node that is not there
    readonly property bool chargeLimitActive: chargeLimitIsActive()

    // Imperative code reads these instead of the properties above: a handler can run before the
    // bindings that derive from the value it was woken by, and a stale read here silently unlatches.
    function chargeLimitIsActive(): bool {
        return root.available && root.chargeLimit > 0 && root.chargeLimit < 100;
    }
    function chargeLimitIsHeld(): bool {
        return root.chargeLimitIsActive() && root.chargeLimitLatched;
    }

    // Firmware does not top the pack back up the moment it dips below the limit; it waits for a
    // recharge threshold a few points lower. Assume the usual 5-point band when none is exposed.
    function chargeLimitFloor(): int {
        if (root.chargeLimitStart > 0 && root.chargeLimitStart < root.chargeLimit)
            return root.chargeLimitStart;
        return Math.max(0, root.chargeLimit - 6);
    }
    readonly property int chargeLimitHoldFloor: chargeLimitFloor()

    // Latched rather than derived: between the limit and the recharge threshold the pack sits on AC
    // losing a few points with no charge current, and a plain comparison flips the whole shell back
    // to "discharging" for hours at a time.
    property bool chargeLimitLatched: false
    readonly property bool chargeLimitReached: chargeLimitActive && chargeLimitLatched

    // Pure decision, so the band can be reasoned about (and tested) without a machine in the right
    // state: given where the latch is now, say where it should be.
    function chargeLimitHoldNext(latched, limit, floor, level, charging, holdable): bool {
        if (!holdable) return false;
        if (!charging && level >= limit - 1) return true;
        if (!latched) return false;
        if (charging && level < limit - 1) return false;
        return level >= floor - 1;
    }

    function refreshChargeLimitHold() {
        const holdable = root.available && root.deviceReady && root.chargeLimitIsActive() && root.onAc;
        root.chargeLimitLatched = root.chargeLimitHoldNext(root.chargeLimitLatched, root.chargeLimit,
            root.chargeLimitFloor(), root.percent, root.isCharging, holdable);
    }

    // Time until the effective full point (charge limit if active, otherwise UPower's estimate)
    readonly property real timeToFullEffective: {
        if (!chargeLimitActive) return timeToFull;
        if (chargeLimitReached || percent >= chargeLimit) return 0;
        const dev = root.device;
        if (!dev) return 0;
        const rate = Math.abs(dev.changeRate);
        if (dev.energyCapacity > 0 && rate > 0.01) {
            const remaining = dev.energyCapacity * (chargeLimit / 100) - dev.energy;
            return Math.max(0, remaining / rate * 3600);
        }
        if (percentage < 1 && timeToFull > 0) {
            return timeToFull * Math.max(0, chargeLimit / 100 - percentage) / (1 - percentage);
        }
        return 0;
    }

    function parseChargeLimit(content, type): int {
        const trimmed = String(content).trim();
        if (type === "bool80") return trimmed === "1" ? 80 : 100;
        const parts = trimmed.split(/\s+/);
        const val = parseInt(type === "last" ? parts[parts.length - 1] : parts[0], 10);
        // 0 means "off" on several drivers, and anything out of range is not a limit we can trust
        if (isNaN(val) || val <= 0 || val > 100) return 100;
        return val;
    }

    function parseChargeStart(content): int {
        const val = parseInt(String(content).trim().split(/\s+/)[0], 10);
        if (isNaN(val) || val <= 0 || val >= 100) return -1;
        return val;
    }

    // Refresh only what is known to exist. A machine with no threshold node at all would otherwise
    // walk the whole candidate list on every heartbeat and log a failed read for each one.
    function reloadChargeLimit() {
        if (!root.chargeLimitResolved) return;
        chargeLimitFile.reload();
        if (!root.chargeLimitStartMissing) chargeLimitStartFile.reload();
    }

    function rediscoverChargeLimit() {
        root.chargeLimitResolved = false;
        root.chargeLimitStartMissing = false;
        root.chargeLimitCandidateIndex = 0;
        chargeLimitFile.reload();
        chargeLimitStartFile.reload();
    }

    FileView {
        id: chargeLimitFile
        path: root.chargeLimitCandidates[root.chargeLimitCandidateIndex]?.path ?? ""
        printErrors: false // walking the candidate list: a missing node is the expected answer
        onLoaded: {
            const candidate = root.chargeLimitCandidates[root.chargeLimitCandidateIndex];
            if (!candidate) return;
            root.chargeLimitResolved = true;
            root.chargeLimit = root.parseChargeLimit(text(), candidate.type);
            if (candidate.startInline) {
                root.chargeLimitStart = root.parseChargeStart(text());
            } else if (!candidate.start) {
                root.chargeLimitStart = -1;
            }
            root.refreshChargeLimitHold();
        }
        onLoadFailed: {
            if (root.chargeLimitCandidateIndex < root.chargeLimitCandidates.length - 1) {
                root.chargeLimitStartMissing = false;
                root.chargeLimitCandidateIndex++;
                return;
            }
            root.chargeLimit = 100;
            root.chargeLimitStart = -1;
            root.refreshChargeLimitHold();
        }
    }

    FileView {
        id: chargeLimitStartFile
        path: root.chargeLimitStartMissing ? ""
            : (root.chargeLimitCandidates[root.chargeLimitCandidateIndex]?.start ?? "")
        printErrors: false // most firmware exposes no start threshold; onLoadFailed records it
        onLoaded: {
            root.chargeLimitStartMissing = false;
            root.chargeLimitStart = root.parseChargeStart(text());
        }
        onLoadFailed: {
            // The huawei node carries both thresholds in the limit file; don't undo what it parsed
            if (root.chargeLimitCandidates[root.chargeLimitCandidateIndex]?.startInline) return;
            root.chargeLimitStartMissing = true;
            root.chargeLimitStart = -1;
        }
    }

    FileView {
        id: cycleCountFile
        path: root.batteryNativePath ? `/sys/class/power_supply/${root.batteryNativePath}/cycle_count` : ""
        printErrors: false
        onLoaded: {
            const val = parseInt(text().trim(), 10);
            root.cycles = isNaN(val) ? -1 : val;
        }
        onLoadFailed: {
            root.cycles = -1;
        }
    }

    // ── Charged notification ─────────────────────────────────────────────────
    // Low and critical alerts are the host BatteryAlerts service's business;
    // the "charged" announcement stays here because the host has no equivalent.
    property bool chargedArmed: true

    function evaluateChargedNotification() {
        const opts = Config.options.battery;
        if (root.isPluggedIn && root.chargedArmed && (opts.notifyCharged ?? true)) {
            // A firmware limit holding the pack is the finished state on this machine: saying "unplug"
            // there would be advice against the whole point of the limit.
            if (root.chargeLimitIsHeld()) {
                root.chargedArmed = false;
                root.announceCharged(Translation.tr("Charged to %1%").arg(root.chargeLimit),
                    Translation.tr("The charge limit is holding it here — the charger can stay in."));
                return;
            }
            if (root.isFullyCharged || root.percent >= 100) {
                root.chargedArmed = false;
                root.announceCharged(Translation.tr("Battery full"),
                    Translation.tr("You can unplug the charger."));
                return;
            }
            if (opts.full <= 100 && root.percent >= opts.full) {
                root.chargedArmed = false;
                root.announceCharged(Translation.tr("Battery at %1%").arg(root.percent),
                    Translation.tr("Consider unplugging the charger."));
            }
        }
        if (!root.isPluggedIn)
            root.chargedArmed = true;
    }

    function announceCharged(title, body) {
        root.publish(title, body, false, []);
    }

    // Shell-owned notification with optional QML-side actions; falls back to
    // notify-send while do-not-disturb would swallow the internal one.
    function publish(title, body, critical, actions) {
        const id = Notifications.publishInternalNotification({
            appName: "Battery",
            appIcon: "battery",
            summary: title,
            body: body,
            urgency: critical ? "critical" : "normal",
            actions: actions ?? []
        });
        if (id !== null)
            return id;
        const args = ["notify-send", title, body, "-a", "Shell", "-u", critical ? "critical" : "normal"];
        Quickshell.execDetached(args);
        return null;
    }

    // ── Automatic suspend ───────────────────────────────────────────────────────────────────────
    readonly property int suspendWarningSeconds: Math.max(0,
        Config.options.battery.suspendWarningSeconds ?? 30)
    property bool suspendPending: false
    property int suspendCountdown: 0
    // One automatic suspend per discharge; without this the machine wakes at 3 % and suspends again,
    // and a cancelled countdown restarts the moment the next reading arrives.
    property bool suspendInhibitedUntilRecovery: false
    property int suspendWarningId: 0

    function evaluateSuspend() {
        if (!root.available || !root.deviceReady) {
            root.cancelAutomaticSuspend(false);
            return;
        }
        const opts = Config.options.battery;
        const level = root.percent;
        const unplugged = !root.isPluggedIn;

        if (!unplugged || level >= opts.suspend + root.rearmMargin)
            root.suspendInhibitedUntilRecovery = false;

        const shouldSuspend = opts.automaticSuspend && unplugged && level <= opts.suspend
            && !root.suspendInhibitedUntilRecovery;
        if (!shouldSuspend) {
            root.cancelAutomaticSuspend(false);
            return;
        }
        if (root.suspendPending || suspendConfirmTimer.running) return;
        // One reading is not enough: a single bad sample must not put the machine to sleep
        suspendConfirmTimer.restart();
    }

    Timer {
        id: suspendConfirmTimer
        interval: 8000
        onTriggered: {
            if (!root.available || !root.deviceReady) return;
            if (!Config.options.battery.automaticSuspend || root.isPluggedIn) return;
            if (root.suspendInhibitedUntilRecovery) return;
            if (root.percent > Config.options.battery.suspend) return;
            root.beginAutomaticSuspend();
        }
    }

    function beginAutomaticSuspend() {
        if (root.suspendPending) return;
        if (root.suspendWarningSeconds <= 0) {
            root.suspendNow();
            return;
        }
        root.suspendPending = true;
        root.suspendCountdown = root.suspendWarningSeconds;
        suspendCountdownTimer.restart();
        root.suspendWarningId = root.publish(
            Translation.tr("Battery critically low"),
            Translation.tr("Suspending in %1 s. Plug in to cancel.").arg(root.suspendWarningSeconds),
            true,
            [
                { "identifier": "__qs_battery_suspend_now", "text": Translation.tr("Suspend now") },
                { "identifier": "__qs_battery_suspend_cancel", "text": Translation.tr("Stay awake") }
            ]) ?? 0;
    }

    Timer {
        id: suspendCountdownTimer
        interval: 1000
        repeat: true
        onTriggered: {
            if (root.isPluggedIn || !Config.options.battery.automaticSuspend) {
                root.cancelAutomaticSuspend(false);
                return;
            }
            root.suspendCountdown--;
            if (root.suspendCountdown <= 0) root.suspendNow();
        }
    }

    function cancelAutomaticSuspend(byUser) {
        suspendConfirmTimer.stop();
        if (!root.suspendPending) return;
        suspendCountdownTimer.stop();
        root.suspendPending = false;
        root.suspendCountdown = 0;
        root.dismissSuspendWarning();
        // A deliberate cancel has to survive the next reading, which still sees a flat battery
        if (byUser) root.suspendInhibitedUntilRecovery = true;
    }

    function suspendNow() {
        suspendConfirmTimer.stop();
        suspendCountdownTimer.stop();
        root.suspendPending = false;
        root.suspendCountdown = 0;
        root.suspendInhibitedUntilRecovery = true;
        root.dismissSuspendWarning();
        HostServices.SessionActions.run("suspend");
    }

    function dismissSuspendWarning() {
        if (root.suspendWarningId === 0) return;
        Notifications.discardNotification(root.suspendWarningId);
        root.suspendWarningId = 0;
    }

    // ── Wiring ──────────────────────────────────────────────────────────────────────────────────
    onBatteryNativePathChanged: {
        cycleCountFile.reload();
        root.rediscoverChargeLimit();
    }

    onChargeStateChanged: {
        cycleCountFile.reload();
        root.reloadChargeLimit();
        root.refreshChargeLimitHold();
        root.evaluateSuspend();
        root.evaluateChargedNotification();
    }

    onPercentChanged: {
        root.refreshChargeLimitHold();
        root.evaluateSuspend();
        root.evaluateChargedNotification();
    }

    onDeviceReadyChanged: {
        root.refreshChargeLimitHold();
        root.evaluateSuspend();
    }

    onAvailableChanged: {
        root.evaluateSuspend();
        root.evaluateChargedNotification();
    }

    onOnAcChanged: root.refreshChargeLimitHold()

    onIsPluggedInChanged: {
        if (!root.available) return;
        root.refreshChargeLimitHold();
        root.evaluateSuspend();
        root.evaluateChargedNotification();
    }

    // Sysfs has no usable change notification and UPower stops emitting when nothing moves, so the
    // limit (which tlp, vendor tools and firmware menus rewrite behind our back) is re-read on a
    // heartbeat, which also picks up threshold edits made in settings.
    Timer {
        interval: 30000
        running: root.available
        repeat: true
        onTriggered: {
            root.reloadChargeLimit();
            root.refreshChargeLimitHold();
            root.evaluateSuspend();
            root.evaluateChargedNotification();
        }
    }
}
