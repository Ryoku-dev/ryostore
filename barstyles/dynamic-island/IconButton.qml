import QtQuick

// A round icon button. `glass: true` sits it on a liquid-glass bead (header
// and toolbar buttons); otherwise it is a bare glyph with a soft hover disc.
Item {
    id: root
    property string icon: ""
    property real size: 20
    property real pad: 8
    property real fill: 0
    property color color: Theme.fg
    property color bg: "transparent"
    property bool active: false
    property bool glass: false
    readonly property bool hovered: ma.containsMouse
    signal clicked()

    implicitWidth: size + pad * 2
    implicitHeight: size + pad * 2
    opacity: enabled ? 1 : 0.3

    Rectangle {
        visible: !root.glass
        anchors.fill: parent
        radius: height / 2
        color: root.active ? Theme.fill3 : ma.containsMouse ? Theme.fill2 : root.bg
        Behavior on color { ColorAnimation { duration: 150 } }
    }
    Lens {
        visible: root.glass
        anchors.fill: parent
        hovered: ma.containsMouse
        pressed: ma.pressed
        tint: Theme.accent
        tintAmount: root.active ? 0.85 : 0
        scale: ma.pressed ? 0.92 : 1
        Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
    }
    Icon {
        anchors.centerIn: parent
        text: root.icon
        size: root.size
        fill: root.fill
        color: root.color
        scale: ma.pressed ? 0.8 : 1
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
