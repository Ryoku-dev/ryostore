import QtQuick
import "../../../../services"
import "../.."

QuickToggleModel {
    id: root

    name: Translation.tr("Screen filter")

    toggled: ScreenShader.active
    statusText: ScreenShader.statusText
    icon: ScreenShader.iconFor(ScreenShader.activeName)
    tooltipText: !ScreenShader.hyprshadeAvailable && ScreenShader.shaders.length === 0 ? Translation.tr("Install hyprshade to get screen filters") : ScreenShader.active ? Translation.tr("Screen filter: %1 | Right-click to change").arg(ScreenShader.statusText) : Translation.tr("Screen filter is off | Right-click to pick one")

    available: ScreenShader.shaders.length > 0
    hasMenu: true

    mainAction: () => {
        ScreenShader.toggle();
    }

    Component.onCompleted: ScreenShader.refresh()
}
