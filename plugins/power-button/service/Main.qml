pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// Session power actions. No UI here — the panel lists choices, then calls these.
Item {
    id: svc

    property var pluginApi

    function powerOff() {
        Quickshell.execDetached(["systemctl", "poweroff"]);
    }

    function reboot() {
        Quickshell.execDetached(["systemctl", "reboot"]);
    }

    function hibernate() {
        Quickshell.execDetached(["systemctl", "hibernate"]);
    }

    // Same path as QS Bar / Super+L: ryoku-shell → qylock.
    function lock() {
        Quickshell.execDetached(["ryoku-shell", "lock"]);
    }
}
