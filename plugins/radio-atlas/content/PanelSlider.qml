import QtQuick

// Port shim for the Omarchy shell's panel slider. Used once (player volume)
// with: minimum, maximum, step, integer, value, track/fill/knob/tick colours,
// enabled, onMoved(nextVolume) and onRightClicked; children read _hot,
// liveValue and progress.
Item {
    id: root

    implicitWidth: 120
    implicitHeight: knobSize + 8

    property real knobSize: 10
    property real minimum: 0
    property real maximum: 100
    property real step: 1
    property bool integer: false
    property real value: 0
    property bool _hot: false
    property color trackColor: "#80808080"
    property color fillColor: "#ffffff"
    property color knobColor: "#ffffff"
    property color tickColor: "#101010"

    readonly property bool _interactive: enabled
    // places the dragged position (like the original's middleware read) —
    // liveValue is what the child Text displays while dragging.
    readonly property real liveValue: _liveValue
    property real _liveValue: value
    readonly property real progress:
        (maximum > minimum) ? (value - minimum) / (maximum - minimum) : 0

    signal moved(real next)
    signal rightClicked()

    onValueChanged: _liveValue = value

    function snap(v) {
        var n = Math.round((v - minimum) / step) * step + minimum
        n = Math.max(minimum, Math.min(maximum, n))
        return integer ? Math.round(n) : n
    }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.max(2, root.knobSize * 0.35)
        radius: height / 2
        color: root.trackColor
    }

    Rectangle {
        id: fill
        anchors.verticalCenter: track.verticalCenter
        anchors.left: track.left
        width: track.width * root.progress
        height: track.height
        radius: height / 2
        color: root.fillColor
    }

    Rectangle {
        id: knob
        width: root.enabled ? root.knobSize : root.knobSize * 0.8
        height: width
        radius: width / 2
        color: root.knobColor
        border.width: 2
        border.color: root.enabled ? root.tickColor : root.trackColor
        anchors.verticalCenter: track.verticalCenter
        x: Math.max(0, Math.min(track.width - width,
                                track.width * root.progress - width / 2))
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -6
        enabled: root._interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: root._hot = true
        onExited: if (!pressed) root._hot = false
        onPositionChanged: (mouse) => {
            root._hot = true
            if (pressed) {
                var v = root.snap(root.minimum +
                    (mouse.x - knob.width / 2) / track.width *
                    (root.maximum - root.minimum))
                root._liveValue = v
                root.moved(v)
            }
        }
        onPressed: (mouse) => { root._hot = true; root._trackTo(mouse.x) }
        onReleased: (mouse) => { if (!containsMouse) root._hot = false }
        onClicked: (mouse) => { if (mouse.button === Qt.RightButton) root.rightClicked() }
    }

    function _trackTo(x) {
        var v = root.snap(root.minimum +
            (x - knob.width / 2) / track.width * (root.maximum - root.minimum))
        root._liveValue = v
        root.moved(v)
    }
}
