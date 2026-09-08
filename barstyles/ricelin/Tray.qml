pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import shell.services as Shell
import shell.barkit as BarKit
import "Singletons"

// The daemon owns SNI registration and removal, as it does for Obi and Nacre.
// Render its current frame instead of retaining dead QML items or blacklisting
// application IDs (which would also hide a restarted instance of the app).
Item {
    id: tray

    property real s: 1
    property var barWindow

    visible: Shell.Tray.items.length > 0
    implicitWidth: visible ? row.implicitWidth : 0
    implicitHeight: 24 * tray.s

    function itemSource(item) {
        if (item.iconPath)
            return item.iconPath.indexOf("/") === 0 ? "file://" + item.iconPath : item.iconPath;
        return Quickshell.iconPath(item.iconName || "application-x-executable-symbolic", true);
    }

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: 2 * tray.s

        Repeater {
            model: Shell.Tray.items

            delegate: Item {
                id: slot
                required property var modelData

                Layout.preferredWidth: 24 * tray.s
                Layout.preferredHeight: 24 * tray.s

                Rectangle {
                    anchors.fill: parent
                    radius: 6 * tray.s
                    color: Theme.frameBg
                    border.width: 1
                    border.color: Theme.frameBorder
                    opacity: area.containsMouse ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                }

                Image {
                    anchors.centerIn: parent
                    source: tray.itemSource(slot.modelData)
                    sourceSize.width: 32
                    sourceSize.height: 32
                    width: 16 * tray.s
                    height: 16 * tray.s
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    asynchronous: true
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: event => {
                        const item = slot.modelData;
                        const point = slot.mapToGlobal(0, slot.height);
                        if (event.button === Qt.RightButton || item.itemIsMenu) {
                            if (item.menu)
                                trayMenu.openFor(item, slot);
                            else
                                Shell.Tray.contextMenu(item.service, Math.round(point.x), Math.round(point.y));
                        } else {
                            Shell.Tray.activate(item.service, Math.round(point.x), Math.round(point.y));
                        }
                    }
                    onWheel: wheel => Shell.Tray.scroll(slot.modelData.service, wheel.angleDelta.y, "vertical")
                }

                Tooltip {
                    s: tray.s
                    placement: "below"
                    title: (slot.modelData.tooltip && slot.modelData.tooltip.title) || slot.modelData.title || slot.modelData.id
                    show: area.containsMouse
                }
            }
        }
    }

    BarKit.TrayMenu {
        id: trayMenu
        edge: "top"
    }
}
