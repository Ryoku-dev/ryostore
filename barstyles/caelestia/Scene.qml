pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import shell.services
import "modules" as CM
import "modules/drawers" as Drawers
import "modules/settings" as Settings
import "services" as CS

// The Caelestia style: the Caelestia shell's own drawers (frame, bar, dashboard, session,
// sidebar, OSD and popouts) running inside the Ryoku shell, in plain QML. They span every
// output themselves, so the scene hosts them once, from the first output. The config is
// ~/.config/ryoku/caelestia/shell.json, edited from the style's own settings panel.
Item {
    id: scene

    property var modelData: null
    width: 0
    height: 0

    readonly property bool primary: modelData !== null && Quickshell.screens.length > 0
        && modelData.name === Quickshell.screens[0].name

    // the bar's dock follows the Ryoku dock when this shell has the Caelestia dock design
    Binding {
        target: CS.HostState
        property: "dock"
        when: typeof Dock.design === "string"
        value: Dock.design === "caelestia" && Dock.cfg("enabled", false)
    }

    // The dashboard follows the Hub's Controls page on shells that have it (SidebarState);
    // on older ones it shows every section, as the Caelestia shell does on its own.
    readonly property var controls: typeof SidebarState === "undefined" ? null : SidebarState

    Binding {
        target: CS.HostState
        property: "controlsSections"
        when: scene.controls !== null
        value: {
            const shown = {};
            for (const s of scene.controls.controls.sections)
                shown[s.id] = s.visible;
            return shown;
        }
    }

    Binding {
        target: CS.HostState
        property: "controlsOrder"
        when: scene.controls !== null
        value: scene.controls.visibleSections.map(s => s.id)
    }

    Binding {
        target: CS.HostState
        property: "controlsHidden"
        when: scene.controls !== null
        value: scene.controls.controls.hidden
    }

    Connections {
        target: CS.HostState

        function onSession(action: string): void {
            SessionActions.run(action);
        }
    }

    Loader {
        active: scene.primary
        sourceComponent: Item {
            CM.ServiceLoader {}
            Drawers.Drawers {}
            CM.Shortcuts {}

            Settings.SettingsPanel {
                screen: scene.modelData
            }
        }
    }
}
