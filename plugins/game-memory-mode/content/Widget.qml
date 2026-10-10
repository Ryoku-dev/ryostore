import QtQuick
import Ryoku.PluginKit.Singletons
Item {
    id: root
    property var pluginApi
    property var screen
    property bool active: false
    property string density: "glyph"
    property real s: 1
    property real widthBudget: 0
    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    implicitWidth: label.implicitWidth + 8*s
    implicitHeight: 20*s
    Text {
        id: label
        anchors.centerIn: parent
        text: "🎮"
        opacity: root.service?.enabled ? 1 : 0.65
        color: root.service?.enabled ? Theme.accent : Theme.dim
        font.pixelSize: 16*root.s
    }
    MouseArea { anchors.fill: parent; onClicked: if (root.pluginApi) root.pluginApi.togglePanel() }
}
