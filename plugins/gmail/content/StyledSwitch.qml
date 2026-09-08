import QtQuick
import QtQuick.Controls

Switch {
    id: root
    property real sizeScale: 0.8
    implicitHeight: 28
    implicitWidth: 46

    property color activeColor: (typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colPrimary : "#ff5252"
    property color inactiveColor: (typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colSurfaceContainerHighest : "#333339"

    indicator: Rectangle {
        implicitWidth: 46
        implicitHeight: 26
        x: root.leftPadding
        y: parent.height / 2 - height / 2
        radius: 13
        color: root.checked ? root.activeColor : root.inactiveColor
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        Behavior on color { ColorAnimation { duration: 150 } }

        Rectangle {
            x: root.checked ? parent.width - width - 3 : 3
            y: 3
            width: 20
            height: 20
            radius: 10
            color: "#ffffff"
            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }
    }
}
