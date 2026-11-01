import QtQuick

Item {
    id: root

    property Item source
    property real topLeftRadius: 0
    property real topRightRadius: 0
    property real bottomRightRadius: 0
    property real bottomLeftRadius: 0
    property color color: "transparent"

    Rectangle {
        anchors.fill: parent
        radius: Math.min(root.width, root.height, root.topLeftRadius, root.topRightRadius, root.bottomRightRadius, root.bottomLeftRadius)
        color: root.color
        clip: true

        ShaderEffectSource {
            anchors.fill: parent
            sourceItem: root.source
            hideSource: false
        }
    }
}
