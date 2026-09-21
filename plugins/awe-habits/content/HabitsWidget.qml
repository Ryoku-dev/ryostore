import QtQuick
import "."

Item {
    id: root
    property real scaleFactor: 1.0

    implicitWidth: 290
    implicitHeight: 72 + root.habitsList.length * 36

    // Habits Matrix List
    property var habitsList: [
        { name: "Code Daily", streak: 18, days: [true, true, true, true, true, false, false], color: "#C2E7FF" },
        { name: "Hydrate (2L)", streak: 12, days: [true, true, true, true, false, false, false], color: "#A2C9C2" },
        { name: "Read / Study", streak: 7, days: [true, true, false, true, false, false, false], color: "#FFE082" }
    ]

    property var dayLabels: ["M", "T", "W", "T", "F", "S", "S"]

    property bool adding: false
    property bool _stateAdopted: false

    function persistHabits() {
        Store.save("habits", { list: root.habitsList })
    }

    function commitHabit() {
        var t = addInput.text.trim()
        if (t.length > 0) {
            var list = root.habitsList.slice()
            var colors = ["#C2E7FF", "#A2C9C2", "#FFE082", "#D7AEFB", "#FFB4AB"]
            var col = colors[list.length % colors.length]
            list.push({ name: t, streak: 1, days: [false, false, false, false, false, false, false], color: col })
            root.habitsList = list
            root.persistHabits()
        }
        addInput.text = ""
        root.adding = false
    }

    function adoptState() {
        if (root._stateAdopted || !Store.loaded)
            return
        root._stateAdopted = true
        var saved = Store.doc.habits
        if (saved && saved.list && Array.isArray(saved.list) && saved.list.length > 0) {
            root.habitsList = saved.list
        }
    }

    Connections {
        target: Store
        function onLoadedChanged() { root.adoptState() }
    }

    Component.onCompleted: root.adoptState()

    // Theme Palette
    readonly property color colBg: Theme.colBg
    readonly property color colPillBg: Theme.colPillBg
    readonly property color colAccent: Theme.colAccent
    readonly property color colAccentGreen: Theme.colAccentGreen
    readonly property color colTextPrimary: Theme.colTextPrimary
    readonly property color colTextSecondary: Theme.colTextSecondary

    // ─── Scaled Visual Content ───
    Item {
        id: scaledContent
        width: 290
        height: 72 + root.habitsList.length * 36
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

                // Header Row: HABITS Badge + Add Button
                Row {
                    width: parent.width

                    Rectangle {
                        height: 22
                        width: badgeRow.implicitWidth + 16
                        radius: 11
                        color: root.colPillBg
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
                                text: "HABIT TRACKER"
                                color: "#FFFFFF"
                                font.pixelSize: 9
                                font.bold: true
                                font.letterSpacing: 0.6
                                font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                            }
                        }
                    }

                    Item {
                        width: Math.max(0, parent.width - parent.children[0].width - addHabitBtn.width)
                        height: 1
                    }

                    Rectangle {
                        id: addHabitBtn
                        width: 22
                        height: 22
                        radius: 11
                        color: root.colAccent
                        antialiasing: true

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

                // Inline Add Field
                Rectangle {
                    width: parent.width
                    height: root.adding ? 26 : 0
                    visible: root.adding
                    radius: 13
                    color: root.colPillBg
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
                            text: "New habit, Enter to add"
                            color: root.colTextSecondary
                            font.pixelSize: 11
                            font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                            visible: !addInput.text
                        }

                        onAccepted: root.commitHabit()
                    }
                }

                // Habits Rows
                Column {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: root.habitsList

                        Rectangle {
                            width: parent.width
                            height: 30
                            radius: 15
                            color: root.colPillBg
                            antialiasing: true

                            Row {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 6

                                // Habit Name + Streak
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.name
                                    color: "#FFFFFF"
                                    font.pixelSize: 10
                                    font.bold: true
                                    elide: Text.ElideRight
                                    width: 85
                                    font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                                }

                                // Streak Badge
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 16
                                    width: stkText.implicitWidth + 8
                                    radius: 8
                                    color: "#1FFFFFFF"
                                    antialiasing: true

                                    Text {
                                        id: stkText
                                        anchors.centerIn: parent
                                        text: modelData.streak + "d"
                                        color: modelData.color || root.colAccent
                                        font.pixelSize: 8
                                        font.bold: true
                                        font.family: "Google Sans Flex, Google Sans, Inter, monospace"
                                    }
                                }

                                Item {
                                    width: Math.max(0, parent.width - 85 - 34 - daysRow.width)
                                    height: 1
                                }

                                // 7-Day Matrix Dots
                                Row {
                                    id: daysRow
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4

                                    Repeater {
                                        model: 7

                                        Rectangle {
                                            width: 16
                                            height: 16
                                            radius: 8
                                            color: (modelData.days && modelData.days[index]) ? (modelData.color || root.colAccent) : "#20000000"
                                            border.color: (modelData.days && modelData.days[index]) ? "transparent" : "#40FFFFFF"
                                            border.width: 1
                                            antialiasing: true

                                            Text {
                                                anchors.centerIn: parent
                                                text: root.dayLabels[index]
                                                color: (modelData.days && modelData.days[index]) ? "#1E2A30" : "#80FFFFFF"
                                                font.pixelSize: 8
                                                font.bold: true
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    var list = root.habitsList.slice()
                                                    var habit = Object.assign({}, list[model.index])
                                                    var days = (habit.days || [false, false, false, false, false, false, false]).slice()
                                                    days[index] = !days[index]
                                                    habit.days = days
                                                    list[model.index] = habit
                                                    root.habitsList = list
                                                    root.persistHabits()
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
        }
    }
}
