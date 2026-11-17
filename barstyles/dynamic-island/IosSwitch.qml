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
    Rectangle {
        id: knob
        y: 2
        height: 27
        width: ma.pressed ? 33 : 27
        radius: 13.5
        x: root.checked ? root.width - width - 2 : 2
        color: "#ffffff"
        Behavior on x { SpringAnimation { spring: 5; damping: 0.42 } }
        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
