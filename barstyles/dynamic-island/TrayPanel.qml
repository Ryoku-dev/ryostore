pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Widgets

// The system tray as a sheet inside the expanded island.
//
//   list  every tray app as a glass tile: click for its action, right-click
//         or the ⋯ badge for its menu
//   menu  that app's menu, drawn here rather than as a separate popup, with
//         submenus, check and radio items, and a back button
//
// Esc goes back one level, a click outside the island closes it. Because the
// menu is part of the island it can't be left floating after the island
// closes, and opening it never collapses the island.
Item {
    id: root
    property string screenName: ""
    readonly property bool inMenu: Hub.trayView === "menu" && Hub.trayItem !== null

    readonly property int cols: 5
    readonly property int tileH: 92
    readonly property int rowCount: Math.max(1, Math.ceil(Hub.trayItems.length / cols))
    // the island asks for this much room
    readonly property int wantedHeight: 62 + (inMenu ? Math.min(menuList.contentHeight, 380) + 16 : rowCount * (tileH + 10) + 14)

    // submenu stack (QsMenuEntry objects with children)
    property var stack: []
    readonly property var currentMenu: stack.length > 0 ? stack[stack.length - 1] : (Hub.trayItem ? Hub.trayItem.menu : null)
    Connections {
        target: Hub
        function onTrayItemChanged() { root.stack = []; }
        function onTrayViewChanged() { root.stack = []; }
    }
    function back() {
        if (stack.length > 0) { stack = stack.slice(0, -1); return; }
        Hub.trayBack();
    }

    Keys.onEscapePressed: root.back()

    // ── header ──
    Item {
        id: header
        x: 20; y: 14
        width: parent.width - 40
        height: 34
        Lens {
            id: backBtn
            width: 32; height: 32
            anchors.verticalCenter: parent.verticalCenter
            hovered: backMa.containsMouse
            pressed: backMa.pressed
            Icon { anchors.centerIn: parent; text: "chevron_left"; size: 20; color: Theme.fg }
            MouseArea { id: backMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.back() }
        }
        Row {
            anchors.left: backBtn.right
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            IconImage {
                visible: root.inMenu
                implicitSize: 20
                anchors.verticalCenter: parent.verticalCenter
                source: Hub.trayItem ? Hub.trayItem.icon : ""
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: root.inMenu ? (root.stack.length > 0 ? root.stack[root.stack.length - 1].text.replace(/_/g, "") : Hub.trayName(Hub.trayItem))
                                  : "Menu Bar Extras"
                size: 17; weight: Font.Bold
            }
        }
        Txt {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.inMenu
            text: Hub.trayItems.length + (Hub.trayItems.length === 1 ? " app" : " apps")
            size: 12; color: Theme.fg2
        }
    }

    // ── list of apps ──
    Grid {
        id: grid
        visible: !root.inMenu
        x: 20; y: 62
        width: parent.width - 40
        columns: root.cols
        rowSpacing: 10
        columnSpacing: 10
        Repeater {
            model: Hub.trayItems
            Item {
                id: tile
                required property var modelData
                width: (grid.width - (root.cols - 1) * 10) / root.cols
                height: root.tileH
                Rectangle {
                    anchors.fill: parent
                    radius: 18
                    color: tileMa.containsMouse ? Theme.fill : "transparent"
                    Behavior on color { ColorAnimation { duration: 140 } }
                }
                Lens {
                    id: well
                    width: 48; height: 48
                    radius: 15
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 8
                    hovered: tileMa.containsMouse
                    pressed: tileMa.pressed
                    scale: tileMa.pressed ? 0.92 : 1
                    Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                    IconImage { anchors.centerIn: parent; implicitSize: 24; source: tile.modelData.icon }
                }
                Txt {
                    anchors.top: well.bottom
                    anchors.topMargin: 7
                    width: parent.width - 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: Hub.trayName(tile.modelData)
                    size: 11; color: Theme.fg2
                }
                MouseArea {
                    id: tileMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onClicked: m => Hub.trayActivate(tile.modelData, m.button)
                    onWheel: w => {
                        const horiz = Math.abs(w.angleDelta.x) > Math.abs(w.angleDelta.y);
                        tile.modelData.scroll(horiz ? w.angleDelta.x : w.angleDelta.y, horiz);
                    }
                }
                // menu badge
                Lens {
                    visible: tile.modelData.hasMenu
                    width: 22; height: 22
                    anchors.left: well.right
                    anchors.leftMargin: -12
                    y: 2
                    base: "#101012"
                    hovered: dotsMa.containsMouse
                    pressed: dotsMa.pressed
                    Icon { anchors.centerIn: parent; text: "more_horiz"; size: 14; color: Theme.fg }
                    MouseArea {
                        id: dotsMa
                        anchors.fill: parent
                        anchors.margins: -3
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Hub.openTrayMenu(tile.modelData, root.screenName)
                    }
                }
            }
        }
    }
    Txt {
        visible: !root.inMenu && Hub.trayItems.length === 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: 80
        text: "No apps in the tray"
        size: 13; color: Theme.fg3
    }

    // ── an app's menu ──
    QsMenuOpener { id: opener; menu: root.inMenu ? root.currentMenu : null }
    Rectangle {
        visible: root.inMenu
        x: 20; y: 58
        width: parent.width - 40
        height: Math.min(menuList.contentHeight, 380) + 8
        radius: 20
        color: Theme.fill
        border.width: 1
        border.color: Theme.hairline
        ListView {
            id: menuList
            anchors.fill: parent
            anchors.margins: 4
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: opener.children
            delegate: Item {
                id: row
                required property var modelData
                required property int index
                readonly property var e: modelData
                readonly property bool check: e && e.buttonType !== QsMenuButtonType.None
                width: menuList.width
                height: e && e.isSeparator ? 11 : 40
                Rectangle {
                    visible: row.e && row.e.isSeparator
                    anchors.verticalCenter: parent.verticalCenter
                    x: 14; width: parent.width - 28; height: 1
                    color: Theme.sep
                }
                Rectangle {
                    visible: row.e && !row.e.isSeparator
                    anchors.fill: parent
                    radius: 14
                    color: rowMa.pressed ? Theme.fill3 : rowMa.containsMouse ? Theme.fill2 : "transparent"
                    Behavior on color { ColorAnimation { duration: 110 } }
                }
                Row {
                    visible: row.e && !row.e.isSeparator
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    opacity: row.e && row.e.enabled ? 1 : 0.4
                    Item {
                        width: 18; height: 18
                        anchors.verticalCenter: parent.verticalCenter
                        Icon {
                            anchors.centerIn: parent
                            visible: row.check && row.e.checkState === Qt.Checked
                            text: row.e && row.e.buttonType === QsMenuButtonType.RadioButton ? "radio_button_checked" : "check"
                            size: 17; weight: 700; color: Theme.accent
                        }
                        IconImage {
                            anchors.fill: parent
                            visible: !row.check && row.e && row.e.icon !== ""
                            source: row.e ? row.e.icon : ""
                        }
                    }
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        width: menuList.width - 80
                        text: row.e ? row.e.text.replace(/_(?=\w)/, "") : ""
                        size: 13.5
                    }
                }
                Icon {
                    visible: row.e && row.e.hasChildren
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "chevron_right"; size: 18; color: Theme.fg3
                }
                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    enabled: row.e && !row.e.isSeparator && row.e.enabled
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const e = row.e;
                        if (e.hasChildren) { root.stack = root.stack.concat([e]); return; }
                        e.triggered();
                        // a toggle stays put so you can see it flip; anything else is done
                        if (!row.check) Hub.collapse();
                    }
                }
            }
        }
    }
}
