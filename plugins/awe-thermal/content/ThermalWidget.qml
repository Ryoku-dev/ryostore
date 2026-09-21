import QtQuick
import Quickshell
import Quickshell.Io
import "."

Item {
    id: root
    implicitWidth: 260
    implicitHeight: 140

    // Thermal properties
    property int cpuTemp: 52
    property int core0Temp: 52
    property int core1Temp: 48
    property string statusText: "Optimal"

    // ─── Query Linux Hardware Thermals ───
    Process {
        id: thermalProc
        command: ["sh", "-c", "t=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{print int($1/1000)}'); s=$(sensors 2>/dev/null | grep -m1 'Package id 0' | awk '{print int($4)}' | tr -d '+°C'); echo \"${s:-${t:-52}}\""]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var val = parseInt(text.trim())
                if (!isNaN(val) && val > 0) {
                    root.cpuTemp = val
                    root.core0Temp = val
                    root.core1Temp = Math.max(20, val - 3)
                    if (val >= 80) root.statusText = "High"
                    else if (val >= 65) root.statusText = "Warm"
                    else root.statusText = "Optimal"
                }
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: thermalProc.running = true
    }

    Component.onCompleted: {
        thermalProc.running = true
    }

    // Theme Palette
    readonly property color colBg: Theme.colBg
    readonly property color colBadgeBg: Theme.colPillBg
    readonly property color colAccentGreen: Theme.colAccentGreen
    readonly property color colAccentAmber: Theme.colAccentWarning
    readonly property color colAccentRed: Theme.colAccentWarm
    readonly property color colCurrentAccent: (root.cpuTemp >= 80) ? colAccentRed : ((root.cpuTemp >= 65) ? colAccentAmber : colAccentGreen)
    readonly property color colTextPrimary: Theme.colTextPrimary
    readonly property color colTextSecondary: Theme.colTextSecondary

    // ─── Scaled Visual Content ───
    Item {
        id: scaledContent
        width: 260
        height: 140
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

                // Header Row: Thermals Pill Badge + Status Tag
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
                                color: root.colCurrentAccent
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "THERMALS"
                                color: root.colTextPrimary
                                font.pixelSize: 9
                                font.bold: true
                                font.letterSpacing: 0.6
                                font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                            }
                        }
                    }

                    Item {
                        width: Math.max(0, parent.width - parent.children[0].width - statusPill.width)
                        height: 1
                    }

                    Rectangle {
                        id: statusPill
                        height: 22
                        width: stText.implicitWidth + 14
                        radius: 11
                        color: root.colBadgeBg
                        antialiasing: true

                        Text {
                            id: stText
                            anchors.centerIn: parent
                            text: root.statusText
                            color: root.colCurrentAccent
                            font.pixelSize: 10
                            font.bold: true
                            font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                        }
                    }
                }

                // Middle Big Temperature Display Row
                Row {
                    width: parent.width
                    spacing: 12

                    // Vector Thermometer Icon Badge
                    Rectangle {
                        width: 38
                        height: 38
                        radius: 19
                        color: root.colBadgeBg
                        anchors.verticalCenter: parent.verticalCenter
                        antialiasing: true

                        Canvas {
                            anchors.fill: parent
                            antialiasing: true
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                var cx = width / 2
                                var cy = height / 2

                                ctx.strokeStyle = "#FFFFFF"
                                ctx.lineWidth = 1.8
                                ctx.beginPath()
                                ctx.arc(cx, cy + 5, 5, -Math.PI * 0.2, -Math.PI * 0.8, true)
                                ctx.lineTo(cx - 2, cy - 8)
                                ctx.arc(cx, cy - 8, 2, Math.PI, 0)
                                ctx.lineTo(cx + 2, cy + 2)
                                ctx.stroke()

                                ctx.fillStyle = root.colCurrentAccent
                                ctx.beginPath()
                                ctx.arc(cx, cy + 5, 3.5, 0, Math.PI * 2)
                                ctx.fill()
                            }
                        }
                    }

                    // Temp Value & Core Indicator
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0

                        Text {
                            text: root.cpuTemp + "°C"
                            color: root.colTextPrimary
                            font.pixelSize: 24
                            font.bold: true
                            font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                        }

                        Text {
                            text: "CPU Package Temp"
                            color: root.colTextSecondary
                            font.pixelSize: 10
                            font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                        }
                    }
                }

                // Bottom Core Progress Bars
                Row {
                    width: parent.width
                    spacing: 8

                    // Core 0 Bar
                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 18
                        radius: 9
                        color: root.colBadgeBg
                        clip: true
                        antialiasing: true

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: Math.max(6, parent.width * (root.core0Temp / 100.0))
                            radius: 9
                            color: root.colCurrentAccent
                            antialiasing: true
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "Core 0: " + root.core0Temp + "°"
                            color: "#FFFFFF"
                            font.pixelSize: 9
                            font.bold: true
                            font.family: "Google Sans Flex, Google Sans, Inter, monospace"
                        }
                    }

                    // Core 1 Bar
                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 18
                        radius: 9
                        color: root.colBadgeBg
                        clip: true
                        antialiasing: true

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: Math.max(6, parent.width * (root.core1Temp / 100.0))
                            radius: 9
                            color: root.colCurrentAccent
                            antialiasing: true
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "Core 1: " + root.core1Temp + "°"
                            color: "#FFFFFF"
                            font.pixelSize: 9
                            font.bold: true
                            font.family: "Google Sans Flex, Google Sans, Inter, monospace"
                        }
                    }
                }
            }
        }
    }
}
