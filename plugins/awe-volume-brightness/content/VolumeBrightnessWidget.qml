import QtQuick
import Quickshell
import Quickshell.Io
import "."

Item {
    id: root
    implicitWidth: 280
    implicitHeight: 145

    // State properties
    property real volumeLevel: 0.85
    property bool isMuted: false
    property real brightnessLevel: 0.50

    // ─── System Volume & Brightness Processes ───
    Process {
        id: queryProc
        command: ["sh", "-c", "v=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || echo 'Volume: 0.85'); b=$(brightnessctl -m 2>/dev/null | awk -F',' '{print $4}' | tr -d '%' || echo '50'); echo \"$v;;$b\""]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var line = text.trim()
                if (line.includes(";;")) {
                    var parts = line.split(";;")
                    var vStr = parts[0]
                    var bStr = parts[1]

                    root.isMuted = vStr.includes("[MUTED]")
                    var vMatch = vStr.match(/Volume:\s+([0-9.]+)/)
                    if (vMatch && vMatch[1]) {
                        root.volumeLevel = Math.min(1.0, Math.max(0, parseFloat(vMatch[1])))
                    }

                    var bVal = parseInt(bStr)
                    if (!isNaN(bVal)) {
                        root.brightnessLevel = Math.min(1.0, Math.max(0, bVal / 100.0))
                    }
                }
            }
        }
    }

    Process {
        id: controlProc
        running: false
    }

    function setVolume(val) {
        root.volumeLevel = Math.max(0, Math.min(1.0, val))
        controlProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", root.volumeLevel.toFixed(2)]
        controlProc.running = true
    }

    function toggleMute() {
        controlProc.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
        controlProc.running = true
        root.isMuted = !root.isMuted
    }

    function setBrightness(val) {
        root.brightnessLevel = Math.max(0.05, Math.min(1.0, val))
        var pct = Math.round(root.brightnessLevel * 100)
        controlProc.command = ["brightnessctl", "set", pct + "%"]
        controlProc.running = true
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: queryProc.running = true
    }

    // Theme Palette
    readonly property color colBg: Theme.colBgTile
    readonly property color colBadgeBg: Theme.colPillBg
    readonly property color colPillTrack: Theme.isGlass ? "#55101620" : "#253035"
    readonly property color colAccentVol: Theme.colAccent
    readonly property color colAccentBri: Theme.colAccentGreen
    readonly property color colTextPrimary: Theme.colTextPrimary
    readonly property color colTextSecondary: Theme.colTextSecondary

    // ─── Scaled Visual Content ───
    Item {
        id: scaledContent
        width: 280
        height: 145
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
                spacing: 10

                // Header Pill Badge
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
                                color: root.colAccentVol
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "CONTROLS"
                                color: root.colTextPrimary
                                font.pixelSize: 9
                                font.bold: true
                                font.letterSpacing: 0.6
                                font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                            }
                        }
                    }

                    Item {
                        width: Math.max(0, parent.width - parent.children[0].width - devText.width)
                        height: 1
                    }

                    Text {
                        id: devText
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.isMuted ? "Muted" : (Math.round(root.volumeLevel * 100) + "% | " + Math.round(root.brightnessLevel * 100) + "%")
                        color: root.colTextSecondary
                        font.pixelSize: 10
                        font.bold: true
                        font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                    }
                }

                // ─── Volume Slider Row ───
                Row {
                    width: parent.width
                    height: 38
                    spacing: 8

                    // Volume Mute Button
                    Rectangle {
                        width: 38
                        height: 38
                        radius: 19
                        color: root.isMuted ? "#FFB4AB" : root.colBadgeBg
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

                                ctx.fillStyle = root.isMuted ? "#1E2A30" : "#FFFFFF"
                                // Speaker body
                                ctx.beginPath()
                                ctx.fillRect(cx - 7, cy - 3, 4, 6)
                                ctx.beginPath()
                                ctx.moveTo(cx - 3, cy - 3)
                                ctx.lineTo(cx + 2, cy - 7)
                                ctx.lineTo(cx + 2, cy + 7)
                                ctx.lineTo(cx - 3, cy + 3)
                                ctx.closePath()
                                ctx.fill()

                                if (root.isMuted) {
                                    // Cross line
                                    ctx.strokeStyle = "#1E2A30"
                                    ctx.lineWidth = 1.8
                                    ctx.beginPath()
                                    ctx.moveTo(cx + 4, cy - 4)
                                    ctx.lineTo(cx + 8, cy + 4)
                                    ctx.moveTo(cx + 8, cy - 4)
                                    ctx.lineTo(cx + 4, cy + 4)
                                    ctx.stroke()
                                } else {
                                    // Sound waves
                                    ctx.strokeStyle = "#FFFFFF"
                                    ctx.lineWidth = 1.5
                                    ctx.beginPath()
                                    ctx.arc(cx + 2, cy, 5, -Math.PI * 0.3, Math.PI * 0.3)
                                    ctx.stroke()
                                    if (root.volumeLevel > 0.5) {
                                        ctx.beginPath()
                                        ctx.arc(cx + 2, cy, 9, -Math.PI * 0.3, Math.PI * 0.3)
                                        ctx.stroke()
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleMute()
                        }
                    }

                    // Volume Track
                    Item {
                        width: parent.width - 38 - 8
                        height: 38
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: 19
                            color: root.colPillTrack
                            clip: true
                            antialiasing: true

                            // Active Fill
                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: Math.max(16, parent.width * (root.isMuted ? 0 : root.volumeLevel))
                                radius: 19
                                color: root.isMuted ? "#4D585F" : root.colAccentVol
                                antialiasing: true
                            }

                            // Volume Percentage Label inside track
                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: (root.isMuted ? "0" : Math.round(root.volumeLevel * 100)) + "%"
                                color: root.colTextPrimary
                                font.pixelSize: 11
                                font.bold: true
                                font.family: "Google Sans Flex, Google Sans, Inter, monospace"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true
                            onPositionChanged: (mouse) => {
                                if (pressed) {
                                    root.setVolume(mouse.x / width)
                                }
                            }
                            onClicked: (mouse) => {
                                root.setVolume(mouse.x / width)
                            }
                        }
                    }
                }

                // ─── Brightness Slider Row ───
                Row {
                    width: parent.width
                    height: 38
                    spacing: 8

                    // Brightness Icon Badge
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

                                // Sun circle
                                ctx.beginPath()
                                ctx.arc(cx, cy, 4.5, 0, Math.PI * 2)
                                ctx.fillStyle = "#FFFFFF"
                                ctx.fill()

                                // Sun rays
                                ctx.strokeStyle = "#FFFFFF"
                                ctx.lineWidth = 1.5
                                for (var i = 0; i < 8; i++) {
                                    var ang = i * Math.PI / 4
                                    ctx.beginPath()
                                    ctx.moveTo(cx + Math.cos(ang) * 6.5, cy + Math.sin(ang) * 6.5)
                                    ctx.lineTo(cx + Math.cos(ang) * 9.5, cy + Math.sin(ang) * 9.5)
                                    ctx.stroke()
                                }
                            }
                        }
                    }

                    // Brightness Track
                    Item {
                        width: parent.width - 38 - 8
                        height: 38
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: 19
                            color: root.colPillTrack
                            clip: true
                            antialiasing: true

                            // Active Fill
                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: Math.max(16, parent.width * root.brightnessLevel)
                                radius: 19
                                color: root.colAccentBri
                                antialiasing: true
                            }

                            // Brightness Percentage Label inside track
                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: Math.round(root.brightnessLevel * 100) + "%"
                                color: root.colTextPrimary
                                font.pixelSize: 11
                                font.bold: true
                                font.family: "Google Sans Flex, Google Sans, Inter, monospace"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true
                            onPositionChanged: (mouse) => {
                                if (pressed) {
                                    root.setBrightness(mouse.x / width)
                                }
                            }
                            onClicked: (mouse) => {
                                root.setBrightness(mouse.x / width)
                            }
                        }
                    }
                }
            }
        }
    }
}
