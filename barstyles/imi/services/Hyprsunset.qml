pragma Singleton

import QtQuick
import Quickshell
import shell.services as HostServices

// Night light for the bar's warmth controls, over the Ryoku daemon's nightlight
// topic. The daemon owns the state and any schedule; this file only translates
// the old hyprsunset-shaped API onto it. Per-monitor gamma has no
// compositor counterpart here, so "gamma" is warmth: 100 is night light off,
// lower values map onto a Kelvin temperature (same rule the Tansu barstyle uses).
Singleton {
    signal gammaChangeAttempt()
    id: root

    readonly property real gammaLowerLimit: 25

    readonly property bool temperatureActive: HostServices.Nightlight.on
    readonly property int colorTemperature: HostServices.Nightlight.temperature

    readonly property int gamma: !root.temperatureActive ? 100
        : Math.max(root.gammaLowerLimit, Math.min(100, Math.round((root.colorTemperature - 2500) / 40)))

    // The daemon follows its own sun/clock schedule; there is nothing to schedule here.
    readonly property bool automatic: HostServices.Nightlight.schedule !== "off"

    // Kept writable: mode actions clear a manual override before re-evaluating.
    property var manualActive: undefined
    property real manualActiveAt: 0

    function enableTemperature() {
        HostServices.Nightlight.setEnabled(true, root.colorTemperature);
    }

    function disableTemperature() {
        HostServices.Nightlight.setEnabled(false);
    }

    // The daemon pushes state by itself; these exist so callers keep working.
    function fetchState() {}
    function ensureState() {}
    function persistState() {}

    function toggleTemperature(active = undefined) {
        if (active !== undefined)
            HostServices.Nightlight.setEnabled(active === true);
        else
            HostServices.Nightlight.toggle();
    }

    function setGamma(gamma) {
        const value = Math.max(root.gammaLowerLimit, Math.min(100, Math.round(Number(gamma) || 0)));
        if (value >= 100) {
            HostServices.Nightlight.setEnabled(false);
            return;
        }
        HostServices.Nightlight.setEnabled(true, 2500 + value * 40);
    }
}
