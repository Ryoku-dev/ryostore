pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "AlertPolicy.js" as Policy

// One monitor per QML engine, even with several physical displays.
Singleton {
    id: svc
    property int clients: 0
    property var apis: []
    readonly property var activeApi: apis.length > 0 ? apis[apis.length - 1] : null
    function attach(api) { apis = apis.concat([api]); clients++; }
    function detach(api) {
        var next = apis.slice();
        var index = next.indexOf(api);
        if (index >= 0) next.splice(index, 1);
        apis = next;
        clients = Math.max(0, clients - 1);
    }
    function saveSetting(key, value) {
        if (activeApi) activeApi.saveSetting(key, value);
    }
    property var settings: ({})
    readonly property bool enabled: clients > 0 && (settings.enabled ?? true)
    readonly property int lowThreshold: Math.max(5, Math.min(50, Number(settings.lowThreshold ?? 25)))
    readonly property int criticalThreshold: Math.max(1, Math.min(lowThreshold - 1, Number(settings.criticalThreshold ?? 10)))
    readonly property var battery: {
        var devices = UPower.devices ? UPower.devices.values : [];
        for (var i = 0; i < devices.length; i++) {
            if (devices[i].isLaptopBattery && devices[i].isPresent) return devices[i];
        }
        return null;
    }
    readonly property bool present: battery !== null && battery.isPresent
    readonly property bool ready: present && battery.ready
    readonly property bool onAc: !UPower.onBattery
    readonly property bool discharging: present && battery.state === UPowerDeviceState.Discharging
    readonly property real percent: ready ? battery.percentage * 100 : NaN
    readonly property int percentage: Number.isFinite(percent) ? Math.round(percent) : -1
    readonly property string status: !present ? qsTr("No laptop battery")
        : !ready ? qsTr("Waiting for battery") : onAc ? qsTr("On AC power")
        : discharging ? qsTr("On battery") : qsTr("Battery idle")
    property string lastResult: ""
    property var alertState: Policy.initialState()
    property var pendingState: null
    property int session: 0
    property int pendingSession: 0
    property bool testing: false

    // Public diagnostics use the same live instance and notification path as
    // the panel; no simulated battery or bypass of the alert policy.
    IpcHandler {
        target: svc.clients > 0 ? "battery-alerts" : ""
        function test(): void { svc.testNotification(); }
        function status(): string {
            return JSON.stringify({ clients: svc.clients, percent: svc.percentage,
                enabled: svc.enabled, onAc: svc.onAc, ready: svc.ready,
                warning: svc.lowThreshold, critical: svc.criticalThreshold,
                lastResult: svc.lastResult });
        }
    }

    function evaluate() {
        if (onAc) { alertState = Policy.initialState(); return; }
        if (notifier.running) return;
        var result = Policy.evaluate(alertState,
            { present: present, ready: ready, onAc: onAc, discharging: discharging, percent: percent },
            { enabled: enabled, low: lowThreshold, critical: criticalThreshold });
        if (!result.level) return;
        pendingState = result.state;
        pendingSession = session;
        testing = false;
        send(result.level === "critical" ? qsTr("Battery critical") : qsTr("Battery low"),
            qsTr("Battery at %1%. Connect your charger.").arg(percentage), result.level === "critical");
    }
    function send(title, body, critical) {
        notifier.command = ["notify-send", "--app-name=Battery Alerts", "--icon=battery-caution-symbolic",
            critical ? "--urgency=critical" : "--urgency=normal", title, body];
        lastResult = qsTr("Sending notification…");
        notifier.running = true;
    }
    function testNotification() {
        if (notifier.running) return;
        testing = true;
        pendingState = null;
        send(qsTr("Battery Alerts test"),
            qsTr("Low-battery alerts are ready. Warning: %1%. Critical: %2%.").arg(lowThreshold).arg(criticalThreshold), false);
    }
    onOnAcChanged: {
        session++;
        if (onAc) alertState = Policy.initialState();
        soon.restart();
    }
    onPercentChanged: soon.restart()
    onReadyChanged: soon.restart()
    onDischargingChanged: soon.restart()
    onSettingsChanged: soon.restart()
    onEnabledChanged: soon.restart()
    Component.onCompleted: soon.restart()
    Timer { id: soon; interval: 300; onTriggered: svc.evaluate() }
    // Alerts stay alive while their panel is closed or bar hidden.
    Timer {
        interval: 30000
        running: svc.enabled && svc.present && !svc.onAc
        repeat: true
        onTriggered: svc.evaluate()
    }
    Process {
        id: notifier
        onExited: (code) => {
            if (code === 0) {
                if (!svc.testing && svc.pendingState && svc.pendingSession === svc.session && !svc.onAc)
                    svc.alertState = svc.pendingState;
                svc.lastResult = qsTr("Notification sent.");
            } else {
                svc.lastResult = qsTr("Notification failed. Check notify-send and the notification service.");
            }
            svc.pendingState = null;
            // The periodic timer retries failures; avoid an immediate retry loop.
            if (code === 0) soon.restart();
        }
    }
}
