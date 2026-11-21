import QtQuick
import QtQuick.Effects

// The island body: solid black, like the hardware it imitates.
// One rectangle, one shadow and an optional coloured halo. No offscreen
// layers, so it costs next to nothing while the island springs between sizes.
Item {
    id: root
    property real radius: 20
    property color color: Theme.surface
    property bool hairline: true            // a faint edge so black reads on a black wallpaper
    property bool shadow: true
    property real shadowBlur: 24
    property real shadowY: 6
    property color glowColor: Theme.accent
    property real glowStrength: 0
    readonly property real r: Math.max(0, Math.min(radius, height / 2, width / 2))

    RectangularShadow {
        anchors.fill: parent
        visible: root.shadow
        radius: root.r
        blur: root.shadowBlur
        spread: -4
        offset.y: root.shadowY
        color: Theme.shadow
    }
    RectangularShadow {
        anchors.fill: parent
        visible: opacity > 0.01
        radius: root.r
        blur: 30
        spread: 1
        color: root.glowColor
        opacity: root.glowStrength
        Behavior on opacity { NumberAnimation { duration: 600 } }
        Behavior on color { ColorAnimation { duration: 500 } }
    }
    Rectangle {
        anchors.fill: parent
        radius: root.r
        color: root.color
        border.width: root.hairline ? 1 : 0
        border.color: Theme.hairline
    }
}
