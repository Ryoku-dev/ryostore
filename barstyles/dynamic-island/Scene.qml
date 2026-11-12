pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import shell.services as Shell
import "."

// The Ryoku bar product entry: the shell instantiates this scene once per
// screen (modelData is that screen). Each scene hosts its island overlay;
// the shared singletons arm once on the primary.
Item {
    id: scene

    property var modelData: null
    width: 0
    height: 0

    readonly property bool primary: modelData !== null && Quickshell.screens.length > 0
        && modelData.name === Quickshell.screens[0].name

    IslandWindow {
        modelData: scene.modelData
    }

    Loader {
        active: scene.primary && Hub.settingsOpen
        sourceComponent: SettingsWindow {}
    }

    Component.onCompleted: if (scene.primary) {
        // touch the singletons so the services start immediately
        Hub.armed;
        Notifs.ready;
        Theme.dark;
    }

    // The desktop's surface bus routes the stock launcher/settings calls to
    // the island's own surfaces, like the shell's built-in full-desktop
    // styles do. Other routes belong to the shell and are left alone.
    Connections {
        target: scene.primary ? Shell.ShellState : null

        function onSurfaceRequested(id, mon, context): void {
            const base = String(id).split("#")[0];
            const screen = String(mon || "");
            if (base === "launcher")
                Hub.openLauncher(screen !== "" ? screen : "");
            else if (base === "settings")
                Hub.openSettings();
        }

        function onSurfaceClosed(id, mon): void {
            const base = String(id).split("#")[0];
            if (base === "launcher")
                Hub.closeLauncher();
            else if (base === "settings")
                Hub.settingsOpen = false;
        }
    }
}
