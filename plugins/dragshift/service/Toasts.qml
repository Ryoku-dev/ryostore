pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

// The result cards, stacked bottom-right of the screen the menu was on, like
// DragShift's ToastStack: the oldest at the bottom, 10 px apart, 18 px from the
// edges. Hyprland blurs behind the "dragshift-toasts" layer (user.lua), the
// cards draw the rest. A card lives 6.5 s after it finishes (9 s for an error),
// pauses while hovered, and leaves 2.5 s after the pointer does.
Scope {
    id: toasts

    property var screen: null
    property string binPath: ""          // bin/dragshift, for Undo and Show in folder
    property string engineDir: ""
    signal undoRequested(int cid, var outs)

    property int _next: 1
    ListModel { id: cards }

    // ---- API ---------------------------------------------------------------
    function working(title, detail) {
        const cid = toasts._next++;
        cards.append({ cid: cid, st: "working", title: title, detail: detail || "", good: "", thumb: "", outs: "[]" });
        return cid;
    }
    function done(cid, reply) {
        const i = _index(cid);
        const d = reply || {};
        const fields = d.ok
            ? { st: "done", title: d.title || "Done", detail: d.detail || "", good: d.good || "",
                thumb: _thumb(d.outs || []), outs: JSON.stringify(d.outs || []) }
            : { st: "error", title: "Couldn't finish", detail: d.error || "Something went wrong", good: "", thumb: "", outs: "[]" };
        if (i < 0)
            cards.append(Object.assign({ cid: toasts._next++ }, fields));
        else
            cards.set(i, fields);
    }
    function info(cid, title, detail) {
        const i = _index(cid);
        const fields = { st: "info", title: title, detail: detail || "", good: "", thumb: "", outs: "[]" };
        if (i < 0)
            cards.append(Object.assign({ cid: toasts._next++ }, fields));
        else
            cards.set(i, fields);
    }
    function dismiss(cid) {
        const i = _index(cid);
        if (i >= 0)
            cards.remove(i);
    }

    function _index(cid) {
        for (let i = 0; i < cards.count; i++)
            if (cards.get(i).cid === cid)
                return i;
        return -1;
    }
    function _thumb(outs) {
        for (const o of outs)
            if (/\.(png|jpe?g|webp|bmp|gif|tiff?|avif|ico)$/i.test(o))
                return o;
        return "";
    }
    function _act(cid, name, outsJson) {
        const outs = JSON.parse(outsJson || "[]");
        if (name === "close") {
            dismiss(cid);
        } else if (name === "open" && outs.length > 0) {
            Quickshell.execDetached(["xdg-open", outs[0]]);
            dismiss(cid);
        } else if ((name === "show" || name === "body") && outs.length > 0 && toasts.binPath) {
            Quickshell.execDetached([toasts.binPath, "--engine", toasts.engineDir, "reveal", outs[0]]);
            dismiss(cid);
        } else if (name === "undo" && outs.length > 0) {
            toasts.undoRequested(cid, outs);
        }
    }

    // ---- the window ----------------------------------------------------------
    readonly property real cw: 380
    readonly property real ch: 104
    readonly property real gap: 10

    PanelWindow {
        id: win
        visible: cards.count > 0
        screen: toasts.screen
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "dragshift-toasts"
        exclusiveZone: 0
        anchors { bottom: true; right: true }
        margins { bottom: 18; right: 18 }
        implicitWidth: toasts.cw
        implicitHeight: Math.max(1, cards.count * (toasts.ch + toasts.gap) - toasts.gap)
        mask: Region { item: stack }

        Item {
            id: stack
            anchors.fill: parent

            Repeater {
                model: cards
                delegate: Item {
                    id: slot
                    required property int index
                    required property int cid
                    required property string st
                    required property string title
                    required property string detail
                    required property string good
                    required property string thumb
                    required property string outs

                    width: toasts.cw
                    height: toasts.ch
                    // the oldest card sits at the bottom
                    y: win.implicitHeight - (slot.index + 1) * (toasts.ch + toasts.gap) + toasts.gap
                    Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    opacity: 0
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    CardView {
                        id: view
                        state_: slot.st
                        title: slot.title
                        detail: slot.detail
                        good: slot.good
                        thumb: slot.thumb
                        hasOuts: slot.outs !== "[]"
                        onAct: (name) => toasts._act(slot.cid, name, slot.outs)
                        onHoveredChanged: {
                            if (hovered)
                                life.stop();
                            else if (slot.st !== "working")
                                life.go(slot.st === "error" ? 4000 : 2500);
                        }
                    }

                    Timer {
                        id: life
                        function go(ms) { interval = ms; restart(); }
                        onTriggered: toasts.dismiss(slot.cid)
                    }
                    function arm() {
                        if (slot.st === "working" || view.hovered)
                            return;
                        life.go(slot.st === "error" ? 9000 : slot.st === "info" ? 2500 : 6500);
                    }
                    onStChanged: arm()
                    Component.onCompleted: { opacity = 1; arm(); }
                    Component.onDestruction: life.stop()
                }
            }
        }
    }
}
