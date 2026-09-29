import QtQuick
import Ryoku.PluginKit.Singletons

// content/Panel.qml: purely informative detail card, no buttons, no actions.
// Opens under the glyph on click.
Item {
    id: root

    property var pluginApi
    property string density: "full"
    property real s: 1
    property real widthBudget: 280
    property bool active: false

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property bool found: service ? service.found : false
    readonly property string deviceName: service ? service.deviceName : ""
    readonly property bool reachable: service ? service.reachable : false
    readonly property int charge: service ? service.charge : -1
    readonly property bool charging: service ? service.charging : false
    readonly property int notifCount: service ? service.notifCount : 0
    readonly property bool lastPollFailed: service ? service.lastPollFailed : false

    implicitWidth: root.widthBudget
    implicitHeight: col.implicitHeight + 24 * root.s

    Column {
        id: col
        x: 14 * root.s
        y: 12 * root.s
        width: root.width - 28 * root.s
        spacing: 8 * root.s

        Text {
            text: "KDE Connect"
            color: Theme.bright
            font.family: Theme.display
            font.pixelSize: 16 * root.s
        }

        Text {
            visible: !root.found
            text: root.lastPollFailed ? "Could not reach kdeconnectd." : "No paired device found."
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 13 * root.s
            wrapMode: Text.WordWrap
            width: parent.width
        }

        Column {
            visible: root.found
            width: parent.width
            spacing: 6 * root.s

            Text {
                text: root.deviceName || "Unknown device"
                color: Theme.bright
                font.family: Theme.font
                font.pixelSize: 14 * root.s
            }

            Text {
                text: root.reachable ? "Connected" : "Not reachable"
                color: root.reachable ? Theme.accent : Theme.dim
                font.family: Theme.font
                font.pixelSize: 12 * root.s
            }

            Text {
                visible: root.charge >= 0
                text: "Battery: " + root.charge + "%" + (root.charging ? " (charging)" : "")
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 12 * root.s
            }

            Text {
                text: "Notifications: " + root.notifCount
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 12 * root.s
            }
        }
    }
}
