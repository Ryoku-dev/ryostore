import QtQuick
import Quickshell
import "../../../.."
import "../../../../services"
import "../.."
import "../../functions"
import "../../widgets"

QuickToggleModel {
    name: Translation.tr("System sounds")
    statusText: toggled ? Translation.tr("On") : Translation.tr("Muted")
    toggled: Config.options.sounds.enable
    icon: toggled ? "music_note" : "music_off"
    mainAction: () => {
        Config.options.sounds.enable = !Config.options.sounds.enable;
    }

    tooltipText: Translation.tr("System sounds | Mute or unmute shell event sounds")
}
