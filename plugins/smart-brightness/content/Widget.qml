pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.PluginKit.Singletons

// Bar glyph: Material mark that flips with watching / video / off. A left click
// opens the panel; the mark never mutates brightness itself.
Item {
    id: root

    property var pluginApi
    property var screen
    property bool active: false
    property string density: "glyph"
    property real s: 1
    property real widthBudget: 0
    property bool open: false
    property real reveal: 0
    property bool tabActive: false
    signal requestClose()

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property bool enabled: service ? service.enabled : false
    readonly property bool videoActive: service ? service.videoActive : false
    readonly property string barText: service ? service.barText : ""
    readonly property bool textShown: barText.length > 0

    readonly property real mark: 19
    readonly property real gap: 6
    readonly property real textMax: Math.max(40, (widthBudget > 0 ? widthBudget : 220) - mark - gap)

    readonly property string glyphName: {
        if (videoActive)
            return "movie";
        if (enabled)
            return "brightness_auto";
        return "brightness_6";
    }
    readonly property color glyphColor: {
        if (videoActive)
            return Theme.accent;
        if (enabled)
            return Theme.cream;
        return Theme.dim;
    }

    implicitWidth: glyph.implicitWidth + (textShown ? gap + barLabel.width : 0)
    implicitHeight: Math.max(mark + 3, glyph.implicitHeight)

    Text {
        id: glyph
        x: 0
        anchors.verticalCenter: parent.verticalCenter
        text: root.glyphName
        font.family: "Material Symbols Rounded"
        font.pixelSize: root.mark
        font.weight: 500
        font.variableAxes: ({ "FILL": root.videoActive ? 1 : 0, "opsz": 20 })
        renderType: Text.QtRendering
        color: root.glyphColor
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    Text {
        id: barLabel
        anchors.verticalCenter: parent.verticalCenter
        x: glyph.x + glyph.implicitWidth + root.gap
        visible: root.textShown
        text: root.barText
        color: root.videoActive ? Theme.cream : Theme.faint
        font.family: Theme.mono
        font.pixelSize: 11
        font.letterSpacing: 1.2
        elide: Text.ElideRight
        width: Math.min(implicitWidth, root.textMax)
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (!root.pluginApi)
                return;
            if (root.open)
                root.requestClose();
            else if (root.pluginApi.togglePanel)
                root.pluginApi.togglePanel();
        }
    }
}
