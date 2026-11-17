import QtQuick

// Text that scrolls back and forth when it doesn't fit.
Item {
    id: root
    property alias text: label.text
    property alias size: label.size
    property alias weight: label.weight
    property alias color: label.color
    property bool running: true
    readonly property bool overflow: label.implicitWidth > width + 1

    implicitHeight: label.implicitHeight
    clip: true

    Txt {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        width: implicitWidth
        elide: Text.ElideNone
        onTextChanged: { x = 0; if (anim.running) anim.restart(); }

        SequentialAnimation on x {
            id: anim
            running: root.overflow && root.running && root.visible
            loops: Animation.Infinite
            PauseAnimation { duration: 1800 }
            NumberAnimation {
                to: -(label.implicitWidth - root.width)
                duration: Math.max(1200, (label.implicitWidth - root.width) * 30)
                easing.type: Easing.InOutSine
            }
            PauseAnimation { duration: 1200 }
            NumberAnimation { to: 0; duration: 600; easing.type: Easing.OutCubic }
            onRunningChanged: if (!running) label.x = 0
        }
    }
}
