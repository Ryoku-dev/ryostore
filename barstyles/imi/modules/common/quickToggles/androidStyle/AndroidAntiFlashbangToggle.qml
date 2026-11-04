import "../../models/quickToggles"
import "../.."
import "../../widgets"
import "../../../../services"
import QtQuick
import Quickshell

AndroidQuickToggleButton {
    id: root

    toggleModel: AntiFlashbangToggle {}
}

