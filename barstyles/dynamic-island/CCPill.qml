import QtQuick

// macOS Control Center module row: the round icon toggles, the rest opens the menu (›).
Item {
    id: root
    property string icon: ""
    property string label: ""
    property string sub: ""
    property bool active: false
    property color activeColor: Theme.accent
    property bool hasMenu: true
    signal toggled()
    signal opened()

    implicitHeight: 44
    implicitWidth: 220

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: rowMa.containsMouse && root.hasMenu ? Theme.fill : "transparent"
        Behavior on color { ColorAnimation { duration: 140 } }
    }
    MouseArea {
        id: rowMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.hasMenu ? root.opened() : root.toggled()
    }

    Rectangle {
        id: circle
        x: 4
        anchors.verticalCenter: parent.verticalCenter
        width: 36; height: 36; radius: 18
        color: root.active ? root.activeColor : circMa.containsMouse ? Theme.fill3 : Theme.fill2
        scale: circMa.pressed ? 0.88 : 1
        Behavior on color { ColorAnimation { duration: 220 } }
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.6 } }
        Icon {
            anchors.centerIn: parent
            text: root.icon
            size: 19
            fill: root.active ? 1 : 0
            color: root.active ? (Theme.lum(root.activeColor) > 0.62 ? "#000000" : "#ffffff") : Theme.fg
        }
        MouseArea {
            id: circMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggled()
        }
    }
    Column {
        anchors.left: circle.right
        anchors.leftMargin: 10
        anchors.right: chev.left
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        Txt { width: parent.width; text: root.label; size: 13; weight: Font.DemiBold }
        Txt { width: parent.width; text: root.sub; size: 11.5; color: Theme.fg2; visible: text !== "" }
    }
    Icon {
        id: chev
        visible: root.hasMenu
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: "chevron_right"
        size: 18
        color: Theme.fg3
        width: root.hasMenu ? implicitWidth : 0
    }
}
