pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell.Widgets

// One Apple-style notification.
//   banner  – glass banner under the island. Swipe up or sideways to put it away
//             (it stays in the Notification Center), pull down or click ⌄ to expand.
//   center  – card in the Notification Center. Swipe left for Options / Clear,
//             all the way left to clear, right to open.
//   island  – bare content shown inside the island itself.
// Expanded notifications show the full text plus an iOS-style action menu and inline reply.
Item {
    id: root
    property var notif: null
    property string variant: "banner"
    property bool showActions: false             // island variant: hover expands
    property bool expanded: false
    readonly property bool open: bare ? showActions : expanded
    readonly property bool hovered: hov.hovered
    signal hidden()       // banner swiped away → goes to the Notification Center
    signal cleared()      // removed for good
    signal activated()    // clicked / default action

    readonly property bool isBanner: variant === "banner"
    readonly property bool isCenter: variant === "center"
    readonly property bool bare: variant === "island"
    readonly property bool crit: Notifs.critical(notif)
    readonly property string img: Notifs.image(notif)
    readonly property string icon: Notifs.appIcon(notif)
    readonly property var acts: Notifs.buttons(notif)
    readonly property bool canReply: notif !== null && notif.hasInlineReply === true
    readonly property bool message: Notifs.isMessage(notif)
    readonly property bool avatar: img !== "" && (message || !appIco.ok)
    readonly property bool thumb: img !== "" && !avatar
    readonly property bool expandable: acts.length > 0 || canReply || bodyTxt.truncated || expanded
    readonly property bool menuShown: open && (acts.length > 0 || canReply)
    readonly property real pad: bare ? 0 : 12

    implicitHeight: card.height + (menuShown ? menu.implicitHeight + 8 : 0)
    Behavior on implicitHeight { NumberAnimation { duration: Theme.reduced ? 1 : 260; easing.type: Easing.OutCubic } }

    // An open banner (actions / reply showing) holds the countdown. The lease
    // is keyed to this notification and dropped when the card goes away.
    readonly property string nid: notif ? String(notif.id) : ""
    readonly property bool holdingOpen: isBanner && expanded && visible
    onHoldingOpenChanged: if (nid !== "") Notifs.setHold("expand:" + nid, holdingOpen)
    Component.onDestruction: if (nid !== "") { Notifs.setHold("expand:" + nid, false); Notifs.setHold("reply:" + nid, false); }

    // ═══════════════════════ GESTURES ═══════════════════════
    property real dragX: 0
    property real dragY: 0
    property string axis: ""
    property bool leaving: false
    property bool flyClear: false
    property bool revealed: false
    readonly property real revealW: (acts.length > 0 ? 82 : 0) + 82

    function leave(dx, dy, clear) {
        if (leaving) return;
        leaving = true;
        flyClear = clear;
        back.stop();
        flyX.to = dx;
        flyY.to = dy;
        fly.start();
    }
    ParallelAnimation {
        id: fly
        NumberAnimation { id: flyX; target: root; property: "dragX"; duration: 250; easing.type: Easing.InCubic }
        NumberAnimation { id: flyY; target: root; property: "dragY"; duration: 250; easing.type: Easing.InCubic }
        onFinished: root.flyClear ? root.cleared() : root.hidden()
    }
    ParallelAnimation {
        id: back
        NumberAnimation { target: root; property: "dragX"; to: root.revealed ? -root.revealW : 0; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.05 }
        NumberAnimation { target: root; property: "dragY"; to: 0; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.05 }
    }
    function settle() {
        const w = width;
        if (isBanner) {
            if (axis === "y" && dragY < -34) { leave(0, -(card.height + 40), false); return; }
            if (axis === "y" && dragY > 26 && expandable) expanded = true;
            if (axis === "x" && Math.abs(dragX) > Math.min(110, w * 0.28)) { leave((dragX > 0 ? 1 : -1) * (w + 60), 0, false); return; }
        } else if (isCenter) {
            if (dragX < -w * 0.62) { leave(-(w + 60), 0, true); return; }
            if (dragX > w * 0.3) { revealed = false; axis = ""; back.restart(); activated(); return; }
            revealed = dragX < -44;
        }
        axis = "";
        back.restart();
    }
    function closeReveal() { if (revealed) { revealed = false; back.restart(); } }

    HoverHandler { id: hov }

    // ── iOS "swipe left" buttons behind the card ──
    component RevealBtn: Item {
        id: rvb
        property string label: ""
        property color tint: "#ffffff"
        property bool tinted: false
        property color textColor: Theme.fg
        signal clicked()
        width: 74
        Lens {
            anchors.fill: parent
            radius: 20
            tint: rvb.tint
            tintAmount: rvb.tinted ? 0.85 : 0
            hovered: rvbMa.containsMouse
            pressed: rvbMa.pressed
            Txt { anchors.centerIn: parent; text: rvb.label; size: 13.5; weight: Font.DemiBold; color: rvb.textColor }
        }
        scale: rvbMa.pressed ? 0.94 : 1
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
        MouseArea { id: rvbMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: rvb.clicked() }
    }
    Row {
        id: revealRow
        visible: root.isCenter && root.dragX < -2
        anchors.right: parent.right
        spacing: 8
        opacity: Math.min(1, -root.dragX / Math.max(1, root.revealW))
        scale: 0.85 + 0.15 * opacity
        RevealBtn {
            visible: root.acts.length > 0
            height: card.height
            label: "Options"
            onClicked: { root.revealed = false; back.restart(); root.expanded = true; }
        }
        RevealBtn {
            height: card.height
            label: "Clear"
            tint: Theme.red
            tinted: true
            onClicked: root.leave(-(root.width + 60), 0, true)
        }
    }

    // ═══════════════════════ CARD ═══════════════════════
    Item {
        id: card
        width: root.width
        height: content.implicitHeight + root.pad * 2
        x: root.dragX
        y: root.isBanner ? root.dragY : 0
        opacity: !root.isBanner ? 1
            : 1 - Math.min(0.9, Math.max(Math.abs(root.dragX) / (root.width * 0.9), -root.dragY / (height * 1.3)))
        scale: root.isBanner && root.dragY > 0 ? 1 + root.dragY / 1200 : 1
        Behavior on height { NumberAnimation { duration: Theme.reduced ? 1 : 260; easing.type: Easing.OutCubic } }

        // glass controls on this card refract the card itself
        property var glassSource: null
        property Item glassSpace: null
        property color glassBase: root.bare ? Theme.surface : Theme.card

        Surface {
            anchors.fill: parent
            visible: !root.bare
            radius: root.isBanner ? 24 : 22
            color: Theme.card
            shadowBlur: root.isBanner ? 28 : 16
            shadowY: root.isBanner ? 9 : 4
            glowColor: Theme.red
            glowStrength: root.crit && Config.s.glow ? 0.32 : 0
        }

        TapHandler {
            enabled: !root.leaving
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onTapped: (pt, button) => {
                if (root.revealed) { root.closeReveal(); return; }
                if (button === Qt.RightButton) { if (root.expandable && !root.bare) root.expanded = !root.expanded; return; }
                root.activated();
            }
        }
        DragHandler {
            id: drag
            target: null
            enabled: !root.bare && !root.leaving
            yAxis.enabled: root.isBanner
            property real startX: 0
            onActiveChanged: {
                if (active) { back.stop(); startX = root.dragX; root.axis = ""; }
                else root.settle();
            }
            onActiveTranslationChanged: {
                if (!active) return;
                const t = activeTranslation;
                if (root.axis === "") {
                    if (Math.abs(t.x) < 6 && Math.abs(t.y) < 6) return;
                    root.axis = root.isBanner && Math.abs(t.y) > Math.abs(t.x) ? "y" : "x";
                }
                if (root.axis === "y") root.dragY = t.y < 0 ? t.y : t.y * 0.35;   // rubber-band downwards
                else {
                    let x = startX + t.x;
                    if (root.isCenter && x > 0) x *= 0.55;
                    root.dragX = x;
                }
            }
        }
        // two-finger touchpad swipe
        WheelHandler {
            enabled: !root.bare && !root.leaving
            orientation: Qt.Horizontal
            onWheel: e => {
                const dx = e.pixelDelta.x !== 0 ? e.pixelDelta.x : e.angleDelta.x / 4;
                if (dx === 0) return;
                back.stop();
                root.axis = "x";
                root.dragX -= dx;
                wheelIdle.restart();
            }
        }
        Timer { id: wheelIdle; interval: 140; onTriggered: root.settle() }

        Item {
            id: content
            x: root.pad + (root.bare ? 0 : 2)
            y: root.pad
            width: card.width - x * 2
            implicitHeight: Math.max(iconBox.height, textCol.implicitHeight)

            // App icon — or a contact picture with a small app badge (Messages style)
            Item {
                id: iconBox
                width: 38; height: 38
                AppIcon {
                    id: appIco
                    visible: !root.avatar
                    anchors.fill: parent
                    size: 38
                    source: root.icon
                    fallback: root.crit ? "warning" : "notifications"
                    fallbackColor: root.crit ? Theme.red : Theme.accent
                }
                ClippingRectangle {
                    visible: root.avatar
                    anchors.fill: parent
                    radius: width / 2
                    color: Theme.fill2
                    Image {
                        anchors.fill: parent
                        source: root.avatar ? root.img : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 96
                        sourceSize.height: 96
                    }
                }
                Rectangle {
                    visible: root.avatar && appIco.ok
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: -4
                    width: 20; height: 20; radius: 6
                    color: "#2c2c2e"
                    AppIcon { anchors.centerIn: parent; size: 16; source: root.icon }
                }
            }

            Column {
                id: textCol
                anchors.left: iconBox.right
                anchors.leftMargin: 11
                anchors.right: thumbBox.visible ? thumbBox.left : parent.right
                anchors.rightMargin: thumbBox.visible ? 10 : 0
                spacing: 1

                Row {
                    visible: root.crit
                    spacing: 3
                    Icon { text: "schedule"; size: 11; weight: 700; color: Theme.orange; anchors.verticalCenter: parent.verticalCenter }
                    Txt { text: "TIME SENSITIVE"; size: 10; weight: Font.Bold; color: Theme.orange; font.letterSpacing: 0.4 }
                }
                Item {
                    width: parent.width
                    height: titleTxt.implicitHeight
                    Txt {
                        id: titleTxt
                        anchors.left: parent.left
                        anchors.right: meta.left
                        anchors.rightMargin: 8
                        text: Notifs.title(root.notif)
                        size: 14.5
                        weight: Font.DemiBold
                    }
                    Item {
                        id: meta
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(ageTxt.implicitWidth, chev.visible ? chev.width : 0)
                        height: ageTxt.implicitHeight
                        readonly property bool chevOn: !root.bare && root.expandable && (root.hovered || root.expanded)
                        Txt {
                            id: ageTxt
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: Notifs.age(root.notif)
                            size: 12.5
                            weight: Font.Normal
                            color: Theme.fg2
                            opacity: meta.chevOn ? 0 : 1
                            Behavior on opacity { NumberAnimation { duration: 140 } }
                        }
                        Rectangle {
                            id: chev
                            visible: opacity > 0.01
                            opacity: meta.chevOn ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 140 } }
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 24; height: 24; radius: 12
                            color: chevMa.containsMouse ? Theme.fill3 : Theme.fill2
                            Icon {
                                anchors.centerIn: parent
                                text: "expand_more"
                                size: 17
                                weight: 600
                                color: Theme.fg2
                                rotation: root.expanded ? 180 : 0
                                Behavior on rotation { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                            }
                            MouseArea {
                                id: chevMa
                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.expanded = !root.expanded
                            }
                        }
                    }
                }
                Txt {
                    id: bodyTxt
                    width: parent.width
                    visible: text !== ""
                    text: Notifs.body(root.notif)
                    size: 14
                    weight: Font.Normal
                    color: Theme.fg
                    wrapMode: Text.Wrap
                    maximumLineCount: root.open ? 14 : root.bare ? 2 : root.isBanner ? 3 : 4
                    lineHeight: 1.06
                }
            }

            // image attachment (iOS puts it on the right)
            ClippingRectangle {
                id: thumbBox
                visible: root.thumb
                anchors.right: parent.right
                anchors.top: parent.top
                width: 40; height: 40; radius: 9
                color: Theme.fill2
                Image {
                    anchors.fill: parent
                    source: root.thumb ? root.img : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 96
                    sourceSize.height: 96
                }
            }
        }

        // close button, a small glass bead on the corner
        Lens {
            visible: opacity > 0.01
            opacity: !root.bare && hov.hovered && !root.leaving && !root.revealed ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
            x: -7; y: -7
            width: 24; height: 24
            base: "#1c1c1e"
            hovered: closeMa.containsMouse
            pressed: closeMa.pressed
            Icon { anchors.centerIn: parent; text: "close"; size: 13; weight: 700; color: Theme.fg }
            MouseArea {
                id: closeMa
                anchors.fill: parent
                anchors.margins: -3
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.cleared()
            }
        }
    }

    // ═══════════════ iOS action menu + inline reply ═══════════════
    Column {
        id: menu
        x: card.x
        y: card.y + card.height + 8
        width: root.width
        spacing: 8
        opacity: root.menuShown ? 1 : 0
        scale: root.menuShown ? 1 : 0.94
        transformOrigin: Item.Top
        visible: opacity > 0.01
        enabled: root.menuShown
        Behavior on opacity { NumberAnimation { duration: Theme.reduced ? 1 : 200 } }
        Behavior on scale { NumberAnimation { duration: Theme.reduced ? 1 : 300; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }

        // reply
        Item {
            visible: root.canReply
            width: parent.width
            height: 42
            Surface {
                anchors.fill: parent
                radius: 21
                color: root.bare ? Theme.fill2 : Theme.card
                shadow: !root.bare
                shadowBlur: 16; shadowY: 4
            }
            TextField {
                id: reply
                anchors.left: parent.left
                anchors.right: send.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 6
                anchors.rightMargin: 4
                leftPadding: 10
                placeholderText: root.notif && root.notif.inlineReplyPlaceholder ? root.notif.inlineReplyPlaceholder : "Reply…"
                placeholderTextColor: Theme.fg3
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: 14
                selectionColor: Theme.accent
                background: Item {}
                onActiveFocusChanged: if (root.nid !== "") Notifs.setHold("reply:" + root.nid, activeFocus)
                onAccepted: send.go()
            }
            Lens {
                id: send
                anchors.right: parent.right
                anchors.rightMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                width: 32; height: 32
                readonly property bool ready: reply.text.trim() !== ""
                tint: Theme.accent
                tintAmount: ready ? 0.9 : 0
                Behavior on tintAmount { NumberAnimation { duration: 150 } }
                hovered: sendMa.containsMouse
                pressed: sendMa.pressed
                Icon { anchors.centerIn: parent; text: "arrow_upward"; size: 18; weight: 700; color: send.ready ? Theme.accentText : Theme.fg3 }
                function go() {
                    if (!ready || !root.notif) return;
                    root.notif.sendInlineReply(reply.text);
                    reply.text = "";
                    if (root.nid !== "") Notifs.setHold("reply:" + root.nid, false);
                    root.expanded = false;
                    Notifs.removePopup(root.notif);
                }
                MouseArea { id: sendMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: send.go() }
            }
        }

        // actions
        Item {
            visible: root.acts.length > 0
            width: parent.width
            height: actCol.implicitHeight
            Surface {
                anchors.fill: parent
                radius: 18
                color: root.bare ? Theme.fill2 : Theme.card
                shadow: !root.bare
                shadowBlur: 16; shadowY: 4
            }
            Column {
                id: actCol
                width: parent.width
                Repeater {
                    model: root.acts
                    Item {
                        id: act
                        required property var modelData
                        required property int index
                        width: actCol.width
                        height: 44
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: 14
                            color: actMa.pressed ? Theme.fill3 : actMa.containsMouse ? Theme.fill : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                        Rectangle { visible: act.index > 0; x: 16; width: parent.width - 32; height: 0.5; color: Theme.sep }
                        Txt {
                            x: 18
                            width: parent.width - 36
                            anchors.verticalCenter: parent.verticalCenter
                            text: act.modelData.text
                            size: 14.5
                            weight: Font.Normal
                        }
                        MouseArea {
                            id: actMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                act.modelData.invoke();
                                root.expanded = false;
                                Notifs.removePopup(root.notif);
                            }
                        }
                    }
                }
            }
        }
    }
}
