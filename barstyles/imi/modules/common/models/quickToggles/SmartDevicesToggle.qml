import QtQuick
import Quickshell
import "../../../.."
import "../../../../services"
import "../.."
import "../../functions"
import "../../widgets"

QuickToggleModel {
    id: root

    name: Translation.tr("Smart Devices")
    statusText: SmartDevicesService.statusText

    toggled: SmartDevicesService.anyDeviceOn
    heroValue: SmartDevicesService.heroValue
    heroUnit: SmartDevicesService.heroUnit
    heroLevel: SmartDevicesService.heroLevel
    icon: SmartDevicesService.anyDeviceOn ? "home_iot_device" : "home"

    mainAction: () => {
        SmartDevicesService.toggleAll();
    }
    hasMenu: true

    Component.onCompleted: {
        SmartDevicesService.readCache();
    }

    tooltipText: Translation.tr("Smart Devices | Right-click to configure")
}
