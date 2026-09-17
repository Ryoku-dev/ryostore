pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.Ui.Singletons
import shell.services

// Obi workspaces: a centred row of kanji numerals, one per live workspace. The
// focused one is a filled pill, occupied ones read solid, empty ones dim. Click
// switches; wheel cycles. This is the bar's centre piece.
//
// The row reads the shell's window-manager facade, so it follows whichever
// workspace model the running compositor offers instead of assuming a fixed
// numbered set.
Item {
    id: root

    property real slot: 26
    readonly property var kanji: ["", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]

    readonly property var entries: {
        const list = Wm.workspaces || [];
        const out = [];
        for (let i = 0; i < list.length; i++) {
            const w = list[i];
            if (!w || w.special === true)
                continue;
            out.push(String(w.name));
        }
        if (out.length === 0 && Wm.focusedWorkspace)
            out.push(String(Wm.focusedWorkspace.name));
        out.sort((a, b) => {
            const an = Number(a), bn = Number(b);
            if (!isNaN(an) && !isNaN(bn))
                return an - bn;
            return a.localeCompare(b);
        });
        return out;
    }

    function label(name) {
        const id = Number(name);
        return (Math.floor(id) === id && id >= 1 && id <= 10) ? root.kanji[id] : String(name);
    }

    implicitWidth: rowr.implicitWidth
    implicitHeight: root.slot

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: e => Wm.cycleWorkspace(e.angleDelta.y > 0 ? -1 : 1)
    }

    Row {
        id: rowr
        anchors.centerIn: parent
        spacing: 3

        Repeater {
            model: root.entries

            delegate: Rectangle {
                id: cell
                required property var modelData
                readonly property string wsName: String(cell.modelData)
                readonly property var ws: Wm.workspaceByName(cell.wsName)
                readonly property bool active: Wm.focusedWorkspace !== null
                    && Wm.focusedWorkspace.name === cell.wsName
                readonly property bool occ: !cell.active && !!cell.ws && cell.ws.occupied === true

                width: root.slot
                height: root.slot
                radius: root.slot / 2
                color: cell.active ? Theme.primary
                    : cell.occ ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.10)
                    : "transparent"
                Behavior on color { ColorAnimation { duration: Motion.fast } }

                Text {
                    anchors.centerIn: parent
                    text: root.label(cell.wsName)
                    color: cell.active ? Theme.onPrimary : (cell.occ ? Theme.onSurface : Theme.onSurfaceVariant)
                    font.family: Theme.fontJp
                    font.pixelSize: 15
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Wm.focusWorkspace(cell.wsName)
                }
            }
        }
    }
}
