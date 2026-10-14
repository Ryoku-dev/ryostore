pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Ryoku.PluginKit.Singletons

// The bar face: one Material fan mark plus, when there is room, the reading the
// user asked for (rpm, profile or the hottest temperature). A left click opens
// the plugin's bar panel, which owns every change - the mark itself never writes
// anything, and no privileged action ever starts here.
//
// The mark follows the theme's accent, turns solid when the fans are on a
// manual profile, and goes gold once a sensor crosses the plugin's warning
// temperature.
Item {
    id: root

    // Host-set; read only, never assign.
    property var pluginApi
    property var screen
    property bool active: false
    property string density: "glyph"
    property real s: 1
    property real widthBudget: 0

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property bool hot: service ? service.hot : false
    // A manual profile means the EC is not deciding any more.
    readonly property bool overridden: service
        ? (service.profile === "manual" || service.profile === "max")
        : false
    readonly property string barText: service ? service.barText : ""
    readonly property string tip: service ? service.summary : ""

    // Mark sizing tracks the bar's inner height so the ligature centres like a
    // native bar glyph. gap sits between the mark and the text.
    readonly property real mark: 19
    readonly property real gap: 6
    readonly property real textMax: Math.max(48, (widthBudget > 0 ? widthBudget : 220) - mark - gap)

    readonly property color ink: {
        if (hot) return Theme.gold;
        return Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, overridden ? 1.0 : 0.6);
    }

    implicitWidth: glyph.implicitWidth + (barText.length > 0 ? gap + label.width : 0)
    implicitHeight: Math.max(mark + 3, glyph.implicitHeight)

    Text {
        id: glyph
        x: 0
        anchors.verticalCenter: parent.verticalCenter
        // Material Symbols ligature (the shell ships ttf-material-symbols).
        text: "mode_fan"
        font.family: "Material Symbols Rounded"
        font.pixelSize: root.mark
        font.weight: 500
        font.variableAxes: ({ "FILL": (root.overridden || root.hot) ? 1 : 0, "opsz": 20 })
        renderType: Text.QtRendering
        color: root.ink
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    Text {
        id: label
        x: glyph.x + glyph.implicitWidth + root.gap
        anchors.verticalCenter: parent.verticalCenter
        visible: root.barText.length > 0
        text: root.barText
        color: root.ink
        font.family: Theme.mono
        font.pixelSize: 11
        elide: Text.ElideRight
        width: Math.min(implicitWidth, root.textMax)
    }

    HoverHandler { id: hover }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        // The sanctioned pattern: a click opens the bar panel, which owns every
        // change to the machine.
        onClicked: if (root.pluginApi) root.pluginApi.togglePanel()
    }

    ToolTip {
        id: tipBox
        parent: root
        x: Math.round((root.width - width) / 2)
        y: root.height + 6
        delay: 350
        visible: hover.hovered
        text: root.tip.length > 0 ? qsTr("Fans %1 (click for the panel)").arg(root.tip) : qsTr("Fan control")
        background: Rectangle {
            color: Theme.panelBot
            border.color: Theme.border
            border.width: 1
            radius: 0
        }
        contentItem: Text {
            text: tipBox.text
            color: Theme.cream
            font.family: Theme.mono
            font.pixelSize: 11
        }
    }
}
