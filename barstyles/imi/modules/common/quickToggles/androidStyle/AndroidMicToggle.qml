import "../../../.."
import "../.."
import "../../models/quickToggles"
import "../../widgets"
import "../../../../services"
import QtQuick
import Quickshell

AndroidQuickToggleButton {
    id: root

    toggleModel: MicToggle {}

    // Same expressive tall face as the output tile, in the tertiary family.
    wide2x2OverrideComponent: tallFace
    tall1x2OverrideComponent: tallFace

    Component {
        id: tallFace
        AudioEndpointPanel {
            anchors.fill: parent
            anchors.margins: root.scaled(12)
            tile: root
            isInput: true
        }
    }
}
