pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.Ui.Singletons
import shell.services

Rectangle {
    id: root

    required property var colors

    // The live workspace set, read from the shell's window-manager facade: a
    // fixed numbered model lays it out as slots, a scrolling model as itself.
    readonly property bool dynamicModel: Wm.workspaceModel === "dynamic"
    readonly property string activeName: Wm.focusedWorkspace ? String(Wm.focusedWorkspace.name) : ""

    readonly property var liveNames: {
        const out = []
        const list = Wm.workspaces || []
        for (let i = 0; i < list.length; ++i) {
            const w = list[i]
            if (w && w.special !== true)
                out.push(String(w.name))
        }
        return out
    }

    readonly property int workspaceCount: {
        if (dynamicModel)
            return Math.max(1, liveNames.length)
        let highest = Math.max(5, root.activeIndex)
        for (let i = 0; i < liveNames.length; ++i) {
            const id = Number(liveNames[i])
            if (id > 0 && id <= 10)
                highest = Math.max(highest, id)
        }
        return Math.min(10, highest)
    }

    readonly property int activeIndex: {
        const n = Number(root.activeName)
        return (Math.floor(n) === n && n > 0) ? n : 1
    }

    function nameAt(number) {
        return root.dynamicModel ? String(root.liveNames[number - 1] || "") : String(number)
    }

    function occupied(number) {
        const ws = Wm.workspaceByName(root.nameAt(number))
        return !!ws && ws.occupied === true
    }

    function focus(number) {
        const name = root.nameAt(number)
        if (name !== "")
            Wm.focusWorkspace(name)
    }

    implicitWidth: row.implicitWidth + Theme.paddingMd * 2
    implicitHeight: Theme.iconLg + Theme.paddingLg

    radius: Theme.radiusWidget
    color: root.colors.backgroundAlt
    border.width: 0
    clip: true

    Row {
        id: row

        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: Theme.paddingMd
            rightMargin: Theme.paddingMd
        }

        height: parent.height
        spacing: Theme.paddingSm

        Repeater {
            model: root.workspaceCount

            Item {
                id: slot
                required property int index

                readonly property int number: index + 1
                readonly property bool active: root.nameAt(slot.number) === root.activeName
                readonly property bool hasWindows: root.occupied(slot.number)

                width: slot.active
                    ? Theme.iconLg + Theme.paddingMd
                    : Theme.iconLg
                height: parent.height

                Rectangle {
                    id: button

                    anchors.fill: parent
                    radius: Theme.radiusWidget
                    color: slot.active
                        ? root.colors.alpha(root.colors.accent(slot.index), 0.22)
                        : hover.containsMouse
                            ? root.colors.surfaceHover
                            : "transparent"
                    border.width: 0

                    Behavior on color {
                        enabled: !Motion.reduce
                        ColorAnimation {
                            duration: Motion.fast
                            easing.type: Motion.easeStandard
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        readonly property string label: root.dynamicModel
                            ? root.nameAt(slot.number)
                            : String(slot.number)
                        text: /^\d$/.test(label) ? "0" + label : label
                        color: slot.active ? root.colors.accent(slot.index) : root.colors.text
                        font.family: Theme.mono
                        font.pixelSize: Theme.fontSm
                        font.weight: Font.Black
                    }

                    Rectangle {
                        anchors {
                            horizontalCenter: parent.horizontalCenter
                            bottom: parent.bottom
                            bottomMargin: Theme.paddingSm
                        }

                        width: slot.hasWindows ? Theme.paddingMd : Theme.borderWidth
                        height: Theme.borderWidth
                        radius: Theme.borderWidth / 2
                        color: root.colors.accent(slot.index)
                        opacity: slot.active ? 1.0 : slot.hasWindows ? 0.72 : 0.20

                        Behavior on opacity {
                            enabled: !Motion.reduce
                            NumberAnimation { duration: Motion.fast }
                        }
                    }

                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.focus(slot.number)
                    }
                }
            }
        }
    }

    WheelHandler {
        onWheel: event => Wm.cycleWorkspace(event.angleDelta.y > 0 ? -1 : 1)
    }
}
