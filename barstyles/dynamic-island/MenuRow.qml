import QtQuick

// A row in the Wi-Fi / Bluetooth menus.
Item {
    id: root
    property string icon: ""
    property real iconFill: 1
    property color iconBg: Theme.fill2
    property color iconColor: Theme.fg
    property string label: ""
    property string sub: ""
    property color subColor: Theme.fg2
    property bool busy: false
    property bool checked: false
    property bool locked: false
    property string trailingIcon: ""       // shown on hover (e.g. forget)
    property bool showSep: true
    readonly property bool hovered: ma.containsMouse
    default property alias extra: extraBox.data
    signal clicked()
    signal trailingClicked()

    width: parent ? parent.width : 0
    implicitHeight: 46 + extraBox.childrenRect.height

    Rectangle {
        width: parent.width
        height: 46
        radius: 12
        color: ma.pressed ? Theme.fill2 : ma.containsMouse ? Theme.fill : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    Rectangle { visible: root.showSep; x: 54; y: 0; width: parent.width - 62; height: 0.5; color: Theme.sep }
    MouseArea {
        id: ma
        width: parent.width
        height: 46
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Rectangle {
        id: ic
        x: 8; y: 7
        width: 32; height: 32; radius: 16
        color: root.iconBg
        Behavior on color { ColorAnimation { duration: 200 } }
        Icon { anchors.centerIn: parent; text: root.icon; size: 17; fill: root.iconFill; color: root.iconColor }
    }
    Column {
        anchors.left: ic.right
        anchors.leftMargin: 12
        anchors.right: trail.left
        anchors.rightMargin: 8
        y: (46 - height) / 2
        Txt { width: parent.width; text: root.label; size: 13.5; weight: root.checked ? Font.DemiBold : Font.Medium }
        Txt { width: parent.width; visible: text !== ""; text: root.sub; size: 11.5; color: root.subColor }
    }
    Row {
        id: trail
        anchors.right: parent.right
        anchors.rightMargin: 10
        y: (46 - height) / 2
        height: 22
        spacing: 8
        Icon {
            visible: root.busy
            anchors.verticalCenter: parent.verticalCenter
            text: "progress_activity"; size: 18; color: Theme.fg2
            RotationAnimator on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: root.busy }
        }
        Rectangle {
            visible: root.trailingIcon !== "" && (root.hovered || trMa.containsMouse) && !root.busy
            anchors.verticalCenter: parent.verticalCenter
            width: 22; height: 22; radius: 11
            color: trMa.containsMouse ? Theme.fill3 : Theme.fill2
            Icon { anchors.centerIn: parent; text: root.trailingIcon; size: 14; weight: 600; color: Theme.fg2 }
            MouseArea { id: trMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.trailingClicked() }
        }
        Icon { visible: root.locked; anchors.verticalCenter: parent.verticalCenter; text: "lock"; size: 15; fill: 1; color: Theme.fg3 }
        Icon { visible: root.checked && !root.busy; anchors.verticalCenter: parent.verticalCenter; text: "check"; size: 18; weight: 700; color: Theme.accent }
    }
    Item {
        id: extraBox
        y: 46
        x: 54
        width: parent.width - 62
        height: childrenRect.height
    }
}
