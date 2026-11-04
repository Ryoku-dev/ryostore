import "../../../.."
import "../../../../services"
import "../.."
import "../../widgets"
import "../../functions"
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io

QuickToggleButton {
    id: root
    available: BluetoothStatus.available
    toggled: BluetoothStatus.enabled
    buttonIcon: BluetoothStatus.connected ? "bluetooth_connected" : BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled"
    onClicked: {
        BluetoothStatus.toggle()
    }
    altAction: () => {
        GlobalStates.openSettingsPage("network", "", "Bluetooth")
        GlobalStates.sidebarRightOpen = false
    }
    StyledToolTip {
        text: Translation.tr("%1 | Right-click to configure").arg(
            (BluetoothStatus.firstActiveDevice?.name ?? Translation.tr("Bluetooth"))
            + (BluetoothStatus.activeDeviceCount > 1 ? ` +${BluetoothStatus.activeDeviceCount - 1}` : "")
            )
    }
}
