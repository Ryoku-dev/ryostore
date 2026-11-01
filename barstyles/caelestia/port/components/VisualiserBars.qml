import QtQuick

Item {
    id: root

    property var values: []
    property color primaryColor: "white"
    property color secondaryColor: primaryColor
    property real rounding: 0
    property real spacing: 0
    property int animationDuration: 200
    readonly property bool settled: true

    function advance(dt: real): void {}

    Row {
        anchors.fill: parent
        spacing: root.spacing

        Repeater {
            model: root.values
            delegate: Rectangle {
                required property real modelData
                width: Math.max(0, (root.width - Math.max(0, root.values.length - 1) * root.spacing) / Math.max(1, root.values.length))
                height: Math.max(1, root.height * modelData)
                anchors.bottom: parent.bottom
                radius: Math.min(root.rounding, width / 2, height / 2)
                color: index % 2 ? root.secondaryColor : root.primaryColor
            }
        }
    }
}
