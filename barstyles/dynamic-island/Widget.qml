import QtQuick

// iOS widget card.
Rectangle {
    id: root
    default property alias content: inner.data
    property real pad: 14
    property bool hoverable: false
    signal clicked()

    radius: 22
    color: hoverable && ma.containsMouse ? Theme.fill2 : Theme.fill
    border.width: 1
    border.color: Theme.glass ? Qt.rgba(1, 1, 1, Theme.dark ? 0.06 : 0.35) : "transparent"
    scale: hoverable && ma.pressed ? 0.97 : 1
    Behavior on color { ColorAnimation { duration: 160 } }
    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2 } }

    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: root.hoverable
        hoverEnabled: true
        cursorShape: root.hoverable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
    Item {
        id: inner
        anchors.fill: parent
        anchors.margins: root.pad
    }
}
