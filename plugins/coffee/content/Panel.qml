pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.PluginKit.Singletons
import "Logic.js" as Logic

// content/Panel.qml is the bar panel: mounted by the host in the shared plugin
// panel surface under the glyph (Escape or an outside click closes it). It is
// the ONLY place Coffee mutates anything: the primary button toggles the idle
// inhibitor through the service, which drives the host's own caffeine bridge,
// so the change shows up in the deck's Keep-Awake toggle too. The host sets
// pluginApi, density ("full"), s, widthBudget (manifest panel.width) and
// active; report implicitHeight and the host sizes the card to it.
Item {
    id: root

    // Host-set; read only, never assign.
    property var pluginApi
    property string density: "full"
    property real s: 1
    property real widthBudget: 300
    property bool active: false

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property bool on: service ? service.on : false
    readonly property bool known: service ? service.known : false
    readonly property bool busy: service ? service.busy : false
    readonly property string error: service ? service.error : ""

    readonly property real w: widthBudget > 0 ? widthBudget : 300
    readonly property string pillText: !known ? "…" : (on ? "ON" : "OFF")
    readonly property color pillInk: on ? Theme.accent : Theme.dim
    readonly property string awakeFor: (service && service.on && service.since > 0)
        ? Logic.formatElapsed(service.nowMs - service.since) : ""

    implicitWidth: w
    implicitHeight: col.implicitHeight + 24 * s

    Column {
        id: col
        x: 12 * root.s
        y: 12 * root.s
        width: root.w - 24 * root.s
        spacing: 10 * root.s

        // Header: mono eyebrow + the state pill.
        Item {
            width: parent.width
            height: Math.max(eyebrow.implicitHeight, pill.implicitHeight)

            Row {
                id: eyebrow
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7 * root.s
                Rectangle {
                    width: 5 * root.s; height: 5 * root.s; radius: 1 * root.s
                    color: Theme.brand
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Coffee"
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 10 * root.s
                    font.weight: Font.DemiBold
                    font.letterSpacing: 2.2 * root.s
                    font.capitalization: Font.AllUppercase
                }
            }
            Text {
                id: pill
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.pillText
                color: root.pillInk
                font.family: Theme.mono
                font.pixelSize: 10 * root.s
                font.weight: Font.DemiBold
                font.letterSpacing: 1.6 * root.s
                Behavior on color { ColorAnimation { duration: Motion.fast } }
            }
        }

        Text {
            width: parent.width
            text: root.on
                ? "Keep-awake is holding the screen and session open. Idle lock and suspend are inhibited."
                : "Keep-awake is off. The desktop idles, locks and suspends normally."
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 12 * root.s
            wrapMode: Text.WordWrap
        }

        Rectangle { width: parent.width; height: 1; color: Theme.hair }

        RowItem { s: root.s; label: "state"; value: root.known ? (root.on ? "idle inhibited" : "idle allowed") : "" }
        RowItem { s: root.s; label: "awake"; value: root.awakeFor }
        RowItem { s: root.s; label: "bridge"; value: "ryoku-cmd-caffeine" }

        Text {
            width: parent.width
            visible: root.error.length > 0
            text: root.error
            color: Theme.sun
            font.family: Theme.mono
            font.pixelSize: 10 * root.s
            wrapMode: Text.WordWrap
        }

        // The one deliberate action. Bordered mono button, accent when it would
        // turn the inhibitor on; disabled while an action is in flight.
        Rectangle {
            id: btn
            width: btnText.implicitWidth + 26 * root.s
            height: 26 * root.s
            radius: Theme.radius
            color: btnHover.hovered && !root.busy ? Theme.sheen : "transparent"
            border.width: 1
            border.color: root.busy ? Theme.border : (root.on ? Theme.border : Theme.lineStrong)
            opacity: root.busy ? 0.5 : 1

            Text {
                id: btnText
                anchors.centerIn: parent
                text: root.busy ? "WORKING…" : (root.on ? "LET IT IDLE" : "KEEP IT AWAKE")
                color: root.on ? Theme.cream : Theme.accent
                font.family: Theme.mono
                font.pixelSize: 10 * root.s
                font.weight: Font.DemiBold
                font.letterSpacing: 1.6 * root.s
            }

            HoverHandler { id: btnHover; cursorShape: root.busy ? Qt.ArrowCursor : Qt.PointingHandCursor }
            TapHandler {
                enabled: !root.busy
                onTapped: if (root.service) root.service.toggle()
            }
        }
    }
}
