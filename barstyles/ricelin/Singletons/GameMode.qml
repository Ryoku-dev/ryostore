pragma Singleton

import QtQuick
import Quickshell

/**
 * Pill-local game/focus mode: quiet notifications, keep the session awake and
 * pause the visualizer, restoring the previous flags on exit. Hyprland window
 * effects remain owned by Ryoku Settings; no compositor configuration is changed.
 */
Singleton {
    id: root

    readonly property bool active: Flags.gameMode

    onActiveChanged: active ? root.enter() : root.leave()

    function enter() {
        Flags.gamePrevDnd = Flags.dnd;
        Flags.gamePrevViz = Flags.musicViz;
        Flags.gamePrevAwake = Flags.keepAwake;
        Flags.dnd = true;
        Flags.musicViz = false;
        Flags.keepAwake = true;
    }

    function leave() {
        Flags.dnd = Flags.gamePrevDnd;
        Flags.musicViz = Flags.gamePrevViz;
        Flags.keepAwake = Flags.gamePrevAwake;
    }
}
