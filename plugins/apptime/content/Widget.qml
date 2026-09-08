// apptime glyph: a small vector clock plus today's total. Left click toggles
// the panel. Nothing here mutates state — the service does all the work.
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
    readonly property int total: service ? service.totalSeconds : 0
    readonly property bool showTotal: {
        if (!service || !service.settings) return true;
        const v = service.settings.glyphTotal;
        return v === undefined || v === null ? true : !!v;
    }
    readonly property bool lit: (mouse.containsMouse || (pluginApi ? pluginApi.panelOpen : false))

    implicitWidth: row.implicitWidth
    implicitHeight: Math.max(row.implicitHeight, 20 * root.s)

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6 * root.s

        // tiny clock, drawn in place (no icon font dependency)
        Item {
            id: clock
            width: 15 * root.s
            height: 15 * root.s
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: 1.6 * root.s
                border.color: root.lit ? Theme.accent : Theme.dim
            }
            Rectangle {
                width: 1.7 * root.s
                height: 4.4 * root.s
                radius: 0.9 * root.s
                color: root.lit ? Theme.accent : Theme.dim
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.verticalCenter
                rotation: -60
                transformOrigin: Item.Bottom
            }
            Rectangle {
                width: 1.7 * root.s
                height: 5.8 * root.s
                radius: 0.9 * root.s
                color: root.lit ? Theme.accent : Theme.dim
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.verticalCenter
                rotation: 60
                transformOrigin: Item.Bottom
            }
        }

        Text {
            id: totalLabel
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showTotal
            text: service ? service.fmtHM(root.total) : ""
            color: root.lit ? Theme.accent : Theme.bright
            font.family: Theme.mono
            font.pixelSize: 12.5 * root.s
            font.weight: Font.Medium
            elide: Text.ElideRight
            width: root.widthBudget > 0
                ? Math.min(implicitWidth, Math.max(40, root.widthBudget - clock.width - row.spacing))
                : implicitWidth
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.pluginApi) root.pluginApi.togglePanel()
    }
}
