import QtQuick
import Quickshell
import Quickshell.Io
import "."

Item {
    id: root
    implicitWidth: 280
    implicitHeight: 190

    // Clipboard History List
    property var historyList: [
        "npm run build",
        "The quick brown fox",
        "Copied text lands here"
    ]
    property string lastCopied: ""
    property string copyToast: ""

    // Process to check wl-paste for new clipboard item
    Process {
        id: pasteProc
        command: ["wl-paste", "-n"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var str = text.trim()
                if (str.length > 0 && str !== root.lastCopied && str.length < 500) {
                    root.lastCopied = str
                    var list = root.historyList.filter(item => item !== str)
                    list.unshift(str)
                    if (list.length > 8) list = list.slice(0, 8)
                    root.historyList = list
                    Store.save("clipboard", { list: root.historyList })
                }
            }
        }
    }

    // Process to copy item back to clipboard
    Process {
        id: copyProc
        running: false
    }

    function copyToClipboard(str) {
        copyProc.command = ["wl-copy", str]
        copyProc.running = true
        root.copyToast = "Copied!"
        toastTimer.restart()
    }

    Timer {
        id: toastTimer
        interval: 1500
        onTriggered: root.copyToast = ""
    }

    Timer {
        interval: 2500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: pasteProc.running = true
    }

    Component.onCompleted: {
        var saved = Store.doc.clipboard
        if (saved && saved.list && Array.isArray(saved.list) && saved.list.length > 0)
            root.historyList = saved.list
    }

    // Theme Palette
    readonly property color colBg: Theme.colBg
    readonly property color colBadgeBg: Theme.colPillBg
    readonly property color colAccent: Theme.colAccent
    readonly property color colAccentGreen: Theme.colAccentGreen
    readonly property color colTextPrimary: Theme.colTextPrimary
    readonly property color colTextSecondary: Theme.colTextSecondary

    // ─── Scaled Visual Content ───
    Item {
        id: scaledContent
        width: 280
        height: 190
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

                // Header Row: CLIPBOARD Badge + Toast + Clear Button
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
                                text: "CLIPBOARD"
                                color: root.colTextPrimary
                                font.pixelSize: 9
                                font.bold: true
                                font.letterSpacing: 0.6
                                font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                            }
                        }
                    }

                    Item {
                        width: Math.max(0, parent.width - parent.children[0].width - rightRow.width)
                        height: 1
                    }

                    Row {
                        id: rightRow
                        spacing: 8
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.copyToast.length > 0
                            text: root.copyToast
                            color: root.colAccentGreen
                            font.pixelSize: 10
                            font.bold: true
                            font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                        }

                        // Clear Button
                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            color: root.colBadgeBg
                            antialiasing: true

                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                color: "#FFB4AB"
                                font.pixelSize: 14
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.historyList = []
                                    Store.save("clipboard", { list: root.historyList })
                                }
                            }
                        }
                    }
                }

                // Clipboard History Items List
                ListView {
                    width: parent.width
                    height: 120
                    clip: true
                    spacing: 6
                    model: root.historyList

                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 32
                        radius: 16
                        color: itemArea.containsMouse ? "#3A4750" : root.colBadgeBg
                        antialiasing: true

                        Row {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            // Copy Vector Icon
                            Canvas {
                                width: 14
                                height: 14
                                anchors.verticalCenter: parent.verticalCenter
                                antialiasing: true
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.reset()
                                    ctx.strokeStyle = root.colAccent
                                    ctx.lineWidth = 1.3
                                    ctx.strokeRect(4, 1, 8, 8)
                                    ctx.fillStyle = root.colBadgeBg
                                    ctx.fillRect(1, 4, 8, 8)
                                    ctx.strokeRect(1, 4, 8, 8)
                                }
                            }

                            Text {
                                width: parent.width - 24
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData
                                color: root.colTextPrimary
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                font.family: "Google Sans Flex, Google Sans, Inter, monospace"
                            }
                        }

                        MouseArea {
                            id: itemArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.copyToClipboard(modelData)
                        }
                    }
                }
            }
        }
    }
}
