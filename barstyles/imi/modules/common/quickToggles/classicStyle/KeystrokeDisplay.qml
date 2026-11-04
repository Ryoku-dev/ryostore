import "../.."
import "../../widgets"
import "../../../../services"
import Quickshell

QuickToggleButton {
    id: root
    buttonIcon: root.toggled ? "keyboard" : "keyboard_off"
    toggled: KeypressService.manualEnabled

    onClicked: KeypressService.toggleManual()

    StyledToolTip {
        text: Translation.tr("Show keystrokes on screen")
    }
}
