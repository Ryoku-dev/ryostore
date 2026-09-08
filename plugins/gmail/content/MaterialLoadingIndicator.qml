import QtQuick

Item {
    id: root
    property bool loading: true
    property real implicitSize: 32
    implicitWidth: implicitSize
    implicitHeight: implicitSize
    property color color: (typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colPrimary : "#ff5252"

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: 3
        border.color: Qt.rgba(root.color.r, root.color.g, root.color.b, 0.2)

        Rectangle {
            width: parent.width
            height: parent.height
            radius: width / 2
            color: "transparent"
            border.width: 3
            border.color: root.color
            clip: true
            Rectangle {
                width: parent.width
                height: parent.height / 2
                color: "transparent"
            }
        }

        RotationAnimation on rotation {
            running: root.loading
            duration: 900
            loops: Animation.Infinite
            from: 0
            to: 360
        }
    }
}
