pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.PluginKit.Singletons

// Desktop tile: status + toggle. The service keeps watching fullscreen media
// whenever the plugin is enabled — this card is just the control surface, so
// you do not need the QS Bar for Smart Brightness to run.
Item {
    id: root

    property var pluginApi
    property var screen
    property bool active: false
    property string density: "compact"
    property real s: 1
    property real widthBudget: 0

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property bool enabled: service ? service.enabled : false
    readonly property bool videoActive: service ? service.videoActive : false
    readonly property int brightnessPercent: service ? service.brightnessPercent : -1
    readonly property string focusSummary: service ? service.focusSummary : ""

    readonly property real w: widthBudget > 0 ? widthBudget : 260 * s
    readonly property string stateText: videoActive ? "VIDEO" : (enabled ? "ON" : "OFF")
    readonly property string detailText: {
        if (videoActive)
            return "max backlight";
        if (enabled)
            return "watching media";
        return "paused";
    }
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

    implicitWidth: w
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: root.w
        spacing: 8 * root.s

        Item {
            width: parent.width
            height: Math.max(mark.implicitHeight, labels.implicitHeight, chip.implicitHeight)

            Text {
                id: mark
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.glyphName
                font.family: "Material Symbols Rounded"
                font.pixelSize: 20 * root.s
                font.weight: 500
                font.variableAxes: ({ "FILL": root.videoActive ? 1 : 0, "opsz": 20 })
                renderType: Text.QtRendering
                color: root.glyphColor
                Behavior on color { ColorAnimation { duration: 140 } }
            }

            Column {
                id: labels
                anchors.left: mark.right
                anchors.leftMargin: 10 * root.s
                anchors.right: chip.left
                anchors.rightMargin: 10 * root.s
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2 * root.s

                Text {
                    width: parent.width
                    text: root.stateText
                        + (root.brightnessPercent >= 0 ? (" · " + root.brightnessPercent + "%") : "")
                    color: root.videoActive || root.enabled ? Theme.cream : Theme.dim
                    font.family: Theme.mono
                    font.pixelSize: 11 * root.s
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.4 * root.s
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: root.detailText
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 9 * root.s
                    font.letterSpacing: 1.2 * root.s
                    font.capitalization: Font.AllUppercase
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                id: chip
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: chipText.implicitWidth + 18 * root.s
                height: 22 * root.s
                radius: Theme.radius
                color: chipHover.hovered ? Theme.sheen : "transparent"
                border.width: 1
                border.color: Theme.lineStrong

                Text {
                    id: chipText
                    anchors.centerIn: parent
                    text: root.enabled ? "PAUSE" : "WATCH"
                    color: root.enabled ? Theme.cream : Theme.accent
                    font.family: Theme.mono
                    font.pixelSize: 9 * root.s
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.4 * root.s
                }

                HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: if (root.service) root.service.toggleEnabled() }
            }
        }

        Text {
            width: parent.width
            visible: root.focusSummary.length > 0 && root.enabled
            text: root.focusSummary
            color: Theme.dim
            font.family: Theme.mono
            font.pixelSize: 9.5 * root.s
            elide: Text.ElideRight
        }
    }
}
