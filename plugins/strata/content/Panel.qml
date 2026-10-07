import QtQuick
import Ryoku.PluginKit
import Ryoku.PluginKit.Singletons

// Panel: models grouped by engine, each with its own start/stop; the selected model's address and
// a start/stop for it at the bottom. Starting any model stops the others (one at a time).
Item {
    id: root

    property var pluginApi
    property string density: "full"
    property real s: 1
    property real widthBudget: 360
    property bool active: false

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property bool on: service ? service.running : false
    readonly property bool busy: service ? service.busy : false
    readonly property string st: service ? service.state : "unknown"
    readonly property var sel: service ? service.selected : null

    implicitWidth: root.widthBudget
    implicitHeight: col.implicitHeight + 32 * root.s

    onActiveChanged: if (active && service) service.refresh()

    // a status dot: lit while running, pulsing while starting/stopping, hollow when idle
    component Dot: Rectangle {
        id: dot
        property bool lit: false
        property bool pulse: false
        width: 7 * root.s
        height: 7 * root.s
        radius: width / 2
        color: lit ? Theme.accent : "transparent"
        border.width: lit ? 0 : 1.5 * root.s
        border.color: Theme.faint
        SequentialAnimation on opacity {
            running: dot.pulse
            loops: Animation.Infinite
            onRunningChanged: if (!running) dot.opacity = 1
            NumberAnimation { to: 0.25; duration: Motion.pulse }
            NumberAnimation { to: 1; duration: Motion.pulse }
        }
    }

    Column {
        id: col
        x: 16 * root.s
        y: 16 * root.s
        width: root.width - 32 * root.s
        spacing: 14 * root.s

        // header: title, the selected model's address, overall state
        Item {
            width: col.width
            height: Math.max(head.implicitHeight, pill.height)

            Row {
                id: head
                spacing: 10 * root.s
                anchors.verticalCenter: parent.verticalCenter

                GlyphIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22 * root.s
                    height: 22 * root.s
                    name: "cpu"
                    color: root.on ? Theme.accent : Theme.iconDim
                    Behavior on color { ColorAnimation { duration: Motion.standard } }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1 * root.s
                    Text {
                        text: "Local models"
                        color: Theme.bright
                        font.family: Theme.display
                        font.pixelSize: 18 * root.s
                    }
                    Text {
                        text: root.sel ? root.sel.engine + " · 127.0.0.1:" + root.sel.port : "no model selected"
                        color: Theme.faint
                        font.family: Theme.mono
                        font.pixelSize: 10.5 * root.s
                    }
                }
            }

            Rectangle {
                id: pill
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: pillRow.implicitWidth + 16 * root.s
                height: pillRow.implicitHeight + 8 * root.s
                radius: height / 2
                color: root.on ? Theme.threadBg : "transparent"
                border.width: 1
                border.color: root.on ? Theme.accent : Theme.border

                Row {
                    id: pillRow
                    anchors.centerIn: parent
                    spacing: 6 * root.s
                    Dot {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 6 * root.s
                        height: 6 * root.s
                        lit: root.on
                        pulse: root.busy
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.st === "activating" ? "starting"
                            : root.st === "deactivating" ? "stopping"
                            : root.on ? "running" : root.st === "failed" ? "failed" : "idle"
                        color: root.on ? Theme.accent : root.st === "failed" ? Theme.verm : Theme.dim
                        font.family: Theme.mono
                        font.pixelSize: 10.5 * root.s
                    }
                }
            }
        }

        Rectangle { width: col.width; height: 1; color: Theme.hair }

        // one group per detected engine
        Column {
            width: col.width
            spacing: 14 * root.s

            Repeater {
                model: root.service ? root.service.engines : []
                delegate: Column {
                    id: group
                    required property string modelData
                    readonly property var rows: root.service ? root.service.models.filter(m => m.engine === modelData) : []
                    readonly property string est: root.service ? root.service.engineState(modelData) : "unknown"
                    width: col.width
                    spacing: 6 * root.s

                    Item {
                        width: group.width
                        height: Math.max(eyebrow.implicitHeight, meta.implicitHeight)
                        MicroLabel {
                            id: eyebrow
                            anchors.verticalCenter: parent.verticalCenter
                            label: group.modelData
                            s: root.s
                        }
                        Text {
                            id: meta
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: (group.est === "active" ? "running · " : group.est === "failed" ? "failed · " : "")
                                + group.rows.length + (group.rows.length === 1 ? " model" : " models")
                            color: group.est === "active" ? Theme.accent : group.est === "failed" ? Theme.verm : Theme.faint
                            font.family: Theme.mono
                            font.pixelSize: 10 * root.s
                        }
                    }

                    Repeater {
                        model: group.rows
                        delegate: Rectangle {
                            id: rowItem
                            required property var modelData
                            readonly property bool sel: root.service && root.service.current === modelData.key
                            readonly property bool live: root.service ? root.service.isRunning(modelData.key) : false
                            width: group.width
                            height: 44 * root.s
                            radius: Motion.rSmall * root.s
                            color: sel ? Theme.threadBg : (pickArea.containsMouse ? Theme.sheen : "transparent")
                            border.width: 1
                            border.color: live ? Theme.accent : sel ? Theme.lineStrong : Theme.hair
                            opacity: root.busy && !sel ? 0.55 : 1
                            Behavior on color { ColorAnimation { duration: Motion.fast } }
                            Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                            MouseArea {
                                id: pickArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: !root.busy
                                onClicked: if (root.service) root.service.pick(rowItem.modelData.key)
                            }

                            Dot {
                                id: rowDot
                                x: 14 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                lit: rowItem.live
                                pulse: rowItem.sel && root.busy
                                border.color: rowItem.sel ? Theme.accent : Theme.faint
                            }

                            Column {
                                anchors.left: rowDot.right
                                anchors.leftMargin: 12 * root.s
                                anchors.right: go.left
                                anchors.rightMargin: 10 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2 * root.s
                                Text {
                                    width: parent.width
                                    text: rowItem.modelData.label
                                    color: rowItem.sel ? Theme.bright : Theme.dim
                                    font.family: Theme.mono
                                    font.pixelSize: 12.5 * root.s
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    text: ":" + rowItem.modelData.port + (rowItem.live ? "  ·  running" : "")
                                    color: rowItem.live ? Theme.accent : Theme.faint
                                    font.family: Theme.mono
                                    font.pixelSize: 10 * root.s
                                    elide: Text.ElideRight
                                }
                            }

                            // this model's own start / stop
                            Rectangle {
                                id: go
                                anchors.right: parent.right
                                anchors.rightMargin: 9 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                width: 28 * root.s
                                height: 28 * root.s
                                radius: width / 2
                                color: goArea.pressed ? Theme.vermDeep
                                     : goArea.containsMouse ? (rowItem.live ? Theme.sheen : Theme.accent)
                                     : "transparent"
                                border.width: 1
                                border.color: rowItem.live || goArea.containsMouse ? Theme.accent : Theme.border
                                Behavior on color { ColorAnimation { duration: Motion.fast } }

                                GlyphIcon {
                                    anchors.centerIn: parent
                                    width: 12 * root.s
                                    height: 12 * root.s
                                    name: rowItem.live ? "stop" : "play"
                                    color: goArea.containsMouse && !rowItem.live ? Theme.cardBot
                                         : rowItem.live ? Theme.accent : Theme.dim
                                }
                                MouseArea {
                                    id: goArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !root.busy
                                    onClicked: if (root.service) root.service.toggleModel(rowItem.modelData.key)
                                }
                            }
                        }
                    }
                }
            }

            Text {
                visible: root.service && root.service.models.length === 0
                text: "No models found yet."
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 12 * root.s
            }
        }

        Rectangle { width: col.width; height: 1; color: Theme.hair }

        // the selected model's OpenAI-style address (selectable, to copy)
        Column {
            width: col.width
            spacing: 4 * root.s
            visible: root.sel !== null
            MicroLabel { label: "Address"; s: root.s }
            TextInput {
                width: parent.width
                readOnly: true
                selectByMouse: true
                text: root.sel ? "http://127.0.0.1:" + root.sel.port + "/v1" : ""
                color: root.on ? Theme.bright : Theme.dim
                selectionColor: Theme.accent
                selectedTextColor: Theme.cardBot
                font.family: Theme.mono
                font.pixelSize: 12 * root.s
            }
        }

        // start / stop the selected model
        Rectangle {
            id: action
            width: col.width
            height: 38 * root.s
            radius: Motion.rSmall * root.s
            color: root.on ? (area.containsMouse ? Theme.sheen : "transparent")
                           : (area.pressed ? Theme.vermDeep : area.containsMouse ? Theme.vermLit : Theme.accent)
            border.width: root.on ? 1 : 0
            border.color: Theme.lineStrong
            opacity: root.busy || !root.sel ? 0.6 : 1
            Behavior on color { ColorAnimation { duration: Motion.fast } }

            Row {
                anchors.centerIn: parent
                spacing: 8 * root.s
                GlyphIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14 * root.s
                    height: 14 * root.s
                    name: root.on ? "stop" : "play"
                    color: root.on ? Theme.bright : Theme.cardBot
                    visible: !root.busy
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.st === "activating" ? "STARTING…"
                        : root.st === "deactivating" ? "STOPPING…"
                        : root.on ? "STOP SERVER" : "START SELECTED"
                    color: root.on ? Theme.bright : Theme.cardBot
                    font.family: Theme.mono
                    font.pixelSize: 11.5 * root.s
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.6 * root.s
                }
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: !root.busy && root.sel !== null
                onClicked: if (root.service) root.service.toggle()
            }
        }

        Text {
            width: col.width
            wrapMode: Text.WordWrap
            text: "One model runs at a time: starting one stops the others."
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 11 * root.s
        }
    }
}
