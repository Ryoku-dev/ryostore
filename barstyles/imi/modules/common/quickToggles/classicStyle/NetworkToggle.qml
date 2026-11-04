import "../../../../services"
import "../.."
import "../../widgets"
import "../../functions"
import ".."
import "../../../.."
import QtQuick
import Quickshell
import Quickshell.Io

QuickToggleButton {
    toggled: Network.wifiStatus !== "disabled"
    buttonIcon: Network.materialSymbol
    onClicked: Network.toggleWifi()
    altAction: () => {
        GlobalStates.openSettingsPage("network", "", Network.ethernet ? "Ethernet ports" : "Wi-Fi")
        GlobalStates.sidebarRightOpen = false
    }
    StyledToolTip {
        text: Translation.tr("%1 | Right-click to configure").arg(Network.networkName)
    }
}
