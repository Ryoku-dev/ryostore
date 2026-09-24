import QtQuick
import QtQuick.Shapes
import Ryoku.PluginKit.Singletons

// content/Widget.qml is the one view the host mounts (on the bar, this is the
// glyph). It reads live state from the service (pluginApi.mainInstance) and
// its only click action toggles the plugin's panel: read-only, no actions.
Item {
    id: root

    property var pluginApi
    property var screen
    property bool active: false
    property string density: "glyph"
    property real s: 1
    property real widthBudget: 0

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property bool found: service ? service.found : false
    readonly property bool reachable: service ? service.reachable : false
    readonly property int charge: service ? service.charge : -1
    readonly property bool charging: service ? service.charging : false
    readonly property int notifCount: service ? service.notifCount : 0

    // Every built-in bar widget (CPU/storage/battery/volume) paints its icon
    // AND its number in the bar's own accent colour ("seal"/widgetIconColor
    // in the shipped widgets), never a flat grey — that accent is what makes
    // a plain-white number stand out. Ryoku.PluginKit's Theme.accent resolves
    // the same live accent role, so match it instead of Theme.dim/bright.
    readonly property color glyphColor: Theme.accent
    readonly property real glyphOpacity: root.found ? (root.reachable ? 1 : 0.55) : 0.4

    implicitWidth: row.implicitWidth
    implicitHeight: Math.max(row.implicitHeight, 18 * root.s)

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4 * root.s

        // A smartphone body: a stroke-only vector path in a 24x24 box, the
        // same technique Ryoku's own GlyphIcon uses (baked SVG path data, no
        // system icon theme dependency). Rounded rect + a home-indicator line
        // near the bottom edge, so it reads as a phone, not an abstract mark.
        Shape {
            id: phoneShape
            anchors.verticalCenter: parent.verticalCenter
            width: 14 * root.s
            height: 14 * root.s
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer
            opacity: root.glyphOpacity
            Behavior on opacity { NumberAnimation { duration: 200 } }

            ShapePath {
                strokeColor: root.glyphColor
                fillColor: "transparent"
                strokeWidth: 1.7
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                scale: Qt.size(phoneShape.width / 24, phoneShape.height / 24)
                PathSvg {
                    path: "M9.5 2h5A2.5 2.5 0 0 1 17 4.5v15A2.5 2.5 0 0 1 14.5 22h-5A2.5 2.5 0 0 1 7 19.5v-15A2.5 2.5 0 0 1 9.5 2z M11 19h2"
                }
                Behavior on strokeColor { ColorAnimation { duration: 200 } }
            }
        }

        // Battery percent, only once we actually have a reading. Theme.accent
        // is the same colour every other bar percentage (CPU/storage/battery)
        // is painted in, so this reads as part of the bar, not a foreign white.
        Text {
            visible: root.found && root.charge >= 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.charge + "%" + (root.charging ? "\u26A1" : "")
            color: Theme.accent
            font.family: Theme.font
            font.pixelSize: 12 * root.s
            elide: Text.ElideRight
            width: root.widthBudget > 0 ? Math.min(implicitWidth, root.widthBudget) : implicitWidth
        }

        // Unread notification count, only when there is at least one.
        Text {
            visible: root.found && root.notifCount > 0
            anchors.verticalCenter: parent.verticalCenter
            text: "(" + root.notifCount + ")"
            color: Theme.accent
            font.family: Theme.font
            font.pixelSize: 12 * root.s
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: if (root.pluginApi) root.pluginApi.togglePanel()
    }
}
