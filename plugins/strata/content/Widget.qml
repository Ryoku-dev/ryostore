import QtQuick
import Ryoku.PluginKit
import Ryoku.PluginKit.Singletons

// Bar glyph: chip icon with a status dot, then the selected model's name.
Item {
    id: root

    property var pluginApi
    property var screen
    property bool active: false
    property string density: "glyph"
    property real s: 1
    property real widthBudget: 0

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property bool on: service ? service.running : false
    readonly property bool busy: service ? service.busy : false

    implicitWidth: row.implicitWidth
    implicitHeight: Math.max(row.implicitHeight, 18 * root.s)

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6 * root.s

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 15 * root.s
            height: 15 * root.s

            GlyphIcon {
                anchors.fill: parent
                name: "cpu"
                color: root.on ? Theme.accent : Theme.iconDim
                Behavior on color { ColorAnimation { duration: Motion.standard } }
            }
            // status dot, bottom-right of the icon
            Rectangle {
                id: dot
                width: 6 * root.s
                height: 6 * root.s
                radius: width / 2
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: -1 * root.s
                color: root.on ? Theme.accent : Theme.ghost
                border.width: 1
                border.color: Theme.cardBot
                SequentialAnimation on opacity {
                    running: root.busy
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) dot.opacity = 1
                    NumberAnimation { to: 0.25; duration: Motion.pulse }
                    NumberAnimation { to: 1; duration: Motion.pulse }
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.service && root.service.selected ? root.service.selected.label : "models"
            color: root.on ? Theme.bright : Theme.dim
            font.family: Theme.mono
            font.pixelSize: 12 * root.s
            elide: Text.ElideRight
            width: root.widthBudget > 0 ? Math.min(implicitWidth, root.widthBudget - 21 * root.s) : implicitWidth
            Behavior on color { ColorAnimation { duration: Motion.standard } }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.pluginApi) root.pluginApi.togglePanel()
    }
}
