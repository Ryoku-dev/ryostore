import "../../../.."
import "../.."
import "../../widgets"
import "../../../../services"
import Quickshell

QuickToggleButton {
    id: root
    buttonIcon: "draw"
    toggled: LiveDraw.trayOpen
    enabled: LiveDraw.enabled

    onClicked: {
        if (!LiveDraw.trayOpen)
            GlobalStates.sidebarRightOpen = false;
        LiveDraw.toggle();
    }

    StyledToolTip {
        text: Translation.tr("Draw on screen")
    }
}
