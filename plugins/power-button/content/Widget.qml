pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.PluginKit
import Ryoku.PluginKit.Singletons

// Bar glyph. Click opens the session menu panel (never runs an action directly).
Item {
    id: root

    property var pluginApi
    property var screen
    property bool active: false
    property string density: "glyph"
    property real s: 1
    property real widthBudget: 0

    readonly property bool panelOpen: pluginApi ? pluginApi.panelOpen : false
    readonly property bool lit: root.panelOpen || hover.hovered

    implicitWidth: 22 * root.s
    implicitHeight: 22 * root.s

    // Quiet hover plate — same dossier language as native pill glyphs.
    Rectangle {
        anchors.centerIn: parent
        width: 20 * root.s
        height: 20 * root.s
        radius: 0
        color: root.lit ? Theme.sheen : "transparent"
        border.width: root.panelOpen ? 1 : 0
        border.color: Theme.hair
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    GlyphIcon {
        anchors.centerIn: parent
        width: 15 * root.s
        height: 15 * root.s
        name: "shutdown"
        color: root.panelOpen ? Theme.accent : (hover.hovered ? Theme.cream : Theme.iconDim)
        stroke: 1.8
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: if (root.pluginApi) root.pluginApi.togglePanel()
    }
}
