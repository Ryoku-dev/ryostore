pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Ryoku.Ui.Singletons
import "Singletons"

/**
 * Workspace dots for one monitor. No numbers, no icons. Active one is a larger
 * filled vermillion dot; the rest are small and dim, brightening on hover.
 * Clicking a dot focuses that workspace through the shell's window-manager
 * facade. Active marker tracks the monitor's live active workspace name from the
 * same model.
 *
 * The dot range unions the workspaces this monitor holds ([[Workspacerules]])
 * with the ones the compositor currently has on it, so a split setup shows every
 * dot its screen owns while a workspace outside that set (one past the last
 * named slot) still appears instead of vanishing from the strip.
 *
 * Workspace identity is resolved through [[Workspacerules.workspaceKey]]
 * rather than read straight off [[name]]: Hyprland names a workspace after
 * its numeric id, but niri workspaces are usually unnamed and are otherwise
 * identified by their per-output position or global id. Using the same
 * fallback everywhere here (range, active detection, click targeting) keeps
 * the strip populated and the active dot correct on both.
 */
Item {
    id: workspaces

    property string screenName: ""
    property real s: 1
    property real stickW: 17 * s
    property real dotW: 5 * s
    property real gap: 4 * s

    readonly property var range: {
        var out = [];
        var seen = ({});
        var ruled = Workspacerules.byMonitor[screenName];
        if (ruled && ruled.length) {
            for (var r = 0; r < ruled.length; r++) {
                if (!seen[ruled[r]]) {
                    seen[ruled[r]] = true;
                    out.push(ruled[r]);
                }
            }
        }

        var wss = Wm.workspaces;
        for (var i = 0; i < wss.length; i++) {
            var w = wss[i];
            if (w.special === true || w.output !== screenName)
                continue;
            var id = Workspacerules.workspaceKey(w);
            if (id !== null && !seen[id]) {
                seen[id] = true;
                out.push(id);
            }
        }
        if (activeKey !== null && !seen[activeKey])
            out.push(activeKey);
        out.sort(function (x, y) { return x - y; });
        return out;
    }

    readonly property var activeKey: Workspacerules.activeKeyFor(screenName)
    readonly property string activeName: activeKey !== null ? String(activeKey) : ""

    property int hoverIndex: -1

    readonly property int activeIndex: activeKey !== null ? range.indexOf(activeKey) : -1

    /**
     * Centre x of a dot slot from target layout widths (active stick is wider).
     * Uses the animation end values, so a focus marker aimed here lands where
     * the dot settles and doesn't chase the width Behavior.
     */
    function slotCenterX(idx) {
        let x = 0;
        for (let i = 0; i < idx; i++)
            x += (i === activeIndex ? stickW : dotW) + gap;
        return x + (idx === activeIndex ? stickW : dotW) / 2;
    }

    readonly property point activeDotPoint: {
        void workspaces.activeName;
        void workspaces.width;
        return Qt.point(slotCenterX(Math.max(0, activeIndex)), height / 2);
    }

    /**
     * [[range]] is a freshly-built JS array on every recompute, and a plain
     * array model gives Repeater no way to tell "the same dots, one value
     * changed" apart from "a different set of dots" -- any change to its
     * value destroys and recreates every delegate from scratch, which skips
     * the width [[Behavior]] entirely (there is nothing to transition from
     * on a brand new item). Hyprland rarely notices because its workspace
     * set is stable across a plain focus switch; niri keeps one empty
     * trailing workspace per output and garbage-collects it as you leave,
     * so the set itself churns on nearly every switch. Mirroring [[range]]
     * into this ListModel with a targeted insert/remove diff -- instead of
     * handing Repeater the array directly -- keeps untouched dots' delegate
     * items alive (and animating) and only pops the genuinely added/removed
     * one in or out.
     */
    ListModel { id: wsModel }

    function syncWsModel() {
        var target = workspaces.range;
        for (var i = wsModel.count - 1; i >= 0; i--) {
            if (target.indexOf(wsModel.get(i).wsId) === -1)
                wsModel.remove(i);
        }
        for (var j = 0; j < target.length; j++) {
            var id = target[j];
            var present = false;
            for (var k = 0; k < wsModel.count; k++) {
                if (wsModel.get(k).wsId === id) {
                    present = true;
                    break;
                }
            }
            if (!present)
                wsModel.insert(j, { wsId: id });
        }
    }

    onRangeChanged: syncWsModel()
    Component.onCompleted: syncWsModel()

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: workspaces.gap

        Repeater {
            model: wsModel

            delegate: Item {
                id: slot

                required property int wsId
                required property int index

                readonly property string wsName: String(wsId)
                readonly property bool isActive: workspaces.activeName === wsName

                Layout.preferredWidth: slot.isActive ? workspaces.stickW : workspaces.dotW
                Layout.preferredHeight: 22 * workspaces.s
                Behavior on Layout.preferredWidth { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: workspaces.dotW
                    radius: height / 2
                    color: slot.isActive ? Theme.vermLit : Theme.cream
                    opacity: slot.isActive ? 1.0 : (area.containsMouse ? 0.7 : 0.3)
                    Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    anchors.leftMargin: -workspaces.gap / 2
                    anchors.rightMargin: -workspaces.gap / 2
                    anchors.topMargin: -8 * workspaces.s
                    anchors.bottomMargin: -8 * workspaces.s
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // Same resolved key used to build the range and match the
                    // active dot (see the file doc comment), so an unnamed
                    // niri workspace is targeted by its idx/id instead of a
                    // blank name.
                    onClicked: Wm.focusWorkspace(slot.wsName)
                    onContainsMouseChanged: {
                        if (containsMouse)
                            workspaces.hoverIndex = slot.index;
                        else if (workspaces.hoverIndex === slot.index)
                            workspaces.hoverIndex = -1;
                    }
                }
            }
        }
    }
}
