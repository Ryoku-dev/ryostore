pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.PluginKit
import Ryoku.PluginKit.Singletons
import "Logic.js" as Logic

// The desktop face: a compact tile. One line — the coffee mark, the state
// pill, and how long it has been awake — with the toggle button beside it. It
// reads everything from the service; the tap toggles the inhibitor through the
// same host bridge the bar panel uses. Colour comes from the kit Theme.
Item {
    id: root

    // Host-set; read only, never assign.
    property var pluginApi
    property var screen
    property bool active: false
    property string density: "compact"
    property real s: 1
    property real widthBudget: 0

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property bool on: service ? service.on : false
    readonly property bool known: service ? service.known : false
    readonly property bool busy: service ? service.busy : false

    readonly property real w: widthBudget > 0 ? widthBudget : 240 * s
    readonly property string stateText: !known ? "…" : (on ? "ON" : "OFF")
    readonly property string awakeFor: (service && service.on && service.since > 0)
        ? Logic.formatElapsed(service.nowMs - service.since) : ""

    implicitWidth: w
    implicitHeight: row.implicitHeight

    Item {
        id: row
        width: root.w
        implicitHeight: Math.max(cup.implicitHeight, labels.implicitHeight, chip.implicitHeight)

        GlyphIcon {
            id: cup
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 18 * root.s
            height: 18 * root.s
            name: "coffee"
            color: root.on ? Theme.accent : Theme.dim
            opacity: root.known ? 1 : 0.55
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }

        Column {
            id: labels
            anchors.left: cup.right
            anchors.leftMargin: 10 * root.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2 * root.s

            Text {
                text: root.stateText + (root.awakeFor ? " · " + root.awakeFor : "")
                color: root.on ? Theme.cream : Theme.dim
                font.family: Theme.mono
                font.pixelSize: 11 * root.s
                font.weight: Font.DemiBold
                font.letterSpacing: 1.4 * root.s
            }
            Text {
                visible: root.on
                text: "idle inhibited"
                color: Theme.faint
                font.family: Theme.mono
                font.pixelSize: 9 * root.s
                font.letterSpacing: 1.2 * root.s
                font.capitalization: Font.AllUppercase
            }
        }

        Rectangle {
            id: chip
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: chipText.implicitWidth + 18 * root.s
            height: 22 * root.s
            radius: Theme.radius
            color: chipHover.hovered && !root.busy ? Theme.sheen : "transparent"
            border.width: 1
            border.color: root.busy ? Theme.border : Theme.lineStrong
            opacity: root.busy ? 0.5 : 1

            Text {
                id: chipText
                anchors.centerIn: parent
                text: root.on ? "LET IDLE" : "KEEP AWAKE"
                color: root.on ? Theme.cream : Theme.accent
                font.family: Theme.mono
                font.pixelSize: 9 * root.s
                font.weight: Font.DemiBold
                font.letterSpacing: 1.4 * root.s
            }

            HoverHandler { id: chipHover; cursorShape: root.busy ? Qt.ArrowCursor : Qt.PointingHandCursor }
            TapHandler {
                enabled: !root.busy
                onTapped: if (root.service) root.service.toggle()
            }
        }
    }
}
