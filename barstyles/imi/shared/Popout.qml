pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import shell.services
import ".."

Item {
    id: root

    property Item target: null
    property bool targetHovered: false
    property real barHeight: 48
    property string namespace: "ryoku-bar-popout"
    property Component content: null
    property bool cardHovered: false
    property bool shown: false
    property real preferredWidth: 280
    property real preferredHeight: 200
    property real lastMappedX: 200

    function isTargetActuallyVisible() {
        if (!root.target) return false;
        let curr = root.target;
        while (curr) {
            if (curr.visible === false || curr.opacity === 0) return false;
            curr = curr.parent;
        }
        return true;
    }

    readonly property bool wantOpen: (root.targetHovered || root.cardHovered)
        && root.target !== null
        && root.content !== null
        && isTargetActuallyVisible()

    function getMappedX(cardWidth) {
        if (!root.target || !isTargetActuallyVisible()) return 200;
        const targetWidth = (root.target.width > 0 ? root.target.width : (root.target.implicitWidth || 40));
        const w = (cardWidth > 0 ? cardWidth : (root.preferredWidth || 280));

        try {
            if (typeof root.target.mapToItem === "function") {
                const pt = root.target.mapToItem(null, targetWidth / 2, 0);
                if (pt && !isNaN(pt.x) && pt.x > 30) {
                    return pt.x - (w / 2);
                }
            }
        } catch (e) {}

        let gx = 0;
        let curr = root.target;
        while (curr) {
            if (curr.x !== undefined && !isNaN(curr.x)) {
                gx += curr.x;
            }
            curr = curr.parent;
        }

        const center = gx + (targetWidth / 2);
        return center - (w / 2);
    }

    function closeImmediately() {
        closeTimer.stop();
        root.shown = false;
        root.cardHovered = false;
        if (GlobalStates.activeBarPopup === root) {
            GlobalStates.activeBarPopup = null;
        }
    }

    onWantOpenChanged: {
        if (root.wantOpen) {
            closeTimer.stop();
            const mx = root.getMappedX(root.preferredWidth + 24);
            if (mx > 30) {
                root.lastMappedX = mx;
            }
            root.shown = true;
            GlobalStates.activeBarPopup = root;
        } else {
            closeTimer.restart();
        }
    }

    Timer {
        id: closeTimer
        interval: 180
        onTriggered: {
            if (!root.wantOpen) {
                root.shown = false;
                if (GlobalStates.activeBarPopup === root) {
                    GlobalStates.activeBarPopup = null;
                }
            }
        }
    }
}
