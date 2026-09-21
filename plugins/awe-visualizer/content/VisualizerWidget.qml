import QtQuick
import Quickshell
import Quickshell.Io
import "."

Item {
    id: root
    implicitWidth: 290
    implicitHeight: 150

    // Visualizer modes: "bars" (16-bar spectrum), "wave" (sine soundwave), "radial" (circular)
    property string vizMode: "bars"
    property var modeList: ["bars", "wave", "radial"]
    property int modeIndex: 0
    property bool isPlaying: false
    property real wavePhase: 0

    // MPRIS Player Status Check
    Process {
        id: mprisProc
        command: ["playerctl", "status"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var st = text.trim().toLowerCase()
                root.isPlaying = (st === "playing")
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: mprisProc.running = true
    }

    // High frequency animation timer for wave canvas
    Timer {
        interval: 35
        running: true
        repeat: true
        onTriggered: {
            root.wavePhase = (root.wavePhase + 0.12) % (Math.PI * 2)
            vizCanvas.requestPaint()
        }
    }

    // Theme Palette
    readonly property color colBg: Theme.colBg
    readonly property color colPillBg: Theme.colPillBg
    readonly property color colAccent: Theme.colAccent
    readonly property color colAccentGreen: Theme.colAccentGreen
    readonly property color colAccentLilac: Theme.colAccentWarm
    readonly property color colTextPrimary: Theme.colTextPrimary
    readonly property color colTextSecondary: Theme.colTextSecondary

    // ─── Scaled Visual Content ───
    Item {
        id: scaledContent
        width: 290
        height: 150
        transformOrigin: Item.TopLeft

        // Double-click cycles the mode; press falls through so the host can drag the tile.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            propagateComposedEvents: true

            onDoubleClicked: (mouse) => {
                root.modeIndex = (root.modeIndex + 1) % root.modeList.length
                root.vizMode = root.modeList[root.modeIndex]
                mouse.accepted = false
            }
        }

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

                // Header Row: VISUALIZER Badge + Mode Pill
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
                                color: root.isPlaying ? root.colAccentGreen : root.colAccent
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "SPECTRUM"
                                color: "#FFFFFF"
                                font.pixelSize: 9
                                font.bold: true
                                font.letterSpacing: 0.6
                                font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                            }
                        }
                    }

                    Item {
                        width: Math.max(0, parent.width - parent.children[0].width - modeBadge.width)
                        height: 1
                    }

                    // Mode Switcher Pill
                    Rectangle {
                        id: modeBadge
                        height: 22
                        width: modeLabel.implicitWidth + 16
                        radius: 11
                        color: root.colPillBg
                        antialiasing: true

                        Text {
                            id: modeLabel
                            anchors.centerIn: parent
                            text: (root.vizMode === "bars" ? "16-Bar Equalizer" : (root.vizMode === "wave" ? "Fluid Sine Wave" : "Radial Soundwave"))
                            color: root.colAccent
                            font.pixelSize: 9
                            font.bold: true
                            font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.modeIndex = (root.modeIndex + 1) % root.modeList.length
                                root.vizMode = root.modeList[root.modeIndex]
                            }
                        }
                    }
                }

                // Middle Canvas Visualizer
                Item {
                    width: parent.width
                    height: 74

                    Canvas {
                        id: vizCanvas
                        anchors.fill: parent
                        antialiasing: true

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            var w = width
                            var h = height
                            var cx = w / 2
                            var cy = h / 2
                            var phase = root.wavePhase
                            var amp = root.isPlaying ? 1.0 : 0.35

                            if (root.vizMode === "bars") {
                                // 16-Bar Spectrum Equalizer
                                var numBars = 16
                                var barW = (w - (numBars - 1) * 4) / numBars

                                for (var i = 0; i < numBars; i++) {
                                    var val = Math.sin(phase + i * 0.45) * 0.5 + 0.5
                                    var val2 = Math.cos(phase * 1.3 + i * 0.3) * 0.3 + 0.3
                                    var barH = Math.max(4, (val * 0.7 + val2 * 0.3) * (h - 8) * amp)
                                    var x = i * (barW + 4)
                                    var y = h - barH

                                    // Gradient bar fill
                                    var grad = ctx.createLinearGradient(x, y, x, h)
                                    grad.addColorStop(0, root.colAccent)
                                    grad.addColorStop(1, root.colAccentGreen)
                                    ctx.fillStyle = grad
                                    ctx.fillRect(x, y, barW, barH)
                                }
                            } else if (root.vizMode === "wave") {
                                // Fluid Sine Waveforms
                                ctx.lineWidth = 2.5
                                ctx.strokeStyle = root.colAccent
                                ctx.lineCap = "round"
                                ctx.beginPath()

                                for (var wx = 0; wx <= w; wx += 3) {
                                    var normX = wx / w
                                    var sine = Math.sin(normX * Math.PI * 4 + phase) * Math.cos(normX * Math.PI * 2 + phase * 0.5)
                                    var wy = cy + sine * (h * 0.38) * amp
                                    if (wx === 0) ctx.moveTo(wx, wy)
                                    else ctx.lineTo(wx, wy)
                                }
                                ctx.stroke()

                                // Secondary Harmonic Waveform
                                ctx.lineWidth = 1.5
                                ctx.strokeStyle = root.colAccentGreen
                                ctx.beginPath()

                                for (var wx2 = 0; wx2 <= w; wx2 += 3) {
                                    var normX2 = wx2 / w
                                    var sine2 = Math.sin(normX2 * Math.PI * 6 - phase * 1.2) * 0.7
                                    var wy2 = cy + sine2 * (h * 0.25) * amp
                                    if (wx2 === 0) ctx.moveTo(wx2, wy2)
                                    else ctx.lineTo(wx2, wy2)
                                }
                                ctx.stroke()
                            } else if (root.vizMode === "radial") {
                                // Radial Pulsing Soundwave
                                var rBase = 22
                                ctx.lineWidth = 2
                                ctx.strokeStyle = root.colAccent
                                ctx.beginPath()

                                for (var a = 0; a <= 360; a += 4) {
                                    var rad = a * Math.PI / 180
                                    var waveR = rBase + (Math.sin(a * 6 * Math.PI / 180 + phase * 2) * 9 + Math.cos(a * 3 * Math.PI / 180 - phase) * 4) * amp
                                    var rx = cx + waveR * Math.cos(rad)
                                    var ry = cy + waveR * Math.sin(rad)
                                    if (a === 0) ctx.moveTo(rx, ry)
                                    else ctx.lineTo(rx, ry)
                                }
                                ctx.closePath()
                                ctx.stroke()

                                // Center Core Dot
                                ctx.fillStyle = root.colAccentGreen
                                ctx.beginPath()
                                ctx.arc(cx, cy, 4, 0, Math.PI * 2)
                                ctx.fill()
                            }
                        }
                    }
                }

                // Bottom Status Pill
                Row {
                    width: parent.width
                    Text {
                        text: root.isPlaying ? "Audio Active · Syncing spectrum" : "Ambient Mode · Ready for media"
                        color: root.colTextSecondary
                        font.pixelSize: 9
                        font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                    }
                }
            }
        }
    }
}
