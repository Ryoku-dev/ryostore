import "../../../../../services"
import QtQuick
import ".."
import "../../../../common/widgets"

OsdConnectValueIndicator {
    id: osdValues
    value: MprisController.activePlayer?.volume ?? 0
    icon: "music_note"
    name: Translation.tr("Music")
    shape: MaterialShape.Shape.Cookie4Sided

    onValueUpdateRequested: (newValue) => {
        if (MprisController.activePlayer) {
            MprisController.activePlayer.volume = newValue;
        }
    }
}
