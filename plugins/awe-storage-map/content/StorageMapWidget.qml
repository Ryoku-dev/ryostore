import QtQuick
import Quickshell
import Quickshell.Io
import "."

Item {
    id: root
    implicitWidth: 270
    implicitHeight: 150

    // Storage metrics
    property string totalSize: "448 GB"
    property string usedSize: "32 GB"
    property string freeSize: "413 GB"
    property real usedPercent: 8.0

    // Disk space query process
    Process {
        id: diskProc
        command: ["sh", "-c", "df -h / | awk 'NR==2 {print $2\";;\"$3\";;\"$4\";;\"$5}' | tr -d '%'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var line = text.trim()
                if (line.includes(";;")) {
                    var parts = line.split(";;")
                    root.totalSize = parts[0] || "448G"
                    root.usedSize = parts[1] || "32G"
                    root.freeSize = parts[2] || "413G"
                    root.usedPercent = Math.min(100, Math.max(1, parseFloat(parts[3]) || 8))
                }
            }
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: diskProc.running = true
    }

    // Theme Palette
    readonly property color colBg: Theme.colBg
    readonly property color colPillBg: Theme.colPillBg
    readonly property color colAccent: Theme.colAccent
    readonly property color colAccentGreen: Theme.colAccentGreen
    readonly property color colAccentAmber: Theme.colAccentWarning
    readonly property color colTextPrimary: Theme.colTextPrimary
    readonly property color colTextSecondary: Theme.colTextSecondary

    // ─── Scaled Visual Content ───
    Item {
        id: scaledContent
        width: 270
        height: 150
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

                // Header Row: STORAGE Badge + Percent
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
                                color: root.colAccentAmber
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "STORAGE MAP"
                                color: "#FFFFFF"
                                font.pixelSize: 9
                                font.bold: true
                                font.letterSpacing: 0.6
                                font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                            }
                        }
                    }

                    Item {
                        width: Math.max(0, parent.width - parent.children[0].width - pctTag.width)
                        height: 1
                    }

                    Rectangle {
                        id: pctTag
                        height: 22
                        width: pctText.implicitWidth + 14
                        radius: 11
                        color: root.colPillBg
                        antialiasing: true

                        Text {
                            id: pctText
                            anchors.centerIn: parent
                            text: Math.round(root.usedPercent) + "% Used"
                            color: root.colAccentAmber
                            font.pixelSize: 9
                            font.bold: true
                            font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                        }
                    }
                }

                // Middle: Segmented Visual Bar
                Column {
                    width: parent.width
                    spacing: 6

                    // Segmented Progress Bar
                    Rectangle {
                        width: parent.width
                        height: 18
                        radius: 9
                        color: root.colPillBg
                        clip: true
                        antialiasing: true

                        // Used Space Fill
                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: Math.max(10, parent.width * (root.usedPercent / 100.0))
                            radius: 9
                            color: root.colAccentAmber
                            antialiasing: true
                        }
                    }

                    // Numeric Metrics Breakdown
                    Row {
                        width: parent.width

                        Text {
                            text: "Used: " + root.usedSize
                            color: root.colAccentAmber
                            font.pixelSize: 10
                            font.bold: true
                            font.family: "Google Sans Flex, Google Sans, Inter, monospace"
                        }

                        Item {
                            width: Math.max(0, parent.width - 90 - 90)
                            height: 1
                        }

                        Text {
                            text: "Free: " + root.freeSize
                            color: root.colAccentGreen
                            font.pixelSize: 10
                            font.bold: true
                            font.family: "Google Sans Flex, Google Sans, Inter, monospace"
                        }
                    }
                }

                // Bottom Partition Label
                Row {
                    width: parent.width
                    spacing: 6

                    Rectangle {
                        height: 20
                        width: (parent.width - 6) / 2
                        radius: 10
                        color: root.colPillBg
                        antialiasing: true

                        Row {
                            anchors.centerIn: parent
                            spacing: 5
                            Text { text: "Root (/):"; color: root.colTextSecondary; font.pixelSize: 9; font.family: "Google Sans Flex, Google Sans, Inter, sans-serif" }
                            Text { text: root.totalSize; color: "#FFFFFF"; font.pixelSize: 9; font.bold: true; font.family: "Google Sans Flex, Google Sans, Inter, monospace" }
                        }
                    }

                    Rectangle {
                        height: 20
                        width: (parent.width - 6) / 2
                        radius: 10
                        color: root.colPillBg
                        antialiasing: true

                        Row {
                            anchors.centerIn: parent
                            spacing: 5
                            Text { text: "Status:"; color: root.colTextSecondary; font.pixelSize: 9; font.family: "Google Sans Flex, Google Sans, Inter, sans-serif" }
                            Text { text: "Optimal"; color: root.colAccentGreen; font.pixelSize: 9; font.bold: true; font.family: "Google Sans Flex, Google Sans, Inter, sans-serif" }
                        }
                    }
                }
            }
        }
    }
}
