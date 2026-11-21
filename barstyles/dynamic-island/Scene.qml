pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import shell.services as Shell
import "."

// The bar style entry. The shell creates one scene per screen (modelData is
// that screen); each scene hosts its island overlay, and the shared services
// start once, on the primary screen.
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
        Platform.kind;
        Hub.armed;
        Notifs.count;
        Theme.accent;
    }

    // The desktop's surface bus: Super+Space and the settings key open the
    // island's own launcher and settings, the way the built-in full-desktop
    // styles take them over. Every other route stays with the shell.
    Connections {
        target: scene.primary ? Shell.ShellState : null

        function onSurfaceRequested(id, mon, context): void {
            const base = String(id).split("#")[0];
            const screen = String(mon || "");
            if (base === "launcher")
                Hub.openLauncher(screen);
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
