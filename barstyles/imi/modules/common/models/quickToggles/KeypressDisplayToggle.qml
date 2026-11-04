import QtQuick
import Quickshell
import "../../../.."
import "../../../../services"
import "../.."
import "../../functions"
import "../../widgets"

QuickToggleModel {
    name: Translation.tr("Keystrokes")
    toggled: KeypressService.manualEnabled
    icon: toggled ? "keyboard" : "keyboard_off"

    mainAction: () => {
        KeypressService.toggleManual()
    }

    tooltipText: Translation.tr("Show the keys you press on screen")
}
