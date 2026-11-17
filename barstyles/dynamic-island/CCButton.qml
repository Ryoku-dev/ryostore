import QtQuick

// Control Center round toggle with label underneath.
Item {
    id: root
    property string icon: ""
    property string label: ""
    property string sub: ""
    property bool active: false
    property color activeColor: Theme.accent
    property real size: 52
    signal clicked()

    implicitWidth: Math.max(size, 76)
    implicitHeight: size + (label !== "" ? 34 : 0)

    Rectangle {
        id: circle
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.size; height: root.size; radius: root.size / 2
        color: root.active ? root.activeColor : ma.containsMouse ? Theme.fill3 : Theme.fill2
        scale: ma.pressed ? 0.9 : ma.containsMouse ? 1.04 : 1
        Behavior on color { ColorAnimation { duration: 220 } }
        Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 2.6 } }
        Icon {
            anchors.centerIn: parent
            text: root.icon
            size: root.size * 0.44
            fill: root.active ? 1 : 0
            color: root.active ? (Theme.lum(root.activeColor) > 0.62 ? "#000000" : "#ffffff") : Theme.fg
        }
    }
    Column {
        anchors.top: circle.bottom
        anchors.topMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.width
        visible: root.label !== ""
        Txt { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: root.label; size: 11; weight: Font.DemiBold }
        Txt { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: root.sub; size: 10; color: Theme.fg2; visible: text !== "" }
    }
    MouseArea {
        id: ma
        anchors.fill: circle
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
