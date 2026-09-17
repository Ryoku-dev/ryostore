pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.Ui.Singletons
import shell.services

Item {
    id: root

    property real barHeight: 40
    property string workspaceStyle: Config.normalizedNacre.workspaceStyle
    readonly property var kanji: ["", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
    readonly property string activeName: Wm.focusedWorkspace ? String(Wm.focusedWorkspace.name) : ""
    readonly property int activeId: {
        const id = Number(root.activeName);
        return (Math.floor(id) === id && id > 0) ? id : 1;
    }
    readonly property int base: Math.floor((root.activeId - 1) / 10) * 10

    // A dynamic workspace model (a scrolling workspace set with no stable slots)
    // follows the live list; a fixed model shows the numbered row below.
    readonly property bool dynamicModel: Wm.workspaceModel === "dynamic"

    function label(name) {
        if (root.workspaceStyle === "dots")
            return "";
        const id = Number(name);
        if (root.workspaceStyle === "kanji" && Math.floor(id) === id && id >= 1 && id <= 10)
            return root.kanji[id];
        return (Math.floor(id) === id) ? String(id) : String(name);
    }

    function occupied(name) {
        const ws = Wm.workspaceByName(String(name));
        return !!ws && ws.occupied === true;
    }

    readonly property var entries: {
        const output = [];
        if (root.dynamicModel) {
            const list = Wm.workspaces || [];
            for (let index = 0; index < list.length; index++) {
                const ws = list[index];
                if (ws && ws.special !== true)
                    output.push(String(ws.name));
            }
            if (output.length === 0 && root.activeName !== "")
                output.push(root.activeName);
            return output;
        }
        if (Config.normalizedNacre.occupiedWorkspaces) {
            for (let index = 1; index <= 10; index++) {
                const id = root.base + index;
                if (id === root.activeId || root.occupied(id))
                    output.push(String(id));
            }
        } else {
            let count = 5;
            for (let index = 10; index > 5; index--) {
                const id = root.base + index;
                if (id === root.activeId || root.occupied(id)) {
                    count = index;
                    break;
                }
            }
            for (let index = 1; index <= count; index++)
                output.push(String(root.base + index));
        }
        return output.length ? output : [String(root.activeId)];
    }

    implicitWidth: content.implicitWidth
    implicitHeight: 26

    WheelHandler {
        onWheel: event => Wm.cycleWorkspace(event.angleDelta.y > 0 ? -1 : 1)
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: root.workspaceStyle === "dots" ? 5 : 3

        Repeater {
            model: root.entries
            delegate: Rectangle {
                id: ring

                required property var modelData
                readonly property string wsName: String(ring.modelData)
                readonly property bool active: ring.wsName === root.activeName
                readonly property bool occupied: !ring.active && root.occupied(ring.wsName)
                readonly property bool dotMode: root.workspaceStyle === "dots"

                anchors.verticalCenter: parent.verticalCenter
                width: ring.dotMode ? (ring.active ? 10 : 7) : 26
                height: width
                radius: width / 2
                color: ring.dotMode ? "transparent"
                    : ring.active ? Theme.primary
                    : ring.occupied
                        ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.10)
                        : "transparent"
                border.width: ring.dotMode ? (ring.active ? 2 : 1) : 0
                border.color: ring.active ? Theme.primary
                    : ring.occupied ? Theme.onSurface : Theme.onSurfaceVariant

                Behavior on width {
                    NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard }
                }
                Behavior on color {
                    ColorAnimation { duration: Motion.fast }
                }
                Behavior on border.color {
                    ColorAnimation { duration: Motion.fast }
                }
                Text {
                    anchors.centerIn: parent
                    visible: !ring.dotMode
                    text: root.label(ring.wsName)
                    color: ring.active ? Theme.onPrimary
                        : ring.occupied ? Theme.onSurface : Theme.onSurfaceVariant
                    font.family: root.workspaceStyle === "kanji" ? Theme.fontJp : Theme.mono
                    font.pixelSize: root.workspaceStyle === "kanji" ? 15 : Theme.fontSm
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -5
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Wm.focusWorkspace(ring.wsName)
                }
            }
        }
    }
}
