pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.PluginKit
import Ryoku.PluginKit.Singletons

// Session menu. Host PluginPanel anchors the card under the glyph (no placement
// API for a true screen-center modal); Escape / click-outside dismiss via host.
Item {
    id: root

    property var pluginApi
    property string density: "full"
    property real s: 1
    property real widthBudget: 300
    property bool active: false

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property real w: widthBudget > 0 ? widthBudget : 300

    implicitWidth: root.w
    implicitHeight: col.implicitHeight

    I18n {
        id: i18n
    }

    function run(action) {
        if (!root.service)
            return;
        if (action === "powerOff")
            root.service.powerOff();
        else if (action === "reboot")
            root.service.reboot();
        else if (action === "hibernate")
            root.service.hibernate();
        else if (action === "lock")
            root.service.lock();
        if (root.pluginApi)
            root.pluginApi.closePanel();
    }

    // Full-width action row: GlyphIcon + label (native session glyphs).
    component ActionRow: Rectangle {
        id: row
        property string label: ""
        property string icon: ""
        property bool danger: false
        signal tapped()

        width: parent ? parent.width : 0
        implicitHeight: 34 * root.s
        radius: 0
        color: rowHover.hovered
            ? (row.danger ? Qt.rgba(Theme.sun.r, Theme.sun.g, Theme.sun.b, 0.14) : Theme.sheen)
            : "transparent"
        border.width: 1
        border.color: row.danger
            ? (rowHover.hovered ? Theme.sun : Theme.lineStrong)
            : (rowHover.hovered ? Theme.lineStrong : Theme.border)
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 12 * root.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10 * root.s

            GlyphIcon {
                anchors.verticalCenter: parent.verticalCenter
                width: 15 * root.s
                height: 15 * root.s
                name: row.icon
                color: row.danger ? Theme.sun : (rowHover.hovered ? Theme.cream : Theme.iconDim)
                stroke: 1.8
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: row.label
                color: row.danger ? Theme.sun : Theme.cream
                font.family: Theme.mono
                font.pixelSize: 11 * root.s
                font.weight: Font.DemiBold
                font.letterSpacing: 1.2 * root.s
            }
        }

        HoverHandler {
            id: rowHover
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: row.tapped()
        }
    }

    Column {
        id: col
        width: root.w
        spacing: 12 * root.s

        Text {
            width: parent.width
            text: i18n.tr("Session")
            color: Theme.cream
            font.family: Theme.mono
            font.pixelSize: 13 * root.s
            font.weight: Font.DemiBold
            font.letterSpacing: 2.4 * root.s
            font.capitalization: Font.AllUppercase
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.hair
        }

        Column {
            width: parent.width
            spacing: 6 * root.s

            ActionRow {
                label: i18n.tr("Shut Down")
                icon: "shutdown"
                danger: true
                onTapped: root.run("powerOff")
            }

            ActionRow {
                label: i18n.tr("Restart")
                icon: "reboot"
                onTapped: root.run("reboot")
            }

            ActionRow {
                // GlyphKit has no "hibernate"; "suspend" is the sleep/moon mark.
                label: i18n.tr("Hibernate")
                icon: "suspend"
                onTapped: root.run("hibernate")
            }

            ActionRow {
                label: i18n.tr("Lock screen")
                icon: "lock"
                onTapped: root.run("lock")
            }
        }
    }
}
