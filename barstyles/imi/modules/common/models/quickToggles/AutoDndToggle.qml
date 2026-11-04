import QtQuick
import Quickshell
import "../../../.."
import "../../../../services"
import "../.."
import "../../functions"
import "../../widgets"

QuickToggleModel {
    name: Translation.tr("Auto DND")
    statusText: toggled ? Translation.tr("Fullscreen") : Translation.tr("Off")
    toggled: Config.options.notifications.autoDndFullscreen
    icon: toggled ? "fullscreen" : "fullscreen_exit"

    mainAction: () => {
        Config.options.notifications.autoDndFullscreen = !Config.options.notifications.autoDndFullscreen;
    }

    tooltipText: Translation.tr("Auto Do-Not-Disturb when focused app is fullscreen")
}
