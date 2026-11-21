pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray

// The tray's short form, next to the tabs in the expanded island: the first
// few apps as glass beads and one more bead that opens the full tray sheet.
//   left click   → the app's own action (a menu-only app opens its menu)
//   right click  → the app's menu, drawn inside the island
//   middle click → secondary action
//   scroll       → forwarded to the app
// Nothing here collapses the island; Esc or a click outside does.
Row {
    id: root
    property string screenName: ""
    readonly property var items: Hub.trayItems
    readonly property int shownCount: Math.min(items.length, Math.max(0, Config.s.trayInHeader))
    readonly property int count: items.length
    spacing: 4

    Repeater {
        model: root.items.slice(0, root.shownCount)
        Lens {
            id: bead
            required property var modelData
            width: 28; height: 28
            hovered: ma.containsMouse
            pressed: ma.pressed
            scale: ma.pressed ? 0.9 : 1
            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2 } }
            IconImage {
                anchors.centerIn: parent
                implicitSize: 16
                source: bead.modelData ? bead.modelData.icon : ""
            }
            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: m => Hub.trayActivate(bead.modelData, m.button)
                onWheel: w => {
                    const horiz = Math.abs(w.angleDelta.x) > Math.abs(w.angleDelta.y);
                    bead.modelData.scroll(horiz ? w.angleDelta.x : w.angleDelta.y, horiz);
                }
            }
        }
    }

    // the whole tray: "+N" when some are hidden, a chevron otherwise
    Lens {
        visible: root.count > 0
        height: 28
        width: root.count > root.shownCount ? moreTxt.implicitWidth + 18 : 28
        radius: 14
        hovered: moreMa.containsMouse
        pressed: moreMa.pressed
        Txt {
            id: moreTxt
            anchors.centerIn: parent
            visible: root.count > root.shownCount
            text: "+" + (root.count - root.shownCount)
            size: 11.5; weight: Font.DemiBold; color: Theme.fg
        }
        Icon {
            anchors.centerIn: parent
            visible: root.count <= root.shownCount
            text: "more_horiz"; size: 16; color: Theme.fg
        }
        MouseArea {
            id: moreMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Hub.openTrayList(root.screenName)
        }
    }
}
