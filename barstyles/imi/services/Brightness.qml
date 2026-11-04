pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import shell.services as HostDevices
import Ryoku.Ui.Singletons as RyokuUi
import "../modules/common"

// Brightness of the screens, backed by the host's Devices service: the
// internal panel through its backlight reader, external monitors through its
// ddcutil buses. One adapter object per Quickshell screen keeps the shape the
// ported OSD and sliders bind to.
Singleton {
    id: root

    // Emitted on any monitor brightness change; the OSD listens to decide
    // whether to show the brightness indicator.
    signal brightnessChanged()

    readonly property var ddcMonitors: HostDevices.Devices.ddcMonitors

    readonly property list<BrightnessMonitor> monitors: Quickshell.screens.map(screen => monitorComp.createObject(root, {
            screen
        }))

    // The output under the pointer, per the host window manager.
    readonly property var targetScreen: Quickshell.screens.find(screen => screen.name === String(RyokuUi.Wm.focusedOutput ?? "")) || Quickshell.screens[0] || null

    function getMonitorForScreen(screen: ShellScreen): var {
        return monitors.find(m => m.screen === screen);
    }

    function getTargetMonitor(): var {
        return root.getMonitorForScreen(root.targetScreen);
    }

    // Dimming below the backlight minimum by lowering gamma is opt-out. Kept
    // as a read for the surfaces that label their slider after it; this port
    // has no gamma backend to drive.
    readonly property bool gammaDimming: Config.options?.light?.gamma?.dimBelowMinimum ?? true

    function increaseBrightness(): void {
        root.brightnessChanged();
        const monitor = root.getTargetMonitor();
        if (monitor)
            monitor.setBrightness(monitor.brightness + 0.05);
    }

    function decreaseBrightness(): void {
        const monitor = root.getTargetMonitor();
        if (monitor)
            monitor.setBrightness(Math.max(monitor.floorBrightness, monitor.brightness - 0.05));
    }

    component BrightnessMonitor: QtObject {
        id: monitor

        required property ShellScreen screen
        property bool isDdc: false
        // The i2c bus number, for ddc monitors only.
        property string bus: ""
        // External panels cannot be read back without stalling the display
        // controller, so their level is tracked optimistically from writes.
        property real ddcBrightness: 0.5
        readonly property bool ready: monitor.isDdc || HostDevices.Devices.backlightAvailable
        // Backlight writes land on whole percent and never below raw 1.
        readonly property real floorBrightness: 0.01
        readonly property real brightness: monitor.isDdc
            ? monitor.ddcBrightness
            : (HostDevices.Devices.backlightAvailable ? HostDevices.Devices.backlightPct / 100 : 0)

        function setBrightness(value: real): void {
            root.brightnessChanged();
            value = Math.max(0, Math.min(1, value));
            if (monitor.isDdc) {
                monitor.ddcBrightness = value;
                HostDevices.Devices.setBrightness(monitor.bus, Math.round(value * 100));
            } else {
                HostDevices.Devices.setBacklight(Math.round(value * 100));
            }
        }
    }

    Component {
        id: monitorComp

        BrightnessMonitor {}
    }

    // Assign each screen its ddc bus (or none). A connector is claimed by the
    // first screen that matches, so two screens never share a bus.
    function rematchDdc(): void {
        const claimed = [];
        for (let i = 0; i < root.monitors.length; i++) {
            const monitor = root.monitors[i];
            const match = (HostDevices.Devices.ddcMonitors ?? []).find(ddc => ddc.label === monitor.screen.name && !claimed.includes(ddc.bus));
            monitor.isDdc = !!match;
            monitor.bus = match?.bus ?? "";
            if (match)
                claimed.push(match.bus);
        }
    }

    onMonitorsChanged: root.rematchDdc()

    Connections {
        target: HostDevices.Devices
        function onDdcMonitorsChanged() {
            root.rematchDdc();
        }
    }

    // The host only reads the backlight level while someone claims the probes;
    // the bar shows brightness without any panel open, so the claim is held
    // for the whole session.
    Component.onCompleted: {
        HostDevices.Devices.startProbes("imi-brightness");
        root.rematchDdc();
    }
}
