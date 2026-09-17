pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import Ryoku.Ui.Singletons

/**
 * Media transport keys.
 *
 * Handing a keypress to a running shell without a compositor keybind needs the
 * compositor's global-shortcuts protocol, which is the one thing here a
 * compositor either offers or does not (Wm.caps.globalShortcuts). This component
 * is the single place that speaks it, so the rest of the bar stays free of
 * compositor imports; where the capability is absent the keys simply never fire
 * and the surface is unaffected.
 */
Item {
    id: root

    visible: false
    enabled: Wm.caps.globalShortcuts === true

    signal toggleRequested()
    signal nextRequested()
    signal prevRequested()

    GlobalShortcut {
        appid: "quickshell"
        name: "mediaToggle"
        description: "Play or pause the active media player"
        onPressed: root.toggleRequested()
    }
    GlobalShortcut {
        appid: "quickshell"
        name: "mediaNext"
        description: "Skip to the next track"
        onPressed: root.nextRequested()
    }
    GlobalShortcut {
        appid: "quickshell"
        name: "mediaPrev"
        description: "Skip to the previous track"
        onPressed: root.prevRequested()
    }
}
