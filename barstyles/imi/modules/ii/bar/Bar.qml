pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import shell.services as HostServices
import "../../.."
import "../../../modules/common"
import "../../../modules/common/widgets"
import "../../../services"
import "core"

// Bar entry point. Scene.qml instantiates one Bar per monitor; the
// window/autohide/exclusiveZone logic lives in core/BarWindow.qml.
// Visibility: the barstyle's own barOpen flag AND the host's per-monitor
// barRevealed (the Hub's bar toggle), so both controls agree.
Scope {
    id: bar

    required property ShellScreen screen
    // Panel-family override: a family may pin the bar to the top edge without
    // touching the user's stored bar position.
    property bool forceTop: false

    readonly property var state: bar.screen ? HostServices.ShellState.forScreen(bar.screen) : null
    readonly property bool hostRevealed: bar.state ? bar.state.barRevealed : true

    LazyLoader {
        id: barLoader

        // Keep an already-open bar mapped while the lock surface is entering.
        // Destroying the PanelWindow here makes Wayland recompute the layer
        // geometry in the same frame as the lock animation, which produces a
        // visible slide when wrapped frame is enabled.
        // Edit Mode holds the bar mapped and revealed.
        active: ((GlobalStates.barOpen && bar.hostRevealed) || GlobalStates.editMode) &&
                !GlobalStates.connectModeActive &&
                !GlobalStates.isMediaModeActiveForScreen(bar.screen ? bar.screen.name : "")
        component: BarWindow {
            screen: bar.screen
            forceTop: bar.forceTop
        }
    }

}
