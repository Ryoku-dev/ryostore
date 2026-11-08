pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.PluginKit.Singletons

Item {
    id: root

    property var pluginApi
    property string density: "glyph"
    property real widthBudget: 220
    property bool active: false

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property var st: (pluginApi && pluginApi.pluginSettings) ? pluginApi.pluginSettings : ({})
    readonly property bool hasTimes: service !== null && service.today && service.rows && service.rows.length > 0
    readonly property string displayMode: s("display", "full")

    function s(key, dflt) {
        var v = st[key];
        return (v === undefined || v === "") ? dflt : v;
    }

    function labelWidth() {
        if (widthBudget <= 0)
            return label.implicitWidth;
        var used = glyph.implicitWidth + row.spacing;
        if (timeText.visible)
            used += timeText.implicitWidth + row.spacing;
        if (countdownText.visible)
            used += countdownText.implicitWidth + row.spacing;
        return Math.min(label.implicitWidth, Math.max(12, widthBudget - used));
    }

    implicitWidth: hasTimes ? row.implicitWidth : Math.max(1, unavailable.implicitWidth)
    implicitHeight: 20

    // hover pill: the only affordance a 32px bar slot can offer
    Rectangle {
        id: hoverBg
        anchors.fill: parent
        anchors.margins: -7
        radius: Theme.radius
        color: Theme.ghost
        opacity: hover.hovered ? 0.7 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        visible: root.hasTimes

        Text {
            id: glyph
            anchors.verticalCenter: parent.verticalCenter
            text: (root.service && (root.service.nextKey === "fajr" || root.service.nextKey === "isha")) ? "☾" : "☀"
            color: (root.service && (root.service.nextKey === "fajr" || root.service.nextKey === "isha")) ? Theme.moonGlow : Theme.sunGold
            font.family: Theme.font
            font.pixelSize: 12
        }

        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            width: root.labelWidth()
            text: root.service && root.service.nextLabel ? root.service.nextLabel : "—"
            color: root.service && root.service.isNow ? Theme.accent : Theme.dim
            font.family: Theme.font
            font.pixelSize: 12
            font.letterSpacing: 0.2
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        Text {
            id: timeText
            anchors.verticalCenter: parent.verticalCenter
            visible: root.displayMode !== "name"
            text: root.service && root.service.nextTimeText ? root.service.nextTimeText : "—"
            color: Theme.bright
            font.family: Theme.mono
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }

        Text {
            id: countdownText
            anchors.verticalCenter: parent.verticalCenter
            visible: root.displayMode === "full"
            text: root.service ? root.service.countdownText : ""
            color: Theme.faint
            font.family: Theme.mono
            font.pixelSize: 11
        }
    }

    Text {
        id: unavailable
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.hasTimes
        text: "—"
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 12
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: if (root.pluginApi) root.pluginApi.togglePanel()
    }
}
