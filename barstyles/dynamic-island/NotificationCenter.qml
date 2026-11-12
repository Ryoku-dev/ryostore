pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// iOS Notification Center: the screen frosts over (scrim in IslandWindow), a big
// lock-screen clock, then floating cards grouped into stacks by app.
// Tap a stack to open it · swipe a card left for Options / Clear · right to open it.
Item {
    id: root
    property bool shown: false
    property string screenName: ""
    property real maxHeight: 800
    property var expandedGroups: ({})
    property bool confirmClear: false

    width: 430
    height: Math.min(maxHeight, hdr.height + 14 + (Notifs.groups.length === 0 ? 140 : list.contentHeight + 30))
    opacity: shown ? 1 : 0
    visible: opacity > 0.01
    transform: [
        Translate {
            y: root.shown ? 0 : -40
            Behavior on y { SpringAnimation { spring: Theme.spring; damping: Math.min(1, Theme.damping + 0.12) } }
        },
        Scale {
            origin.x: root.width / 2
            xScale: root.shown ? 1 : 0.96
            yScale: xScale
            Behavior on xScale { SpringAnimation { spring: Theme.spring; damping: Math.min(1, Theme.damping + 0.12) } }
        }
    ]
    Behavior on opacity { NumberAnimation { duration: Theme.reduced ? 1 : 220; easing.type: Easing.OutCubic } }

    onShownChanged: { if (!shown) { confirmClear = false; expandedGroups = ({}); } else keyCatcher.forceActiveFocus(); }

    function isOpen(key) { return expandedGroups[key] === true; }
    function setOpen(key, v) { const e = Object.assign({}, expandedGroups); e[key] = v; expandedGroups = e; }

    Item {
        id: keyCatcher
        focus: true
        Keys.onEscapePressed: Notifs.centerOpen = false
    }

    // clicks on empty space close it (the scrim behind handles the rest)
    MouseArea { anchors.fill: parent; onClicked: Notifs.centerOpen = false }

    // ── lock-screen header: always white text over the frosted desktop ──
    Column {
        id: hdr
        width: parent.width
        spacing: 0

        Txt {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(Hub.now, "dddd d MMMM")
            size: 17
            weight: Font.DemiBold
            color: Qt.rgba(1, 1, 1, 0.85)
        }
        Txt {
            id: bigClock
            anchors.horizontalCenter: parent.horizontalCenter
            text: Hub.fmtClock(Hub.now, false, false)
            size: 92
            weight: Font.Bold
            font.letterSpacing: -3
            color: Qt.rgba(1, 1, 1, 0.94)
        }
        // Focus chip
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: Notifs.dnd
            height: 28
            width: focusRow.implicitWidth + 22
            radius: 14
            color: Qt.rgba(1, 1, 1, 0.16)
            Row {
                id: focusRow
                anchors.centerIn: parent
                spacing: 6
                Icon { text: "bedtime"; size: 15; fill: 1; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter }
                Txt { text: "Do Not Disturb"; size: 12.5; weight: Font.DemiBold; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Notifs.toggleDnd() }
        }
        Item { width: 1; height: 18 }

        RowLayout {
            width: parent.width
            height: 34
            Txt { Layout.fillWidth: true; Layout.leftMargin: 6; text: "Notification Center"; size: 21; weight: Font.Bold; color: "#ffffff" }
            Rectangle {
                width: 30; height: 30; radius: 15
                color: dndMa.containsMouse ? Qt.rgba(1, 1, 1, 0.26) : Qt.rgba(1, 1, 1, 0.16)
                Icon { anchors.centerIn: parent; text: Notifs.dnd ? "bedtime" : "bedtime_off"; size: 16; fill: Notifs.dnd ? 1 : 0; color: "#ffffff" }
                MouseArea { id: dndMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Notifs.toggleDnd() }
            }
            // iOS "×" that turns into "Clear"
            Rectangle {
                visible: Notifs.groups.length > 0
                height: 30
                width: root.confirmClear ? clrTxt.implicitWidth + 26 : 30
                radius: 15
                color: root.confirmClear ? Qt.rgba(1, 1, 1, 0.3) : Qt.rgba(1, 1, 1, 0.16)
                clip: true
                Behavior on width { SpringAnimation { spring: 5; damping: 0.42 } }
                Behavior on color { ColorAnimation { duration: 150 } }
                Icon { anchors.centerIn: parent; visible: !root.confirmClear; text: "close"; size: 16; weight: 700; color: "#ffffff" }
                Txt { id: clrTxt; anchors.centerIn: parent; visible: root.confirmClear; text: "Clear"; size: 13; weight: Font.DemiBold; color: "#ffffff" }
                Timer { id: clrReset; interval: 3000; onTriggered: root.confirmClear = false }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.confirmClear) { root.confirmClear = true; clrReset.restart(); return; }
                        root.confirmClear = false;
                        Notifs.clearAll();
                    }
                }
            }
        }
        Item { width: 1; height: 6 }
    }

    // ── empty state ──
    Txt {
        visible: Notifs.groups.length === 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: hdr.height + 50
        text: !Config.s.notifications ? "Notifications are turned off"
            : "No Older Notifications"
        size: 15
        weight: Font.DemiBold
        color: Qt.rgba(1, 1, 1, 0.6)
    }

    // ── stacks ──
    ListView {
        id: list
        y: hdr.height + 8
        width: parent.width
        height: root.height - y
        clip: true
        spacing: 10
        topMargin: 8
        bottomMargin: 8
        leftMargin: 0
        boundsBehavior: Flickable.DragOverBounds
        model: Notifs.groups
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 4 }
        add: Transition { NumberAnimation { properties: "opacity"; from: 0; to: 1; duration: 220 } }
        displaced: Transition { NumberAnimation { properties: "y"; duration: 260; easing.type: Easing.OutCubic } }

        delegate: Item {
            id: grp
            required property var modelData
            readonly property var g: modelData
            readonly property bool multi: g.items.length > 1
            readonly property bool open: !multi || root.isOpen(g.key)
            width: list.width
            height: open ? openCol.implicitHeight : stackTop.implicitHeight + Math.min(g.items.length - 1, 2) * 8
            Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            // collapsed stack: the newest card with slivers of the others underneath
            Item {
                anchors.fill: parent
                visible: !grp.open
                Repeater {
                    model: Math.min(grp.g.items.length - 1, 2)
                    // each sliver only draws the strip that peeks out, so nothing overlaps
                    Item {
                        required property int index
                        y: stackTop.implicitHeight + index * 8
                        width: parent.width
                        height: 8
                        clip: true
                        Glass {
                            x: (parent.index + 1) * 12
                            width: parent.width - (parent.index + 1) * 24
                            y: -28 + 8
                            height: 28
                            radius: 14
                            tint: Theme.alpha(Theme.card, Theme.card.a * (0.8 - parent.index * 0.22))
                            shadow: false
                        }
                    }
                }
                NotifCard {
                    id: stackTop
                    width: parent.width
                    notif: grp.g.items[0]
                    variant: "center"
                    onActivated: root.setOpen(grp.g.key, true)
                    onCleared: Notifs.clearGroup(grp.g)
                }
            }

            // opened stack
            Column {
                id: openCol
                width: parent.width
                visible: grp.open
                spacing: 8
                RowLayout {
                    visible: grp.multi
                    width: parent.width
                    height: 32
                    Txt { Layout.fillWidth: true; Layout.leftMargin: 6; text: grp.g.app; size: 19; weight: Font.Bold; color: "#ffffff" }
                    Rectangle {
                        height: 28; radius: 14
                        width: lessTxt.implicitWidth + 24
                        color: Qt.rgba(1, 1, 1, 0.16)
                        Txt { id: lessTxt; anchors.centerIn: parent; text: "Show less"; size: 12.5; weight: Font.DemiBold; color: "#ffffff" }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.setOpen(grp.g.key, false) }
                    }
                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: Qt.rgba(1, 1, 1, 0.16)
                        Icon { anchors.centerIn: parent; text: "close"; size: 15; weight: 700; color: "#ffffff" }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Notifs.clearGroup(grp.g) }
                    }
                }
                Repeater {
                    model: grp.open ? grp.g.items : []
                    NotifCard {
                        id: nc
                        required property var modelData
                        width: openCol.width
                        notif: modelData
                        variant: "center"
                        onActivated: Notifs.activate(nc.modelData)
                        onCleared: Notifs.dismiss(nc.modelData)
                    }
                }
            }
        }
    }
}
