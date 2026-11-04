import QtQuick
import "../../../../services"
import "../.."
import "../../functions"
import "../../widgets"

QuickToggleModel {
    name: Translation.tr("Anti-flashbang")
    tooltipText: Translation.tr("Anti-flashbang")
    icon: "flash_off"
    toggled: HyprlandAntiFlashbangShader.enabled

    mainAction: () => {
        HyprlandAntiFlashbangShader.toggle()
    }
    hasMenu: true
}
