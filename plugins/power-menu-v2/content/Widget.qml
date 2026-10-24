import QtQuick
import Ryoku.PluginKit.Singletons

// The bar glyph. A click only opens the panel; nothing is ever run from here.
Item {
    id: root

    property var pluginApi
    property var screen
    property bool active: false
    property string density: "glyph"
    property real s: 1
    property real widthBudget: 0

    implicitWidth: mark.implicitWidth
    implicitHeight: Math.max(mark.implicitHeight, 18 * root.s)

    Text {
        id: mark
        anchors.verticalCenter: parent.verticalCenter
        text: "\u23FB"
        color: root.active ? Theme.accent : Theme.bright
        font.family: Theme.mono
        font.pixelSize: 15 * root.s
    }

    MouseArea {
        anchors.fill: parent
        onClicked: if (root.pluginApi) root.pluginApi.togglePanel()
    }
}
