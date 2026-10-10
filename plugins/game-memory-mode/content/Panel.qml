import QtQuick
import Ryoku.PluginKit.Singletons
Item {
    id: root
    property var pluginApi
    property string density: "full"
    property real s: 1
    property real widthBudget: 320
    property bool active: false
    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property var status: service ? service.status : ({})
    implicitWidth: widthBudget
    implicitHeight: col.implicitHeight + 28*s
    Column {
        id: col
        x: 14*root.s; y: 14*root.s; width: parent.width-28*root.s; spacing: 12*root.s
        Text { text: "Game Mode Optimizer"; color: Theme.bright; font.family: Theme.display; font.pixelSize: 17*root.s }
        Text {
            width: parent.width; wrapMode: Text.WordWrap
            text: root.status.error || (root.status.active ? "Active · voice typing stopped, live wallpaper replaced" : "Ready · your usual desktop is unchanged")
            color: root.status.error ? Theme.accent : Theme.dim
            font.family: Theme.font; font.pixelSize: 13*root.s
        }
        Text {
            visible: root.status.gaming || root.status.games > 0
            text: (root.status.gaming ? "Following Quick Settings → Gaming" : "") + (root.status.games > 0 ? " · " + root.status.games + " game session(s)" : "")
            width: parent.width; wrapMode: Text.WordWrap; color: Theme.dim; font.pixelSize: 12*root.s
        }
        Rectangle {
            width: parent.width; height: 36*root.s; radius: Theme.radius; color: Theme.accent
            Text { anchors.centerIn: parent; text: root.status.manual ? "Turn manual mode off" : "Turn manual mode on"; color: Theme.cardBot; font.pixelSize: 13*root.s }
            MouseArea { anchors.fill: parent; onClicked: if (root.service) root.service.toggleManual() }
        }
        Repeater {
            model: [{key:"automatic",label:"Automatic on game launch"},{key:"followGaming",label:"Follow the Gaming toggle"}]
            delegate: Rectangle {
                required property var modelData
                readonly property bool checked: root.pluginApi ? (root.pluginApi.pluginSettings[modelData.key] ?? true) : true
                width: col.width; height: 34*root.s; radius: Theme.radius; color: Theme.cardBot
                Text { anchors.left: parent.left; anchors.leftMargin: 8*root.s; anchors.verticalCenter: parent.verticalCenter; text: modelData.label; color: Theme.bright; font.pixelSize: 12*root.s }
                Text { anchors.right: parent.right; anchors.rightMargin: 8*root.s; anchors.verticalCenter: parent.verticalCenter; text: parent.checked ? "On" : "Off"; color: Theme.accent; font.pixelSize: 12*root.s }
                MouseArea { anchors.fill: parent; onClicked: root.pluginApi.saveSetting(parent.modelData.key,!parent.checked) }
            }
        }
        Text { width: parent.width; wrapMode: Text.WordWrap; text: "Restores what was running before gaming. A video becomes a still frame of the same wallpaper."; color: Theme.dim; font.pixelSize: 12*root.s }
    }
}
