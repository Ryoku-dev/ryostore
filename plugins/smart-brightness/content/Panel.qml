pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.PluginKit.Singletons

// Bar panel: master switch and live status. The only place that mutates the
// enabled setting; brightness itself is driven by the service when media goes
// fullscreen. Host sizes the card to this root's implicitHeight.
Item {
    id: root

    property var pluginApi
    property string density: "full"
    property real s: 1
    property real widthBudget: 320
    property bool active: false

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property bool enabled: service ? service.enabled : false
    readonly property bool videoActive: service ? service.videoActive : false
    readonly property int brightnessPercent: service ? service.brightnessPercent : -1
    readonly property string focusSummary: service ? service.focusSummary : ""
    readonly property string lastAction: service ? service.lastAction : ""
    readonly property string focusedTitle: service ? service.focusedTitle : ""

    readonly property real w: widthBudget > 0 ? widthBudget : 320
    readonly property string pillText: {
        if (videoActive)
            return "VIDEO";
        if (enabled)
            return "ON";
        return "OFF";
    }
    readonly property color pillInk: {
        if (videoActive)
            return Theme.accent;
        if (enabled)
            return Theme.cream;
        return Theme.dim;
    }

    implicitWidth: w
    implicitHeight: col.implicitHeight + 24 * s

    component Btn: Rectangle {
        id: btn
        property string label: ""
        property bool enabledAction: true
        property bool strong: false
        signal tapped()
        implicitWidth: btnText.implicitWidth + 22 * root.s
        implicitHeight: 24 * root.s
        radius: 0
        color: btnHover.hovered && btn.enabledAction ? Theme.sheen : "transparent"
        border.width: 1
        border.color: btn.enabledAction ? (btn.strong ? Theme.lineStrong : Theme.border) : Theme.border
        opacity: btn.enabledAction ? 1 : 0.5
        Text {
            id: btnText
            anchors.centerIn: parent
            text: btn.label
            color: Theme.cream
            font.family: Theme.mono
            font.pixelSize: 9.5 * root.s
            font.weight: Font.DemiBold
            font.letterSpacing: 1.6 * root.s
        }
        HoverHandler { id: btnHover; cursorShape: btn.enabledAction ? Qt.PointingHandCursor : Qt.ArrowCursor }
        TapHandler { enabled: btn.enabledAction; onTapped: btn.tapped() }
    }

    component InfoRow: Item {
        property string label: ""
        property string value: ""
        width: parent ? parent.width : 0
        height: visible ? 18 * root.s : 0
        visible: value.length > 0
        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: parent.label
            color: Theme.faint
            font.family: Theme.mono
            font.pixelSize: 10 * root.s
            font.letterSpacing: 1.2 * root.s
            font.capitalization: Font.AllUppercase
        }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * 0.62
            horizontalAlignment: Text.AlignRight
            text: parent.value
            color: Theme.cream
            font.family: Theme.mono
            font.pixelSize: 10.5 * root.s
            elide: Text.ElideRight
        }
    }

    Column {
        id: col
        x: 12 * root.s
        y: 12 * root.s
        width: root.w - 24 * root.s
        spacing: 12 * root.s

        Item {
            width: parent.width
            height: 20 * root.s
            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Smart Brightness"
                color: Theme.cream
                font.family: Theme.mono
                font.pixelSize: 13 * root.s
                font.weight: Font.DemiBold
                font.letterSpacing: 1.6 * root.s
            }
            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: pill.implicitWidth + 14 * root.s
                height: 17 * root.s
                radius: 0
                color: "transparent"
                border.width: 1
                border.color: root.pillInk
                Text {
                    id: pill
                    anchors.centerIn: parent
                    text: root.pillText
                    color: root.pillInk
                    font.family: Theme.mono
                    font.pixelSize: 8.5 * root.s
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.6 * root.s
                }
            }
        }

        Text {
            width: parent.width
            text: root.videoActive
                ? qsTr("Fullscreen media is up — backlight is at max. Your brightness keys still work; the previous level restores when you leave.")
                : (root.enabled
                    ? qsTr("Watching for compositor-fullscreen media (players and video pages). Maximized windows alone do not trigger it.")
                    : qsTr("Off. Brightness stays where you set it."))
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 12 * root.s
            wrapMode: Text.WordWrap
        }

        Rectangle { width: parent.width; height: 1; color: Theme.hair }

        Item {
            width: parent.width
            height: 24 * root.s
            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.enabled ? qsTr("Watching") : qsTr("Paused")
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 12 * root.s
                font.weight: Font.DemiBold
            }
            Btn {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                strong: true
                label: root.enabled ? qsTr("TURN OFF") : qsTr("TURN ON")
                onTapped: if (root.service) root.service.toggleEnabled()
            }
        }

        InfoRow {
            label: qsTr("backlight")
            value: root.brightnessPercent >= 0 ? (root.brightnessPercent + "%") : ""
        }
        InfoRow {
            label: qsTr("focus")
            value: root.focusSummary
        }
        InfoRow {
            label: qsTr("title")
            value: root.focusedTitle
        }
        InfoRow {
            label: qsTr("last")
            value: root.lastAction
        }
    }
}
