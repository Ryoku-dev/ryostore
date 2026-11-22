import QtQuick
import QtQuick.Effects

// iOS toggle.
Item {
    id: root
    property bool checked: false
    property color activeColor: Theme.green
    signal toggled(bool v)

    implicitWidth: 51
    implicitHeight: 31

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? root.activeColor : Theme.fill3
        Behavior on color { ColorAnimation { duration: 220 } }
    }
    RectangularShadow {
        anchors.fill: knob
        radius: knob.radius
        blur: 8
        offset.y: 2
        color: Qt.rgba(0, 0, 0, 0.25)
    }
    Item {
        id: knob
        y: 2
        height: 27
        width: ma.pressed ? 33 : 27
        readonly property real radius: 13.5
        x: root.checked ? root.width - width - 2 : 2
        Behavior on x { SpringAnimation { spring: 5; damping: 0.42 } }
        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        // white at rest; while held it turns to glass and swells, as on iOS
        Rectangle {
            anchors.fill: parent
            radius: knob.radius
            color: "#ffffff"
            opacity: ma.pressed && Theme.glass ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 140 } }
        }
        Lens {
            anchors.fill: parent
            visible: opacity > 0.01
            opacity: ma.pressed ? 1 : 0
            scale: ma.pressed ? 1.25 : 1
            base: root.checked ? root.activeColor : "#3a3a3c"
            tint: "#ffffff"
            tintAmount: 0.15
            pressed: true
            Behavior on opacity { NumberAnimation { duration: 140 } }
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
