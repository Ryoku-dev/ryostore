import QtQuick
import QtQuick.Controls

ToolTip {
    id: root
    verticalPadding: 6
    horizontalPadding: 10
    contentItem: Text {
        text: root.text
        font.family: (typeof Appearance !== "undefined" && Appearance && Appearance.font && Appearance.font.family) ? Appearance.font.family.main : "Space Grotesk"
        font.pixelSize: 12
        color: "#ffffff"
    }
    background: Rectangle {
        color: Qt.rgba(0.1, 0.1, 0.12, 0.95)
        radius: 6
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.15)
    }
}
