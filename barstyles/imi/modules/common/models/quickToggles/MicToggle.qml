import QtQuick
import Quickshell
import "../../../.."
import "../../../../services"
import "../.."
import "../../functions"
import "../../widgets"

QuickToggleModel {
    name: Translation.tr("Audio input")
    statusText: toggled ? Audio.friendlyDeviceName(Audio.source) : Translation.tr("Muted")
    toggled: !Audio.source?.audio?.muted
    readonly property real volume: {
        const v = Audio.source?.audio?.volume;
        return typeof v === "number" && !isNaN(v) ? v : 0;
    }
    heroLevel: Math.min(1, volume)
    heroValue: String(Math.round(volume * 100))
    heroUnit: "%"
    icon: Audio.source?.audio?.muted ? "mic_off" : "mic"
    mainAction: () => {
        Audio.toggleMicMute()
    }
    hasMenu: true

    tooltipText: Translation.tr("Audio input | Right-click for volume mixer & device selector")
}
