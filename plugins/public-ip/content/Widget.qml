import QtQuick
import QtQuick.Shapes
import Ryoku.PluginKit.Singletons

// content/Widget.qml is the one view the host mounts (on the bar, this is the
// glyph). It shows the last public IP reading; a left click copies it to the
// clipboard (the widget's only action, and it never sends anything anywhere
// beyond the local clipboard). The host sets pluginApi, density, s,
// widthBudget and active; read them, never assign.
Item {
    id: root

    property var pluginApi
    property var screen
    property bool active: false
    property string density: "glyph"
    property real s: 1
    property real widthBudget: 220

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property string ip: service ? service.ip : ""
    readonly property bool lastPollFailed: service ? service.lastPollFailed : false
    readonly property bool copied: service ? service.copied : false

    implicitWidth: row.implicitWidth
    implicitHeight: Math.max(row.implicitHeight, 18 * root.s)

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6 * root.s

        // A globe mark: stroke-only vector path in a 24x24 box, the same
        // technique Ryoku's own GlyphIcon uses.
        Shape {
            id: globeShape
            anchors.verticalCenter: parent.verticalCenter
            width: 13 * root.s
            height: 13 * root.s
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer
            opacity: root.ip.length > 0 ? 1 : 0.45

            ShapePath {
                strokeColor: Theme.accent
                fillColor: "transparent"
                strokeWidth: 1.7
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                scale: Qt.size(globeShape.width / 24, globeShape.height / 24)
                PathSvg {
                    path: "M12 2a10 10 0 1 0 0 20a10 10 0 0 0 0-20z M2 12h20 M12 2c2.8 2.7 4.2 6.3 4.2 10s-1.4 7.3-4.2 10c-2.8-2.7-4.2-6.3-4.2-10s1.4-7.3 4.2-10z"
                }
            }
        }

        // The address (or a placeholder), elided to the width the host
        // allows. Flashes an accent-coloured confirmation right after a
        // click copies it.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.copied ? "\u00a1Copiada!" : (root.ip.length > 0 ? root.ip : (root.lastPollFailed ? "sin IP" : "..."))
            color: Theme.accent
            font.family: Theme.mono
            font.pixelSize: 12 * root.s
            elide: Text.ElideRight
            width: root.widthBudget > 0 ? Math.min(implicitWidth, root.widthBudget) : implicitWidth
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.service) root.service.copyToClipboard()
    }
}
