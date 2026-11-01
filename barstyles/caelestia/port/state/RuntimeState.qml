pragma Singleton

import QtQuick
import Quickshell
import shell.services

Singleton {
    id: root

    property bool syncing: false
    property bool gameMode: Flags.gameMode
    property bool inhibitIdle: Flags.keepAwake
    readonly property real inhibitingIdleSince: Flags.keepAwakeSince

    onGameModeChanged: {
        if (!syncing && Flags.gameMode !== gameMode)
            Flags.gameMode = gameMode;
    }
    onInhibitIdleChanged: {
        if (!syncing && Flags.keepAwake !== inhibitIdle)
            Flags.keepAwake = inhibitIdle;
    }

    Connections {
        target: Flags
        function onGameModeChanged(): void {
            root.syncing = true;
            root.gameMode = Flags.gameMode;
            root.syncing = false;
        }
        function onKeepAwakeChanged(): void {
            root.syncing = true;
            root.inhibitIdle = Flags.keepAwake;
            root.syncing = false;
        }
    }
}
