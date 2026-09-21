import QtQuick
import Quickshell
import Quickshell.Io
import "."

Item {
    id: root
    implicitWidth: 270
    implicitHeight: 210

    // Resource percentages (0 - 100)
    property real cpuUsage: 18
    property real ramUsage: 42
    property real diskUsage: 55
    property real tempUsage: 48

    // Process to query system resources
    Process {
        id: statsProc
        command: ["sh", "-c", "cpu=$(grep 'cpu ' /proc/stat | awk '{u=$2+$4; t=$2+$4+$5; if(t>0) print int(u*100/t); else print 15}'); mem=$(free | awk '/Mem:/ {print int($3*100/$2)}'); disk=$(df / | awk 'NR==2 {print int($5)}'); temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{print int($1/1000)}'); echo \"${cpu:-15};;${mem:-40};;${disk:-50};;${temp:-45}\""]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var line = text.trim()
                if (line.includes(";;")) {
                    var parts = line.split(";;")
                    root.cpuUsage = Math.min(100, Math.max(2, parseFloat(parts[0]) || 15))
                    root.ramUsage = Math.min(100, Math.max(2, parseFloat(parts[1]) || 40))
                    root.diskUsage = Math.min(100, Math.max(2, parseFloat(parts[2]) || 50))
                    root.tempUsage = Math.min(100, Math.max(2, parseFloat(parts[3]) || 45))
                    wheelCanvas.requestPaint()
                }
            }
        }
    }

    Timer {
        interval: 2500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: statsProc.running = true
    }

    // Theme Palette
    readonly property color colBg: Theme.colBg
    readonly property color colBadgeBg: Theme.colPillBg
    readonly property color colCpu: Theme.colAccent
    readonly property color colRam: Theme.colAccentGreen
    readonly property color colDisk: Theme.colAccentWarning
    readonly property color colTemp: Theme.colAccentWarm
    readonly property color colTextPrimary: Theme.colTextPrimary
    readonly property color colTextSecondary: Theme.colTextSecondary

    // ─── Scaled Visual Content ───
    Item {
        id: scaledContent
        width: 270
        height: 210
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

                // Header Row: GAUGE Pill Badge
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
                                color: root.colCpu
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "RESOURCE WHEEL"
                                color: root.colTextPrimary
                                font.pixelSize: 9
                                font.bold: true
                                font.letterSpacing: 0.6
                                font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                            }
                        }
                    }
                }

                // Middle: Concentric Circular Arcs + Legend
                Row {
                    width: parent.width
                    spacing: 12

                    // Concentric Gauge Wheel Canvas
                    Item {
                        width: 116
                        height: 116

                        Canvas {
                            id: wheelCanvas
                            anchors.fill: parent
                            antialiasing: true

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                var cx = width / 2
                                var cy = height / 2

                                var rings = [
                                    { r: 50, val: root.cpuUsage, col: root.colCpu },
                                    { r: 40, val: root.ramUsage, col: root.colRam },
                                    { r: 30, val: root.diskUsage, col: root.colDisk },
                                    { r: 20, val: root.tempUsage, col: root.colTemp }
                                ]

                                for (var i = 0; i < rings.length; i++) {
                                    var ring = rings[i]

                                    // Base muted track
                                    ctx.strokeStyle = root.colBadgeBg
                                    ctx.lineWidth = 4.5
                                    ctx.beginPath()
                                    ctx.arc(cx, cy, ring.r, 0, Math.PI * 2)
                                    ctx.stroke()

                                    // Active progress arc
                                    var ratio = Math.min(1.0, ring.val / 100.0)
                                    ctx.strokeStyle = ring.col
                                    ctx.lineWidth = 4.5
                                    ctx.lineCap = "round"
                                    ctx.beginPath()
                                    ctx.arc(cx, cy, ring.r, -Math.PI / 2, -Math.PI / 2 + (ratio * Math.PI * 2), false)
                                    ctx.stroke()
                                }
                            }
                        }

                        // Center Value
                        Column {
                            anchors.centerIn: parent
                            spacing: -2

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Math.round(root.cpuUsage) + "%"
                                color: root.colTextPrimary
                                font.pixelSize: 14
                                font.bold: true
                                font.family: "Google Sans Flex, Google Sans, Inter, monospace"
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "CPU"
                                color: root.colCpu
                                font.pixelSize: 8
                                font.bold: true
                                font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                            }
                        }
                    }

                    // Legend Metrics Column
                    Column {
                        width: parent.width - 116 - 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5

                        // CPU
                        Row {
                            spacing: 6
                            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 6; height: 6; radius: 3; color: root.colCpu }
                            Text { text: "CPU: " + Math.round(root.cpuUsage) + "%"; color: root.colTextPrimary; font.pixelSize: 10; font.family: "Google Sans Flex, Google Sans, Inter, monospace" }
                        }

                        // RAM
                        Row {
                            spacing: 6
                            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 6; height: 6; radius: 3; color: root.colRam }
                            Text { text: "RAM: " + Math.round(root.ramUsage) + "%"; color: root.colTextPrimary; font.pixelSize: 10; font.family: "Google Sans Flex, Google Sans, Inter, monospace" }
                        }

                        // DISK
                        Row {
                            spacing: 6
                            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 6; height: 6; radius: 3; color: root.colDisk }
                            Text { text: "Disk: " + Math.round(root.diskUsage) + "%"; color: root.colTextPrimary; font.pixelSize: 10; font.family: "Google Sans Flex, Google Sans, Inter, monospace" }
                        }

                        // TEMP
                        Row {
                            spacing: 6
                            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 6; height: 6; radius: 3; color: root.colTemp }
                            Text { text: "Temp: " + Math.round(root.tempUsage) + "°"; color: root.colTextPrimary; font.pixelSize: 10; font.family: "Google Sans Flex, Google Sans, Inter, monospace" }
                        }
                    }
                }

                // Bottom Status
                Text {
                    text: "Hardware telemetry updated in real time"
                    color: root.colTextSecondary
                    font.pixelSize: 9
                    font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                }
            }
        }
    }
}
