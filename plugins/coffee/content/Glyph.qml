pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.PluginKit
import Ryoku.PluginKit.Singletons

// The bar face: the kit's coffee-cup glyph, tinted accent while the inhibitor
// is held, dim when idle. An optional ON/OFF readout rides beside it (the
// barLabel setting). A left click opens the plugin's bar panel; it never
// mutates the inhibitor. Colour comes from the kit Theme so the mark matches
// the bar ink on any scheme.
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
    readonly property bool on: service ? service.on : false
    readonly property bool known: service ? service.known : true
    readonly property string stateText: !known ? "" : (on ? "ON" : "OFF")
    readonly property bool textShown: service ? service.barLabel === "state" : false

    readonly property real mark: 16 * s
    readonly property real gap: 5 * s
    readonly property real textMax: Math.max(24 * s, (widthBudget > 0 ? widthBudget : 220) - mark - gap)

    implicitWidth: mark + (textShown ? gap + stateLabel.width : 0)
    implicitHeight: Math.max(mark + 4 * s, stateLabel.implicitHeight)

    GlyphIcon {
        id: cup
        x: 0
        anchors.verticalCenter: parent.verticalCenter
        width: root.mark
        height: root.mark
        name: "coffee"
        color: root.on ? Theme.accent : Theme.dim
        opacity: root.known ? 1 : 0.55
        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

    Text {
        id: stateLabel
        visible: root.textShown
        x: root.mark + root.gap
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, root.textMax)
        text: root.stateText
        color: root.on ? Theme.cream : Theme.faint
        font.family: Theme.mono
        font.pixelSize: 11 * root.s
        font.letterSpacing: 1.2 * root.s
        elide: Text.ElideRight
    }

    HoverHandler {
        id: hover
        // (no tooltip: attached ToolTip object needs QtQuick.Controls, which
        // the plugin sandbox does not import; the panel is the status view)
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.pluginApi && root.pluginApi.togglePanel) root.pluginApi.togglePanel()
    }
}
