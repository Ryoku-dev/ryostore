import QtQuick
import Quickshell.Widgets

// iOS-style slider. Thin by default; set `big` for the Control Center pill with an icon inside.
Item {
    id: root
    property real value: 0
    property color color: Theme.fg
    property bool interactive: true
    property real barHeight: 6
    property bool big: false
    property string icon: ""
    signal moved(real v)
    signal committed(real v)

    readonly property bool active: ma.containsMouse || ma.pressed
    readonly property real shownValue: Math.max(0, Math.min(1, ma.pressed ? ma.dragValue : value))
    readonly property real h: big ? barHeight : (interactive && active ? barHeight + 3 : barHeight)
    implicitHeight: big ? barHeight : 20
    implicitWidth: 120

    ClippingRectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: root.h
        radius: height / 2
        color: root.big ? (Theme.dark ? Theme.fill2 : Theme.fill3) : Theme.fill2
        scale: root.big && ma.pressed ? 1.025 : 1
        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2 } }

        Rectangle {
            height: track.height
            radius: root.big ? 0 : track.radius
            width: root.big ? parent.width * root.shownValue : Math.max(height, parent.width * root.shownValue)
            color: root.color
            Behavior on width { enabled: !ma.pressed; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 300 } }
        }
        Icon {
            visible: root.big && root.icon !== ""
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            fill: 1
            size: Math.min(20, root.barHeight * 0.55)
            color: root.shownValue > 0.12 ? (Theme.lum(root.color) > 0.6 ? "#000000" : "#ffffff") : Theme.fg2
        }
    }

    MouseArea {
        id: ma
        property real dragValue: 0
        anchors.fill: parent
        anchors.topMargin: root.big ? 0 : -5
        anchors.bottomMargin: root.big ? 0 : -5
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        function upd(mx) { dragValue = Math.max(0, Math.min(1, mx / width)); root.moved(dragValue); }
        onPressed: m => upd(m.x)
        onPositionChanged: m => { if (pressed) upd(m.x); }
        onReleased: root.committed(dragValue)
        onWheel: w => {
            const v = Math.max(0, Math.min(1, root.value + (w.angleDelta.y > 0 ? 0.05 : -0.05)));
            root.moved(v);
            root.committed(v);
        }
    }
}
