pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes

// Countdown timer + stopwatch with an animated progress ring.
RowLayout {
    id: root
    spacing: 26
    readonly property bool sw: Hub.timerMode === 1
    readonly property real frac: sw
        ? (Hub.swElapsed % 60000) / 60000
        : (Hub.timerActive ? Hub.timerLeft / Math.max(1, Hub.timerTotal) : 1)
    property real shownFrac: frac
    Behavior on shownFrac { enabled: !root.sw; NumberAnimation { duration: 950 } }
    readonly property color ringColor: sw ? Theme.green : Theme.orange

    component Pill: Rectangle {
        id: pill
        property string label: ""
        property color tint: Theme.fill2
        property color textColor: Theme.fg
        signal clicked()
        Layout.fillWidth: true
        implicitHeight: 40
        radius: 20
        color: tint
        opacity: pMa.containsMouse ? 0.85 : 1
        scale: pMa.pressed ? 0.94 : 1
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
        Behavior on color { ColorAnimation { duration: 200 } }
        Txt { anchors.centerIn: parent; text: pill.label; size: 13; weight: Font.DemiBold; color: pill.textColor }
        MouseArea { id: pMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pill.clicked() }
    }

    Item {
        Layout.preferredWidth: 180
        Layout.preferredHeight: 180
        Layout.alignment: Qt.AlignVCenter

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Theme.fill2
                strokeWidth: 10
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: 90; centerY: 90; radiusX: 82; radiusY: 82; startAngle: 0; sweepAngle: 360 }
            }
            ShapePath {
                strokeColor: root.ringColor
                strokeWidth: 10
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: 90; centerY: 90; radiusX: 82; radiusY: 82
                    startAngle: -90
                    sweepAngle: 360 * Math.max(0.001, root.shownFrac)
                }
            }
        }
        Column {
            anchors.centerIn: parent
            spacing: 2
            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.sw ? Hub.fmtSw(Hub.swElapsed)
                              : Hub.fmtTime(Hub.timerActive ? Hub.timerLeft : Hub.timerSet)
                size: root.sw ? 28 : 36
                weight: Font.Medium
            }
            Txt {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.sw ? (Hub.swRunning ? "Running" : "Stopwatch")
                              : (Hub.timerRunning ? "Remaining" : Hub.timerActive ? "Paused" : "Timer")
                size: 11
                color: Theme.fg2
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 10

        // Segmented Timer / Stopwatch switch
        Rectangle {
            id: seg
            Layout.fillWidth: true
            implicitHeight: 34
            radius: 17
            color: Theme.fill
            Rectangle {
                y: 3
                width: seg.width / 2 - 4
                height: 28
                radius: 14
                x: root.sw ? seg.width / 2 + 1 : 3
                color: (Theme.dark ? Qt.rgba(1, 1, 1, 0.2) : "#ffffff")
                Behavior on x { SpringAnimation { spring: 5; damping: 0.38 } }
            }
            Row {
                anchors.fill: parent
                Repeater {
                    model: ["Timer", "Stopwatch"]
                    Item {
                        id: segItem
                        required property string modelData
                        required property int index
                        width: seg.width / 2
                        height: seg.height
                        Txt {
                            anchors.centerIn: parent
                            text: segItem.modelData
                            size: 12.5
                            weight: Font.DemiBold
                            color: Hub.timerMode === segItem.index ? Theme.fg : Theme.fg2
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Hub.timerMode = segItem.index }
                    }
                }
            }
        }

        // Presets (timer only)
        GridLayout {
            Layout.fillWidth: true
            visible: !root.sw
            columns: 3
            rowSpacing: 6
            columnSpacing: 6
            Repeater {
                model: [60, 300, 600, 900, 1500, 2700]
                Rectangle {
                    id: preset
                    required property int modelData
                    Layout.fillWidth: true
                    implicitHeight: 30
                    radius: 15
                    color: prMa.containsMouse ? Theme.fill2 : Theme.fill
                    Txt { anchors.centerIn: parent; text: (preset.modelData / 60) + " min"; size: 12 }
                    MouseArea { id: prMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Hub.startTimer(preset.modelData) }
                }
            }
        }

        // Fine adjust before starting
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            visible: !root.sw && !Hub.timerActive
            spacing: 4
            IconButton { icon: "remove"; size: 18; pad: 5; onClicked: Hub.timerSet = Math.max(60, Hub.timerSet - 60) }
            Txt { text: "1 min"; size: 11; color: Theme.fg2 }
            IconButton { icon: "add"; size: 18; pad: 5; onClicked: Hub.timerSet = Math.min(5940, Hub.timerSet + 60) }
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Pill {
                tint: root.sw ? (Hub.swRunning ? Theme.alpha(Theme.red, 0.25) : Theme.alpha(Theme.green, 0.25))
                              : (Hub.timerRunning ? Theme.alpha(Theme.orange, 0.25) : Theme.orange)
                textColor: !root.sw && !Hub.timerRunning ? "#000000" : root.sw ? (Hub.swRunning ? Theme.red : Theme.green) : Theme.orange
                label: root.sw ? (Hub.swRunning ? "Stop" : (Hub.swElapsed > 0 ? "Resume" : "Start"))
                               : (Hub.timerRunning ? "Pause" : (Hub.timerLeft > 0 ? "Resume" : "Start"))
                onClicked: root.sw ? Hub.swToggle() : Hub.timerToggle()
            }
            Pill {
                label: "Reset"
                onClicked: root.sw ? Hub.swReset() : Hub.timerReset()
            }
        }
    }
}
