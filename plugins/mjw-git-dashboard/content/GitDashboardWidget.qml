import QtQuick
import Quickshell
import Quickshell.Io
import "."

Item {
    id: root
    implicitWidth: 290
    implicitHeight: 155

    // Git Status Properties
    property string branchName: "main"
    property int modifiedCount: 0
    property string lastHash: "head"
    property string lastAuthor: "Dev"
    property string lastMessage: "Ready"
    property bool isClean: true

    // Process to query Git status
    Process {
        id: gitProc
        command: ["sh", "-c", "cd \"$HOME\" && b=$(git rev-parse --abbrev-ref HEAD 2>/dev/null); m=$(git status --porcelain 2>/dev/null | wc -l); l=$(git log -1 --format='%h;;%an;;%s' 2>/dev/null); echo \"${b:-main};;${m:-0};;${l:-none;;Dev;;No commits}\""]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var line = text.trim()
                if (line.includes(";;")) {
                    var parts = line.split(";;")
                    root.branchName = parts[0] || "main"
                    var count = parseInt(parts[1]) || 0
                    root.modifiedCount = count
                    root.isClean = (count === 0)
                    root.lastHash = parts[2] || "head"
                    root.lastAuthor = parts[3] || "Author"
                    root.lastMessage = parts[4] || "Latest updates"
                }
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: gitProc.running = true
    }

    // Theme Palette
    readonly property color colBg: Theme.colBg
    readonly property color colBadgeBg: Theme.colPillBg
    readonly property color colAccent: Theme.colAccent
    readonly property color colCleanGreen: Theme.colAccentGreen
    readonly property color colDirtyAmber: Theme.colAccentWarning
    readonly property color colTextPrimary: Theme.colTextPrimary
    readonly property color colTextSecondary: Theme.colTextSecondary

    // ─── Scaled Visual Content ───
    Item {
        id: scaledContent
        width: 290
        height: 155
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

                // Header Row: GIT DASHBOARD Badge + Branch Pill
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
                                color: root.isClean ? root.colCleanGreen : root.colDirtyAmber
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "GIT REPO"
                                color: root.colTextPrimary
                                font.pixelSize: 9
                                font.bold: true
                                font.letterSpacing: 0.6
                                font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                            }
                        }
                    }

                    Item {
                        width: Math.max(0, parent.width - parent.children[0].width - branchPill.width)
                        height: 1
                    }

                    // Active Branch Pill
                    Rectangle {
                        id: branchPill
                        height: 22
                        width: brRow.implicitWidth + 14
                        radius: 11
                        color: root.colBadgeBg
                        antialiasing: true

                        Row {
                            id: brRow
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: "⎇"
                                color: root.colAccent
                                font.pixelSize: 11
                                font.bold: true
                            }

                            Text {
                                text: root.branchName
                                color: root.colTextPrimary
                                font.pixelSize: 10
                                font.bold: true
                                font.family: "Google Sans Flex, Google Sans, Inter, monospace"
                            }
                        }
                    }
                }

                // Middle: Status & Last Commit Snippet
                Rectangle {
                    width: parent.width
                    height: 52
                    radius: 16
                    color: root.colBadgeBg
                    antialiasing: true

                    Column {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 2

                        Row {
                            spacing: 6
                            Rectangle {
                                height: 14
                                width: hashText.implicitWidth + 8
                                radius: 7
                                color: "#25343B"
                                antialiasing: true

                                Text {
                                    id: hashText
                                    anchors.centerIn: parent
                                    text: root.lastHash
                                    color: root.colAccent
                                    font.pixelSize: 9
                                    font.bold: true
                                    font.family: "Google Sans Flex, Google Sans, Inter, monospace"
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.lastAuthor
                                color: root.colTextSecondary
                                font.pixelSize: 10
                                font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                            }
                        }

                        Text {
                            width: parent.width
                            text: root.lastMessage
                            color: root.colTextPrimary
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                        }
                    }
                }

                // Bottom Status Pill Row
                Row {
                    width: parent.width

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.isClean ? "Working tree clean ✓" : (root.modifiedCount + " uncommitted changes")
                        color: root.isClean ? root.colCleanGreen : root.colDirtyAmber
                        font.pixelSize: 10
                        font.bold: true
                        font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                    }

                    Item {
                        width: Math.max(0, parent.width - parent.children[0].width - syncBtn.width)
                        height: 1
                    }

                    Rectangle {
                        id: syncBtn
                        height: 20
                        width: 48
                        radius: 10
                        color: "#25343B"
                        antialiasing: true

                        Text {
                            anchors.centerIn: parent
                            text: "Sync"
                            color: root.colAccent
                            font.pixelSize: 9
                            font.bold: true
                            font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: gitProc.running = true
                        }
                    }
                }
            }
        }
    }
}
