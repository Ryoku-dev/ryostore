pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// iOS banners. A new one drops out from under the island; when it times out it
// slides back up into it. Older banners tuck behind the newest (macOS stack);
// hovering fans the stack out and pauses every timer.
Item {
    id: root
    property bool active: true
    property real originY: -60          // where banners emerge from (relative to the stack)
    readonly property bool hovered: hov.hovered
    readonly property bool fanned: hovered || live.length <= 1

    // Notification objects on screen, including ones animating out
    property var shown: []
    property var leaving: ({})
    property var heights: ({})

    function sync() {
        const cur = active ? Notifs.popups.filter(p => p) : [];
        const alive = Notifs.list;
        const next = [];
        const lv = Object.assign({}, leaving);
        for (let i = 0; i < cur.length; i++) if (shown.indexOf(cur[i]) < 0) next.push(cur[i]);
        for (let i = 0; i < shown.length; i++) {
            const n = shown[i];
            if (!n || alive.indexOf(n) < 0) continue;   // dismissed for good: gone (the object may be destroyed)
            if (cur.indexOf(n) >= 0) { delete lv[n.id]; next.push(n); }
            else { lv[n.id] = true; next.push(n); }
        }
        leaving = lv;
        shown = next;
        purge.restart();
    }
    Timer {
        id: purge
        interval: 520
        onTriggered: {
            const cur = Notifs.popups;
            root.shown = root.shown.filter(n => n && cur.indexOf(n) >= 0);
            root.leaving = ({});
        }
    }
    Connections { target: Notifs; function onPopupsChanged() { root.sync(); } }
    onActiveChanged: sync()

    readonly property var live: shown.filter(n => n && !leaving[n.id])
    function h(n) { return (n && heights[n.id]) || 72; }
    function targetY(n) {
        const idx = live.indexOf(n);
        if (idx < 0) return originY;
        if (fanned) {
            let y = 0;
            for (let i = 0; i < idx; i++) y += h(live[i]) + 8;
            return y;
        }
        // tucked: peek out below the front banner
        return h(live[0]) - h(n) + Math.min(idx, 2) * 9;
    }
    readonly property real contentHeight: {
        if (live.length === 0) return 0;
        if (fanned) { let y = 0; for (let i = 0; i < live.length; i++) y += h(live[i]) + (i ? 8 : 0); return y; }
        return h(live[0]) + Math.min(live.length - 1, 2) * 9;
    }
    height: Math.max(1, contentHeight)
    visible: shown.length > 0

    HoverHandler {
        id: hov
        onHoveredChanged: Notifs.hovering = hovered
    }

    // "N more" pill under a tucked stack
    Rectangle {
        visible: opacity > 0.01
        opacity: !root.fanned && root.live.length > 1 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.contentHeight + 6
        height: 20; radius: 10
        width: moreTxt.implicitWidth + 16
        color: Theme.card
        Txt { id: moreTxt; anchors.centerIn: parent; text: (root.live.length - 1) + " more"; size: 11; weight: Font.DemiBold; color: Theme.fg2 }
    }

    // slivers of the tucked banners peeking out under the front one
    Repeater {
        model: !root.fanned ? Math.min(2, root.live.length - 1) : 0
        Item {
            required property int index
            y: root.h(root.live[0]) + index * 9
            z: 200
            width: root.width
            height: 9
            clip: true
            Glass {
                x: (parent.index + 1) * 14
                width: parent.width - (parent.index + 1) * 28
                y: -30 + 9
                height: 30
                radius: 15
                tint: Theme.alpha(Theme.card, Theme.card.a * (0.85 - parent.index * 0.25))
                shadow: false
            }
        }
    }

    Repeater {
        model: ScriptModel { values: root.shown }
        Item {
            id: slot
            required property var modelData
            readonly property var n: modelData
            readonly property int idx: root.live.indexOf(n)
            readonly property bool out: idx < 0
            property bool entered: false
            property bool swiped: false        // the card already flew away by itself
            Component.onCompleted: Qt.callLater(() => slot.entered = true)

            width: root.width
            height: card.implicitHeight
            z: 100 - Math.max(0, idx)
            y: !entered || (out && !swiped) ? root.originY : root.targetY(n)
            // tucked banners hide behind the slivers below (glass is translucent, so no overlap)
            opacity: !entered || out ? 0 : (root.fanned || idx === 0 ? 1 : 0)
            scale: !entered || (out && !swiped) ? 0.82 : (root.fanned ? 1 : 1 - Math.min(idx, 2) * 0.05)
            transformOrigin: Item.Top
            Behavior on y { SpringAnimation { spring: Theme.spring; damping: Math.min(1, Theme.damping + 0.1); epsilon: 0.3 } }
            Behavior on opacity { NumberAnimation { duration: slot.out ? 200 : 260; easing.type: Easing.OutCubic } }
            Behavior on scale { SpringAnimation { spring: Theme.spring; damping: Math.min(1, Theme.damping + 0.14) } }

            onHeightChanged: {
                if (!slot.n) return;
                const hs = Object.assign({}, root.heights);
                hs[slot.n.id] = height;
                root.heights = hs;
            }

            NotifCard {
                id: card
                width: parent.width
                notif: slot.n
                variant: "banner"
                enabled: !slot.out && (root.fanned || slot.idx === 0)
                onActivated: Notifs.activate(slot.n)
                onHidden: { slot.swiped = true; Notifs.hide(slot.n); }
                onCleared: { slot.swiped = true; Notifs.dismiss(slot.n); }
            }
        }
    }
}
