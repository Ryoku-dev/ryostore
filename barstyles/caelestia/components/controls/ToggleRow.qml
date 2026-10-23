import QtQuick
import QtQuick.Layouts
import "../../config"
import ".."
import "."
RowLayout {
    id: root

    required property string label
    property alias checked: toggle.checked
    property alias toggle: toggle

    Layout.fillWidth: true
    spacing: Tokens.spacing.medium

    StyledText {
        Layout.fillWidth: true
        text: root.label
    }

    StyledSwitch {
        id: toggle

        cLayer: 2
    }
}
