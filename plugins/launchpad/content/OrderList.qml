pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.PluginKit
import Ryoku.PluginKit.Singletons

// An EDIT list you reorder by dragging a row's grip: the row follows the pointer, the
// rows it passes slide out of its way, and it lands where you let go. × removes a row.
// labelOf / subOf / iconOf map a model entry to its text and icon.
Column {
    id: list

    property var model: []
    property real s: 1
    property var labelOf: (e) => String(e)
    property var subOf: (e) => ""
    property var iconOf: (e) => ""
    signal moveTo(int from, int to)
    signal remove(int index)

    // the drag in flight: which row, and where it would land
    property int dragFrom: -1
    property int dragTo: -1
    readonly property real pitch: 34 * s + spacing

    spacing: 6 * s

    Repeater {
        model: list.model
        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            readonly property bool dragging: grip.drag.active
            readonly property string icon: list.iconOf(modelData) || ""
            readonly property string sub: list.subOf(modelData) || ""
            // rows between the dragged row and its landing spot step aside
            readonly property real shift: list.dragFrom < 0 || dragging ? 0
                : (index > list.dragFrom && index <= list.dragTo) ? -list.pitch
                : (index < list.dragFrom && index >= list.dragTo) ? list.pitch : 0

            width: list.width
            height: 34 * list.s
            radius: Motion.rSmall * list.s
            z: dragging ? 10 : 0
            color: dragging ? Theme.threadBg : hover.hovered ? Theme.sheen : Theme.cardBot
            border.width: 1
            border.color: dragging ? Theme.accent : Theme.hair
            transform: Translate {
                y: row.dragging ? grip.drag.translation.y : row.shift
                Behavior on y { enabled: !row.dragging; NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
            }
            HoverHandler { id: hover }

            // grip: the drag handle
            Item {
                id: grip
                property alias drag: dragH
                width: 28 * list.s
                height: parent.height
                Column {
                    anchors.centerIn: parent
                    spacing: 2.5 * list.s
                    Repeater {
                        model: 3
                        Rectangle {
                            width: 10 * list.s
                            height: 1.5 * list.s
                            radius: height / 2
                            color: row.dragging || gripHover.hovered ? Theme.accent : Theme.iconDim
                        }
                    }
                }
                HoverHandler { id: gripHover; cursorShape: row.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor }
                DragHandler {
                    id: dragH
                    target: null
                    xAxis.enabled: false
                    onTranslationChanged: if (active) {
                        list.dragFrom = row.index;
                        list.dragTo = Math.max(0, Math.min(list.model.length - 1, row.index + Math.round(translation.y / list.pitch)));
                    }
                    onActiveChanged: if (!active) {
                        const from = list.dragFrom, to = list.dragTo;
                        list.dragFrom = -1;
                        list.dragTo = -1;
                        if (from >= 0 && to >= 0 && from !== to) list.moveTo(from, to);
                    }
                }
            }

            Image {
                id: img
                visible: row.icon.length > 0
                anchors.left: grip.right
                anchors.verticalCenter: parent.verticalCenter
                width: visible ? 18 * list.s : 0
                height: 18 * list.s
                sourceSize: Qt.size(width * 2, height * 2)
                source: row.icon
                asynchronous: true
            }

            Column {
                anchors.left: img.right
                anchors.leftMargin: (row.icon.length > 0 ? 10 : 2) * list.s
                anchors.right: del.left
                anchors.rightMargin: 8 * list.s
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    width: parent.width
                    text: list.labelOf(row.modelData)
                    color: Theme.bright
                    font.family: Theme.font
                    font.pixelSize: 12 * list.s
                    elide: Text.ElideRight
                }
                Text {
                    visible: row.sub.length > 0
                    width: parent.width
                    text: row.sub
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 9.5 * list.s
                    elide: Text.ElideRight
                }
            }

            // remove
            Rectangle {
                id: del
                anchors.right: parent.right
                anchors.rightMargin: 5 * list.s
                anchors.verticalCenter: parent.verticalCenter
                width: 24 * list.s
                height: 24 * list.s
                radius: width / 2
                color: delArea.containsMouse ? Theme.sheen : "transparent"
                border.width: delArea.containsMouse ? 1 : 0
                border.color: Theme.verm
                GlyphIcon {
                    anchors.centerIn: parent
                    width: 11 * list.s
                    height: 11 * list.s
                    name: "close"
                    color: Theme.verm
                }
                MouseArea {
                    id: delArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: list.remove(row.index)
                }
            }
        }
    }
}
