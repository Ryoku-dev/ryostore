pragma Singleton

import QtQuick
import Quickshell

// Ryoku has no Unity LauncherEntry D-Bus watcher; dock badges stay absent.
Singleton {
    readonly property int revision: 0

    signal changed()

    function forApp(desktopId: string): var {
        return null;
    }
}
