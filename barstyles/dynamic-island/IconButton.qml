import QtQuick

Item {
    id: root
    property string icon: ""
    property real size: 20
    property real pad: 8
    property real fill: 0
    property color color: Theme.fg
    property color bg: "transparent"
    property bool active: false
    readonly property bool hovered: ma.containsMouse
    signal clicked()

    implicitWidth: size + pad * 2
    implicitHeight: size + pad * 2
    opacity: enabled ? 1 : 0.3

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.active ? Theme.fill3 : ma.containsMouse ? Theme.fill2 : root.bg
        Behavior on color { ColorAnimation { duration: 150 } }
    }
    Icon {
        anchors.centerIn: parent
        text: root.icon
        size: root.size
        fill: root.fill
        color: root.color
        scale: ma.pressed ? 0.78 : 1
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 3 } }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
