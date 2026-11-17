import QtQuick

// Material Symbols Rounded (closest open match to SF Symbols): text: "play_arrow"
Text {
    id: root
    property real size: 18
    property real fill: 0
    property int weight: 500
    font.family: Theme.iconFont
    font.pixelSize: size
    font.variableAxes: ({ "FILL": root.fill, "wght": root.weight, "GRAD": 0, "opsz": Math.max(20, Math.min(48, root.size)) })
    color: Theme.fg
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    Behavior on fill { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 220 } }
}
