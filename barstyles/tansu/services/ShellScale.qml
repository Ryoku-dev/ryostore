pragma Singleton
import QtQuick
import Quickshell
import "."

// Tansu's own size per monitor, plus the bar-only multiplier. The compositor
// already applies the display scale to logical pixels, so the device pixel
// ratio is never multiplied in here.
Singleton {
    id: root

    readonly property real minScale: 0.5
    readonly property real maxScale: 3.0

    readonly property var monitors: SettingsService.get("shell.scales", ({}))

    function clampScale(v) {
        const n = Number(v)
        if (!isFinite(n) || n <= 0)
            return 1
        return Math.max(root.minScale, Math.min(root.maxScale, n))
    }

    function userFor(name) {
        const v = name ? Number(root.monitors[name]) : NaN
        return isFinite(v) && v > 0 ? root.clampScale(v) : 1
    }

    function forScreen(screen) {
        return root.userFor(screen ? screen.name : "")
    }

    function effectiveFor(name) {
        return root.userFor(name)
    }

    function setScale(monitor, value) {
        if (!monitor)
            return
        const next = Object.assign({}, root.monitors)
        next[monitor] = Math.round(root.clampScale(value) * 100) / 100
        SettingsService.set("shell.scales", next)
    }

    function resetScale(monitor) {
        if (!monitor)
            return
        const next = Object.assign({}, root.monitors)
        delete next[monitor]
        SettingsService.set("shell.scales", next)
    }

    // Bar -> Size -> "Bar size": a multiplier on the bar strip alone (its pills
    // and the space it reserves), for displays where the phone and the popups
    // are the right size but the bar is not. The phone keeps Tansu size.
    readonly property real minBarScale: 0.7
    readonly property real maxBarScale: 1.3

    function clampBarScale(v) {
        const n = Number(v)
        if (!isFinite(n) || n <= 0)
            return 1
        return Math.max(root.minBarScale, Math.min(root.maxBarScale, n))
    }

    readonly property real barScale: root.clampBarScale(SettingsService.get("bar.scale", 1))

    function setBarScale(value) {
        SettingsService.set("bar.scale", Math.round(root.clampBarScale(value) * 100) / 100)
    }
}
