pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import shell.services
import shell.barkit as Pill

Item {
    id: root
    property bool vertical: false
    implicitWidth: vertical ? 26 : strip.implicitWidth + 8
    implicitHeight: vertical ? strip.implicitHeight + 8 : 26
    visible: Tray.items.length > 0

    function itemSource(it) {
        if (it.iconPath && it.iconPath.length > 0)
            return it.iconPath.indexOf("/") === 0 ? ("file://" + it.iconPath) : it.iconPath;
        if (it.iconName && it.iconName.length > 0)
            return Quickshell.iconPath(it.iconName, "application-x-executable-symbolic");
        return Quickshell.iconPath("application-x-executable-symbolic", true);
    }

    Row {
        id: strip
        anchors.centerIn: parent
        spacing: 8

        Repeater {
            model: Tray.items

            delegate: Item {
                id: cell
                required property var modelData

                width: 18
                height: 26

                Image {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    sourceSize.width: width
                    sourceSize.height: height
                    smooth: true
                    asynchronous: true
                    source: root.itemSource(cell.modelData)
                    scale: area.pressed ? 0.82 : 1.0
                    opacity: area.pressed ? 0.72 : 1.0
                    Behavior on scale { NumberAnimation { duration: 120 } }
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: event => {
                        const it = cell.modelData;
                        if (event.button === Qt.LeftButton) {
                            const g = cell.mapToGlobal(0, cell.height);
                            Tray.activate(it.service, Math.round(g.x), Math.round(g.y));
                        } else if (it.menu) {
                            trayMenu.openFor(it, cell);
                        } else {
                            const g = cell.mapToGlobal(0, cell.height);
                            Tray.contextMenu(it.service, Math.round(g.x), Math.round(g.y));
                        }
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
