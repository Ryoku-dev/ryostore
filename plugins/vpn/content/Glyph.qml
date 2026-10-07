pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Ryoku.PluginKit.Singletons

// The bar face: a single Material mark that flips with the live VPN state, the
// bar text beside it when there is room. A left click opens the plugin's bar
// panel; it never mutates the network. Colour comes from the kit Theme so the
// mark matches the bar ink on any scheme, nothing is hardcoded.
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
    readonly property bool connected: service ? service.connected : false
    readonly property string barText: service ? service.barText : ""
    readonly property string headline: service ? service.headline : ""

    // The bar text rides beside the mark when the service has one to show.
    readonly property bool textShown: barText.length > 0

    // Mark sizing tracks the bar's inner height so the ligature centres like a
    // native bar glyph. gap sits between the mark and the text.
    readonly property real mark: 19
    readonly property real gap: 6
    // Cap the text so a long name cannot run the bar glyph off its budget.
    readonly property real textMax: Math.max(60, (widthBudget > 0 ? widthBudget : 220) - mark - gap)

    implicitWidth: glyph.implicitWidth + (textShown ? gap + barLabel.width : 0)
    implicitHeight: Math.max(mark + 3, glyph.implicitHeight)

    Text {
        id: glyph
        x: 0
        anchors.verticalCenter: parent.verticalCenter
        // Material Symbols ligature: a locked mark when a VPN is up, key-off when
        // none is. The shell ships this font (ttf-material-symbols-variable).
        text: root.connected ? "vpn_lock" : "vpn_key_off"
        font.family: "Material Symbols Rounded"
        font.pixelSize: root.mark
        font.weight: 500
        font.variableAxes: ({ "FILL": root.connected ? 1 : 0, "opsz": 20 })
        renderType: Text.QtRendering
        // Always the theme accent, like every other bar icon; idle just drops
        // opacity instead of switching to a different, washed-out token.
        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, root.connected ? 1.0 : 0.6)
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    Text {
        id: barLabel
        anchors.verticalCenter: parent.verticalCenter
        x: glyph.x + glyph.implicitWidth + root.gap
        visible: root.textShown
        text: root.barText
        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, root.connected ? 1.0 : 0.6)
        font.family: Theme.mono
        font.pixelSize: 11
        elide: Text.ElideRight
        width: Math.min(implicitWidth, root.textMax)
    }

    HoverHandler { id: hover }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        // The sanctioned pattern: a click opens the bar panel; the panel owns
        // every mutation, so no network state ever changes from the bar mark.
        onClicked: if (root.pluginApi) root.pluginApi.togglePanel()
    }

    // Hover text: what is connected, and that a click opens the panel.
    ToolTip {
        id: tip
        parent: root
        x: Math.round((root.width - width) / 2)
        y: root.height + 6
        delay: 350
        visible: hover.hovered
        text: root.connected
            ? qsTr("VPN: %1 (click for details)").arg(root.headline.length > 0 ? root.headline : qsTr("connected"))
            : qsTr("VPN off (click for details)")
        background: Rectangle {
            color: Theme.panelBot
            border.color: Theme.border
            border.width: 1
            radius: 0
        }
        contentItem: Text {
            text: tip.text
            color: Theme.cream
            font.family: Theme.mono
            font.pixelSize: 11
        }
    }
}
