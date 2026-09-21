import QtQuick
import "."

Item {
    id: root
    property real scaleFactor: 1.0

    implicitWidth: 280
    implicitHeight: 240

    // Todo items list
    property var taskList: [
        { text: "Update Quickshell desktop widgets", done: true },
        { text: "Material 3 theme refinement", done: true },
        { text: "Check soundwave equalizer animations", done: false },
        { text: "Customize wallpaper photo frame", done: false }
    ]

    readonly property int completedCount: {
        var c = 0
        for (var i = 0; i < taskList.length; i++) {
            if (taskList[i].done) c++
        }
        return c
    }

    readonly property real progressRatio: taskList.length > 0 ? completedCount / taskList.length : 0

    property bool adding: false
    property bool _stateAdopted: false

    function persistTasks() {
        Store.save("todo", { list: root.taskList })
    }

    function commitTask() {
        var t = addInput.text.trim()
        if (t.length > 0) {
            var list = root.taskList.slice()
            list.push({ text: t, done: false })
            root.taskList = list
            root.persistTasks()
        }
        addInput.text = ""
        root.adding = false
    }

    function adoptState() {
        if (root._stateAdopted || !Store.loaded)
            return
        root._stateAdopted = true
        var saved = Store.doc.todo
        if (saved && saved.list && Array.isArray(saved.list) && saved.list.length > 0) {
            root.taskList = saved.list
        }
    }

    Connections {
        target: Store
        function onLoadedChanged() { root.adoptState() }
    }

    Component.onCompleted: root.adoptState()

    // Theme Palette
    readonly property color colBg: Theme.colBgTile
    readonly property color colBadgeBg: Theme.colPillBg
    readonly property color colAccent: Theme.colAccent
    readonly property color colAccentGreen: Theme.colAccentGreen
    readonly property color colTextPrimary: Theme.colTextPrimary
    readonly property color colTextSecondary: Theme.colTextSecondary

    // ─── Scaled Visual Content ───
    Item {
        id: scaledContent
        width: 280
        height: 240
        scale: root.scaleFactor
        transformOrigin: Item.TopLeft

        // Main Card
        Rectangle {
            anchors.fill: parent
            color: root.colBg
            radius: 32
            border.color: Theme.borderColor
            border.width: Theme.borderWidth
            clip: true
            antialiasing: true

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1.5
                color: Theme.glassGloss
                visible: Theme.isGlass
            }

            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                // Header Row: Tasks Badge + Progress Pill + Add Button
                Row {
                    width: parent.width

                    Rectangle {
                        height: 22
                        width: badgeRow.implicitWidth + 16
                        radius: 11
                        color: root.colBadgeBg
                        antialiasing: true

                        Row {
                            id: badgeRow
                            anchors.centerIn: parent
                            spacing: 6

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 7
                                height: 7
                                radius: 3.5
                                color: root.colAccentGreen
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "TASKS"
                                color: root.colTextPrimary
                                font.pixelSize: 9
                                font.bold: true
                                font.letterSpacing: 0.6
                                font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                            }
                        }
                    }

                    Item {
                        width: Math.max(0, parent.width - parent.children[0].width - rightBtns.width)
                        height: 1
                    }

                    Row {
                        id: rightBtns
                        spacing: 8
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.completedCount + "/" + root.taskList.length
                            color: root.colTextSecondary
                            font.pixelSize: 11
                            font.bold: true
                            font.family: "Google Sans Flex, Google Sans, Inter, monospace"
                        }

                        // Add Task Pill Button
                        Rectangle {
                            width: 22
                            height: 22
                            radius: 11
                            color: root.colAccent
                            Text {
                                anchors.centerIn: parent
                                text: "+"
                                color: "#1E2A30"
                                font.pixelSize: 14
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.adding = !root.adding
                                    if (root.adding) addInput.forceActiveFocus()
                                }
                            }
                        }
                    }
                }

                // Inline Add Field
                Rectangle {
                    width: parent.width
                    height: root.adding ? 26 : 0
                    visible: root.adding
                    radius: 13
                    color: root.colBadgeBg
                    clip: true
                    antialiasing: true

                    TextInput {
                        id: addInput
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        color: root.colTextPrimary
                        font.pixelSize: 11
                        font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                        clip: true
                        selectByMouse: true

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "New task, Enter to add"
                            color: root.colTextSecondary
                            font.pixelSize: 11
                            font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                            visible: !addInput.text
                        }

                        onAccepted: root.commitTask()
                    }
                }

                // Progress Bar
                Rectangle {
                    width: parent.width
                    height: 4
                    radius: 2
                    color: root.colBadgeBg
                    antialiasing: true

                    Rectangle {
                        width: Math.max(parent.radius * 2, parent.width * root.progressRatio)
                        height: parent.height
                        radius: parent.radius
                        color: root.progressRatio === 1.0 ? "#A2C9C2" : root.colAccent
                        antialiasing: true
                    }
                }

                // Task List Items Container
                ListView {
                    width: parent.width
                    height: 160
                    clip: true
                    spacing: 6
                    model: root.taskList

                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 32
                        radius: 16
                        color: root.colBadgeBg
                        antialiasing: true

                        Row {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 8

                            // Checkbox Pill
                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                color: modelData.done ? root.colAccentGreen : "#2B353A"
                                anchors.verticalCenter: parent.verticalCenter
                                antialiasing: true

                                Text {
                                    anchors.centerIn: parent
                                    visible: modelData.done
                                    text: "✓"
                                    color: "#1E2A30"
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var list = root.taskList.slice()
                                        list[index] = { text: modelData.text, done: !modelData.done }
                                        root.taskList = list
                                        root.persistTasks()
                                    }
                                }
                            }

                            // Task Text
                            Text {
                                width: parent.width - 20 - 8 - 24
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.text
                                color: modelData.done ? "#88979E" : root.colTextPrimary
                                font.pixelSize: 11
                                font.strikeout: modelData.done
                                font.bold: !modelData.done
                                elide: Text.ElideRight
                                font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                            }

                            // Delete Single Task Button
                            Item {
                                width: 20
                                height: 20
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: "×"
                                    color: "#88979E"
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var list = root.taskList.slice()
                                        list.splice(index, 1)
                                        root.taskList = list
                                        root.persistTasks()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
