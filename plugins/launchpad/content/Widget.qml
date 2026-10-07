import QtQuick
import Ryoku.PluginKit.Singletons

// Bar glyph: a 2x2 tile mark; the accent tile lights while the panel is open.
// A click only toggles the panel.
Item {
    id: root

    property var pluginApi
    property var screen
    property bool active: false
    property string density: "glyph"
    property real s: 1
    property real widthBudget: 0

    readonly property bool open: pluginApi ? pluginApi.panelOpen : false

    implicitWidth: 16 * root.s
    implicitHeight: 18 * root.s

    Grid {
        anchors.centerIn: parent
        columns: 2
        spacing: 2.5 * root.s
        Repeater {
            model: 4
            Rectangle {
                required property int index
                width: 6 * root.s
                height: 6 * root.s
                radius: 1.5 * root.s
                color: index === 0 ? Theme.accent : (root.open || area.containsMouse ? Theme.bright : Theme.iconDim)
                Behavior on color { ColorAnimation { duration: Motion.fast } }
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.pluginApi) root.pluginApi.togglePanel()
    }
}
