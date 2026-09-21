import QtQuick
import "."

Item {
    id: root
    property real scaleFactor: 1.0

    implicitWidth: 270
    implicitHeight: 220

    // Notes Data (Default color matches standard dark slate #232D33)
    property var notesList: [
        { title: "Project Ideas", body: "Build smooth Material 3 widgets with instant inline typing and auto-save.", color: "#232D33", date: "Today" },
        { title: "Desktop Tweaks", body: "Organize layout grids and add animated soundwaves to media player.", color: "#1C3842", date: "Yesterday" },
        { title: "Quick Reminders", body: "Check dotfiles and test Wayland layershell transparency.", color: "#223B22", date: "Aug 30" }
    ]
    property int currentNoteIndex: 0

    Timer {
        id: autoSaveTimer
        interval: 600
        repeat: false
        onTriggered: root.persistNotes()
    }

    function persistNotes() {
        Store.save("notes", { list: root.notesList })
    }

    function loadCurrentNoteFields() {
        if (root.notesList && root.notesList.length > root.currentNoteIndex) {
            var n = root.notesList[root.currentNoteIndex]
            titleInput.text = n.title || ""
            bodyInput.text = n.body || ""
        }
    }

    function updateCurrentNote() {
        if (root.notesList && root.notesList.length > root.currentNoteIndex) {
            var list = root.notesList.slice()
            var prevColor = list[root.currentNoteIndex].color || "#232D33"
            list[root.currentNoteIndex] = {
                title: titleInput.text,
                body: bodyInput.text,
                color: prevColor,
                date: "Edited"
            }
            root.notesList = list
            autoSaveTimer.restart()
        }
    }

    property bool _stateAdopted: false

    function adoptState() {
        if (root._stateAdopted || !Store.loaded)
            return
        root._stateAdopted = true
        var saved = Store.doc.notes
        if (saved && saved.list && Array.isArray(saved.list) && saved.list.length > 0) {
            root.notesList = saved.list
            if (root.currentNoteIndex >= root.notesList.length) root.currentNoteIndex = 0
            root.loadCurrentNoteFields()
        }
    }

    Connections {
        target: Store
        function onLoadedChanged() { root.adoptState() }
    }

    Component.onCompleted: {
        root.loadCurrentNoteFields()
        root.adoptState()
    }

    // Material 3 Dark & Pastel Tonal Palette
    property var themeColors: [
        { name: "Slate", bg: "#232D33", badge: "#C2E7FF", border: "#3B4A53" },
        { name: "Amber", bg: "#3C321E", badge: "#FEEFC3", border: "#614E2E" },
        { name: "Seafoam", bg: "#1C3842", badge: "#CBF0F8", border: "#2E5A6B" },
        { name: "Mint", bg: "#223B22", badge: "#CCFF90", border: "#396139" },
        { name: "Lilac", bg: "#35263F", badge: "#D7AEFB", border: "#583E69" }
    ]

    readonly property color currentCardBg: {
        if (root.notesList && root.notesList[root.currentNoteIndex]) {
            var c = root.notesList[root.currentNoteIndex].color
            if (c && c !== "#232D33") return c
        }
        return Theme.colBg
    }

    readonly property color currentBadgeColor: {
        for (var i = 0; i < themeColors.length; i++) {
            if (themeColors[i].bg === root.currentCardBg) return themeColors[i].badge
        }
        return Theme.colAccent
    }

    // ─── Scaled Visual Content ───
    Item {
        id: scaledContent
        width: 270
        height: 220
        scale: root.scaleFactor
        transformOrigin: Item.TopLeft

        // Main Card
        Rectangle {
            anchors.fill: parent
            color: root.currentCardBg
            radius: 28
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
                spacing: 6

                // ─── Header Row: NOTES Pill Badge + Navigation + Add Button ───
                Row {
                    width: parent.width

                    // Material 3 Notes Pill Badge
                    Rectangle {
                        height: 22
                        width: badgeRow.implicitWidth + 14
                        radius: 11
                        color: "#20000000"
                        border.color: "#1AFFFFFF"
                        border.width: 1
                        antialiasing: true

                        Row {
                            id: badgeRow
                            anchors.centerIn: parent
                            spacing: 5

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 6
                                height: 6
                                radius: 3
                                color: root.currentBadgeColor
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "NOTES"
                                color: "#FFFFFF"
                                font.pixelSize: 9
                                font.bold: true
                                font.letterSpacing: 0.8
                                font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                            }
                        }
                    }

                    Item {
                        width: Math.max(0, parent.width - parent.children[0].width - navRow.width)
                        height: 1
                    }

                    // Navigation & Add Controls
                    Row {
                        id: navRow
                        spacing: 6
                        anchors.verticalCenter: parent.verticalCenter

                        // Prev Note Button
                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            color: prevNoteArea.containsMouse ? "#33FFFFFF" : "#40000000"
                            antialiasing: true
                            Text {
                                anchors.centerIn: parent
                                text: "‹"
                                color: "#FFFFFF"
                                font.pixelSize: 13
                                font.bold: true
                            }
                            MouseArea {
                                id: prevNoteArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.notesList.length > 0) {
                                        root.currentNoteIndex = (root.currentNoteIndex - 1 + root.notesList.length) % root.notesList.length
                                        root.loadCurrentNoteFields()
                                    }
                                }
                            }
                        }

                        // Counter Indicator
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: (root.currentNoteIndex + 1) + "/" + Math.max(1, root.notesList.length)
                            color: "#B3FFFFFF"
                            font.pixelSize: 10
                            font.bold: true
                            font.family: "Google Sans Flex, Google Sans, Inter, monospace"
                        }

                        // Next Note Button
                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            color: nextNoteArea.containsMouse ? "#33FFFFFF" : "#40000000"
                            antialiasing: true
                            Text {
                                anchors.centerIn: parent
                                text: "›"
                                color: "#FFFFFF"
                                font.pixelSize: 13
                                font.bold: true
                            }
                            MouseArea {
                                id: nextNoteArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.notesList.length > 0) {
                                        root.currentNoteIndex = (root.currentNoteIndex + 1) % root.notesList.length
                                        root.loadCurrentNoteFields()
                                    }
                                }
                            }
                        }

                        // Add Note Button (+)
                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            color: root.currentBadgeColor
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
                                    var list = root.notesList.slice()
                                    list.push({ title: "New Memo", body: "Type note here...", color: "#232D33", date: "Just now" })
                                    root.notesList = list
                                    root.currentNoteIndex = list.length - 1
                                    root.loadCurrentNoteFields()
                                    root.persistNotes()
                                }
                            }
                        }
                    }
                }

                // ─── Inline Editable Note Title ───
                TextInput {
                    id: titleInput
                    width: parent.width
                    color: "#FFFFFF"
                    font.pixelSize: 15
                    font.bold: true
                    font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                    clip: true
                    selectByMouse: true

                    Text {
                        anchors.fill: parent
                        text: "Note Title..."
                        color: "#66FFFFFF"
                        font.pixelSize: 15
                        font.bold: true
                        font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                        visible: !titleInput.text && !titleInput.activeFocus
                    }

                    onTextChanged: {
                        if (activeFocus) root.updateCurrentNote()
                    }
                }

                // ─── Inline Editable Multiline Note Body ───
                Flickable {
                    id: flickBody
                    width: parent.width
                    height: 104
                    contentWidth: width
                    contentHeight: bodyInput.implicitHeight
                    clip: true

                    TextEdit {
                        id: bodyInput
                        width: flickBody.width
                        color: "#E0FFFFFF"
                        font.pixelSize: 12
                        font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                        wrapMode: TextEdit.Wrap
                        selectByMouse: true

                        Text {
                            anchors.fill: parent
                            text: "Type note content here..."
                            color: "#59FFFFFF"
                            font.pixelSize: 12
                            font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                            visible: !bodyInput.text && !bodyInput.activeFocus
                        }

                        onTextChanged: {
                            if (activeFocus) root.updateCurrentNote()
                        }
                    }
                }

                // ─── Bottom Action Bar: Theme Color Chips + Delete Note ───
                Row {
                    width: parent.width
                    height: 20

                    // Color Palette Swatches
                    Row {
                        spacing: 7
                        anchors.verticalCenter: parent.verticalCenter

                        Repeater {
                            model: root.themeColors

                            Rectangle {
                                width: 14
                                height: 14
                                radius: 7
                                color: modelData.badge
                                border.color: (root.currentCardBg === modelData.bg) ? "#FFFFFF" : "#66000000"
                                border.width: (root.currentCardBg === modelData.bg) ? 2 : 1
                                antialiasing: true

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var list = root.notesList.slice()
                                        if (list[root.currentNoteIndex]) {
                                            list[root.currentNoteIndex].color = modelData.bg
                                            root.notesList = list
                                            root.persistNotes()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        width: Math.max(0, parent.width - (5 * 21) - delNoteBtn.width)
                        height: 1
                    }

                    // Delete Note Button
                    Rectangle {
                        id: delNoteBtn
                        width: 20
                        height: 20
                        radius: 10
                        color: delNoteArea.containsMouse ? "#FFB4AB" : "#40000000"
                        antialiasing: true

                        Canvas {
                            anchors.fill: parent
                            antialiasing: true
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                var cx = width / 2
                                var cy = height / 2
                                ctx.strokeStyle = delNoteArea.containsMouse ? "#1E2A30" : "#FFB4AB"
                                ctx.lineWidth = 1.4
                                ctx.beginPath()
                                ctx.moveTo(cx - 3.5, cy - 3.5)
                                ctx.lineTo(cx + 3.5, cy + 3.5)
                                ctx.moveTo(cx + 3.5, cy - 3.5)
                                ctx.lineTo(cx - 3.5, cy + 3.5)
                                ctx.stroke()
                            }
                        }

                        MouseArea {
                            id: delNoteArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.notesList.length > 1) {
                                    var list = root.notesList.slice()
                                    list.splice(root.currentNoteIndex, 1)
                                    root.notesList = list
                                    root.currentNoteIndex = Math.max(0, root.currentNoteIndex - 1)
                                    root.loadCurrentNoteFields()
                                    root.persistNotes()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
