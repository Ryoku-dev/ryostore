import QtQuick
import Ryoku.PluginKit.Singletons

// The bar glyph and render usage %. A click only opens the panel.
Item {
    id: root

    property var pluginApi
    property var screen
    property bool active: false
    property string density: "glyph"
    property real s: 1
    property real widthBudget: 0

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property string value: {
        if (!root.service || !root.service.found)
            return "n/a";
        if (!root.service.ready)
            return "--";
        return String(Math.round(root.service.busy)).padStart(2, "0") + "%";
    }

    implicitWidth: row.implicitWidth
    implicitHeight: Math.max(row.implicitHeight, 18 * root.s)

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5 * root.s

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: String.fromCodePoint(0xF061A)
            color: root.active ? Theme.accent : Theme.bright
            font.family: Theme.mono
            font.pixelSize: 14 * root.s
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.value
            color: root.active ? Theme.accent : Theme.bright
            font.family: Theme.mono
            font.pixelSize: 12 * root.s
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: if (root.pluginApi) root.pluginApi.togglePanel()
    }
}
