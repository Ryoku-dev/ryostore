pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import shell.services
import shell.barkit as Pill

Item {
    id: root

    property bool allow: true

    visible: root.allow && Tray.items.length > 0
    implicitWidth: visible ? content.implicitWidth : 0
    implicitHeight: 32

    function iconSource(item) {
        if (item.iconPath && item.iconPath.length)
            return item.iconPath.indexOf("/") === 0 ? "file://" + item.iconPath : item.iconPath;

        if (item.iconName && item.iconName.length)
            return Quickshell.iconPath(item.iconName, "application-x-executable-symbolic");

        return Quickshell.iconPath("application-x-executable-symbolic", true);
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 7

        Repeater {
            model: Tray.items

            delegate: Item {
                id: cell
                required property var modelData

                width: 20
                height: 30

                Image {
                    anchors.centerIn: parent
                    width: 17
                    height: 17
                    sourceSize.width: width
                    sourceSize.height: height
                    smooth: true
                    asynchronous: true
                    source: root.iconSource(cell.modelData)
                    opacity: hover.hovered ? 1 : 0.82
                    scale: mouse.pressed ? 0.84 : hover.hovered ? 1.08 : 1

                    Behavior on opacity { NumberAnimation { duration: 110 } }
                    Behavior on scale {
                        NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
                    }
                }

                HoverHandler {
                    id: hover
                    cursorShape: Qt.PointingHandCursor
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    onClicked: event => {
                        const item = cell.modelData;

                        if (event.button === Qt.LeftButton) {
                            const p = cell.mapToGlobal(0, cell.height);
                            Tray.activate(item.service, Math.round(p.x), Math.round(p.y));
                            return;
                        }

                        if (item.menu) {
                            trayMenu.openFor(item, cell);
                            return;
                        }

                        const p = cell.mapToGlobal(0, cell.height);
                        Tray.contextMenu(item.service, Math.round(p.x), Math.round(p.y));
                    }
                }
            }
        }
    }

    Pill.TrayMenu {
        id: trayMenu
        edge: "top"
    }
}
