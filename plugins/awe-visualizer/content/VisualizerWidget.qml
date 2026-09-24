import QtQuick
import "."

Item {
    id: root
    implicitWidth: 290
    implicitHeight: 150

    // Visualizer modes: "bars" (16-band spectrum), "wave" (scope waveform),
    // "radial" (circular). All three draw the tile's own cava spectrum (the
    // `levels`/`energy` fed down from service/Main.qml) instead of a sine
    // animation, so the tile answers to whatever is actually playing.
    property string vizMode: "bars"
    property var modeList: ["bars", "wave", "radial"]
    property int modeIndex: 0
    property real wavePhase: 0

    // The analyser settles to all-zero bands on silence; energy is the mean
    // level, so it is the honest play/pause signal (and it covers browser and
    // game audio that has no MPRIS interface, which playerctl could not see).
    property var levels: []
    property real energy: 0
    readonly property bool isPlaying: energy > 0.02

    // Resample the 40 cava bands to n, linearly, so every mode reads the real
    // spectrum at whatever width it draws.
    function band(n, i) {
        var src = (levels && levels.length) ? levels : null;
        if (!src)
            return 0;
        var t = n > 1 ? i / (n - 1) : 0;
        var f = t * (src.length - 1);
        var a = Math.floor(f);
        var b = Math.min(src.length - 1, a + 1);
        return src[a] + (src[b] - src[a]) * (f - a);
    }

    // Redraw the moment a real frame arrives; the timer only carries the
    // idle shimmer and the wave/radial scroll, and runs while playing.
    function repaint() {
        vizCanvas.requestPaint();
    }
    onLevelsChanged: repaint()
    onEnergyChanged: repaint()

    // Idle breath so the tile is alive with nothing playing; the paint adds it
    // at a small amplitude, so silence reads as a resting line, not a flat gap.
    Timer {
        id: shimmer
        interval: 45
        running: true
        repeat: true
        onTriggered: {
            root.wavePhase = (root.wavePhase + 0.12) % (Math.PI * 2);
            if (!root.isPlaying)
                root.repaint();
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
                            // A faint resting breath keeps the tile alive on
                            // silence; the real spectrum dominates once playing.
                            var idle = 0.06 * (0.5 + 0.5 * Math.sin(phase))

                            if (root.vizMode === "bars") {
                                // 16-band spectrum, resampled from the cava feed.
                                var numBars = 16
                                var barW = (w - (numBars - 1) * 4) / numBars
                                for (var i = 0; i < numBars; i++) {
                                    var val = root.band(numBars, i) + idle
                                    var barH = Math.max(3, Math.min(h, val * (h - 8)))
                                    var x = i * (barW + 4)
                                    var y = h - barH
                                    var grad = ctx.createLinearGradient(x, y, x, h)
                                    grad.addColorStop(0, root.colAccent)
                                    grad.addColorStop(1, root.colAccentGreen)
                                    ctx.fillStyle = grad
                                    ctx.fillRect(x, y, barW, barH)
                                }
                            } else if (root.vizMode === "wave") {
                                // The spectrum drawn as a centred waveform: the
                                // 40 bands mirrored left-to-right into one curve.
                                var pts = 60
                                ctx.lineWidth = 2.5
                                ctx.strokeStyle = root.colAccent
                                ctx.lineCap = "round"
                                ctx.beginPath()
                                for (var k = 0; k <= pts; k++) {
                                    var normX = k / pts
                                    // fold so the centre is the loudest band edge
                                    var bi = normX < 0.5 ? normX * 2 : (1 - normX) * 2
                                    var lvl = root.band(24, Math.round(bi * 23))
                                    var wy = cy - (lvl + idle) * (h * 0.42)
                                    var px = normX * w
                                    if (k === 0) ctx.moveTo(px, wy); else ctx.lineTo(px, wy)
                                }
                                ctx.stroke()
                            } else if (root.vizMode === "radial") {
                                // A ring whose radius breathes with the spectrum.
                                var rBase = 22
                                var steps = 72
                                ctx.lineWidth = 2
                                ctx.strokeStyle = root.colAccent
                                ctx.beginPath()
                                for (var s = 0; s <= steps; s++) {
                                    var a = (s / steps) * 360
                                    var rad = a * Math.PI / 180
                                    var lvl = root.band(steps, s % steps)
                                    var waveR = rBase + (lvl + idle) * 26
                                    var rx = cx + waveR * Math.cos(rad)
                                    var ry = cy + waveR * Math.sin(rad)
                                    if (s === 0) ctx.moveTo(rx, ry); else ctx.lineTo(rx, ry)
                                }
                                ctx.closePath()
                                ctx.stroke()
                                ctx.fillStyle = root.colAccentGreen
                                ctx.beginPath()
                                ctx.arc(cx, cy, 4 + root.energy * 10, 0, Math.PI * 2)
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
