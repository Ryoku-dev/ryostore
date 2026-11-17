pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray

// System tray (StatusNotifierItem) icons for the expanded island header.
// Discreet: small, dimmed icons that brighten on hover. With more than
// `collapsedMax` items only the first few show plus a "+N" chip; hovering the
// strip slides the rest out.
//   left click   → activate (or open the menu if the app only has a menu)
//   right click  → app menu
//   middle click → secondary activate
//   scroll       → forwarded to the app; scrolls the strip when it overflows
Item {
    id: root
    property real maxWidth: 130
    property real iconSize: 16
    property int collapsedMax: 3
    readonly property int count: SystemTray.items.values.length
    readonly property real slotSize: 26
    readonly property bool overflow: count > collapsedMax
    readonly property bool open: hov.hovered || !overflow
    signal activated()   // an item was clicked, so the island can collapse

    implicitHeight: slotSize
    implicitWidth: Math.min(maxWidth, list.width + (moreChip.visible ? moreChip.width + 2 : 0))

    HoverHandler { id: hov }

    ListView {
        id: list
        height: parent.height
        width: Math.min(root.maxWidth, root.open ? contentWidth : root.collapsedMax * (root.slotSize + spacing) - spacing)
        Behavior on width { NumberAnimation { duration: Theme.reduced ? 1 : 260; easing.type: Easing.OutCubic } }
        orientation: ListView.Horizontal
        spacing: 1
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentWidth > width + 1
        model: SystemTray.items
        opacity: hov.hovered ? 1 : 0.6
        Behavior on opacity { NumberAnimation { duration: 180 } }

        delegate: Item {
            id: slot
            required property SystemTrayItem modelData
            width: root.slotSize
            height: root.slotSize

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Theme.fill2
                opacity: ma.containsMouse ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }
            IconImage {
                anchors.centerIn: parent
                implicitSize: root.iconSize
                source: slot.modelData ? slot.modelData.icon : ""
                scale: ma.pressed ? 0.85 : 1
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
            }

            function openMenu() {
                if (!modelData.hasMenu) return;
                const p = slot.mapToItem(null, 0, slot.height + 6);
                modelData.display(QsWindow.window, Math.round(p.x), Math.round(p.y));
            }

            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: m => {
                    const it = slot.modelData;
                    if (m.button === Qt.RightButton) { slot.openMenu(); return; }
                    if (m.button === Qt.MiddleButton) { it.secondaryActivate(); root.activated(); return; }
                    if (it.onlyMenu) { slot.openMenu(); return; }
                    it.activate();
                    root.activated();
                }
                onWheel: w => {
                    if (list.interactive) { w.accepted = false; return; }
                    const horiz = Math.abs(w.angleDelta.x) > Math.abs(w.angleDelta.y);
                    slot.modelData.scroll(horiz ? w.angleDelta.x : w.angleDelta.y, horiz);
                }
            }
        }
    }

    // "+N" chip while collapsed; hovering the strip reveals the rest
    Rectangle {
        id: moreChip
        visible: root.overflow && !root.open
        anchors.left: list.right
        anchors.leftMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        height: 18
        width: moreTxt.implicitWidth + 10
        radius: 9
        color: Theme.fill2
        opacity: 0.8
        Txt { id: moreTxt; anchors.centerIn: parent; text: "+" + (root.count - root.collapsedMax); size: 10; weight: Font.DemiBold; color: Theme.fg2 }
    }
}
