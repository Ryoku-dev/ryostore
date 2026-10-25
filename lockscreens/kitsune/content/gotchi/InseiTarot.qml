/* InseiTarot.qml — Mystical 7-Fold Card
 * ==========================================
 * Holographic card with 3D flip, idle breathe, hover lift, fold-color glow.
 * Back face: position number + large glowing fold sigil + hover tooltip.
 * Front face: fold label + principle after reveal.
 */
import QtQuick
import QtQuick.Effects
import "../tw" as TW

Item {
    id: root

    property string cardName:    "The Oracle"
    property string principle:   "TRUTH"
    property string foldLabel:   "THE EYE"
    property string icon:        "\u25c9"
    property color  accent:      "#4ade80"
    property bool   isRevealed:  false
    property int    revealOrder: -1
    property int    position:    1      // shuffled position 1–7 (shown on back)
    property real   time:        0.0
    property real   _phase:      0.0   // idle breathe phase offset

    implicitWidth:  70
    implicitHeight: 110

    signal tapped()
    signal alreadyDrawn()

    // ── Hover lift ────────────────────────────────────────────────────
    property real _hoverLift: _hov.hovered && !isRevealed ? -8.0 : 0.0
    Behavior on _hoverLift { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    y: _hoverLift

    // ── Flip ──────────────────────────────────────────────────────────
    property real _flipAngle: isRevealed ? 180.0 : 0.0
    Behavior on _flipAngle { NumberAnimation { duration: 550; easing.type: Easing.OutBack; easing.overshoot: 0.18 } }

    // ── Idle breathe — unrevealed only ───────────────────────────────
    readonly property real _breathe: isRevealed ? 0.0
        : 0.04 * Math.sin(time * 0.9 + _phase)

    // ── Already-drawn flash ───────────────────────────────────────────
    property real _flashOpacity: 1.0
    SequentialAnimation {
        id: _flashAnim
        NumberAnimation { target: root; property: "_flashOpacity"; to: 0.3; duration: 80 }
        NumberAnimation { target: root; property: "_flashOpacity"; to: 1.0; duration: 160 }
    }
    opacity: _flashOpacity

    // ── Hover tooltip — shown above card when hovered and not revealed ─
    Item {
        id: _tooltip
        // Positioned above the card, centered
        x:       (root.implicitWidth - _tooltipBg.width) / 2
        y:       -_tooltipBg.height - 6
        width:   _tooltipBg.width
        height:  _tooltipBg.height
        visible: !root.isRevealed
        opacity: _hov.hovered ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        Rectangle {
            id: _tooltipBg
            width:  _tooltipRow.implicitWidth + 14
            height: _tooltipRow.implicitHeight + 8
            radius: 4
            color:  Qt.rgba(0.03, 0.06, 0.10, 0.92)
            border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.45)
            border.width: 1

            Row {
                id: _tooltipRow
                anchors.centerIn: parent
                spacing: 5

                Text {
                    text:           root.icon
                    color:          root.accent
                    font.pixelSize: 11
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    text:           root.foldLabel
                    color:          Qt.rgba(1, 1, 1, 0.85)
                    font.family:    TW.TransparentWorld.fontFamilyMono
                    font.pixelSize: 9
                    font.bold:      true
                    font.letterSpacing: 0.8
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    text:           "·"
                    color:          Qt.rgba(1, 1, 1, 0.30)
                    font.pixelSize: 9
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    text:           root.principle
                    color:          root.accent
                    font.family:    TW.TransparentWorld.fontFamilyMono
                    font.pixelSize: 9
                    font.letterSpacing: 0.8
                    verticalAlignment: Text.AlignVCenter
                }
            }

            // Tooltip glow
            layer.enabled: _hov.hovered
            layer.effect: MultiEffect {
                shadowEnabled: true
                blurEnabled:   false
                shadowColor:   Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.55)
                shadowBlur:    0.8
                shadowVerticalOffset:   0
                shadowHorizontalOffset: 0
            }
        }
    }

    // ── Card container — 3D Y-axis rotation ──────────────────────────
    Item {
        id: _container
        anchors.fill: parent

        transform: Rotation {
            origin.x: _container.width  / 2
            origin.y: _container.height / 2
            axis { x: 0; y: 1; z: 0 }
            angle: root._flipAngle
        }

        // ── Back face ─────────────────────────────────────────────────
        Rectangle {
            id: _back
            anchors.fill: parent
            visible: root._flipAngle < 90
            color:   "#080d12"
            radius:  5
            border.color: _hov.hovered
                ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.70)
                : Qt.rgba(1, 1, 1, 0.10 + root._breathe * 2)
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 120 } }

            // Geometric lattice — tints toward accent on hover
            Canvas {
                id: _lattice
                anchors { fill: parent; margins: 2 }
                renderStrategy: Canvas.Cooperative
                renderTarget:   Canvas.FramebufferObject

                // Dirty-flag repaint on hover change only
                property bool _dirty: false
                onVisibleChanged: _dirty = true

                Connections {
                    target: _hov
                    function onHoveredChanged() { _lattice._dirty = true }
                }

                Timer {
                    interval: 100
                    running:  _lattice.visible
                    repeat:   true
                    onTriggered: {
                        if (_lattice._dirty) {
                            _lattice._dirty = false
                            _lattice.requestPaint()
                        }
                    }
                }

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    var alpha = _hov.hovered ? 0.28 : 0.15
                    var r = _hov.hovered ? root.accent.r * 0.4 : 0.15
                    var g = _hov.hovered ? root.accent.g * 0.4 : 0.35
                    var b = _hov.hovered ? root.accent.b * 0.4 : 0.55
                    ctx.strokeStyle = Qt.rgba(r, g, b, alpha)
                    ctx.lineWidth = 0.8
                    for (var i = 0; i <= width; i += 9) {
                        ctx.beginPath(); ctx.moveTo(i, 0);      ctx.lineTo(width - i, height); ctx.stroke()
                        ctx.beginPath(); ctx.moveTo(i, height); ctx.lineTo(width - i, 0);      ctx.stroke()
                    }
                }
            }

            // Position number — top left
            Text {
                anchors { top: parent.top; left: parent.left; margins: 5 }
                text:           root.position.toString()
                color:          _hov.hovered
                    ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.90)
                    : Qt.rgba(1, 1, 1, 0.45 + root._breathe * 2)
                font.family:    TW.TransparentWorld.fontFamilyMono
                font.pixelSize: 12
                font.bold:      true
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            // ── Fold sigil — center, large, glowing ───────────────────
            Item {
                id: _sigilContainer
                anchors.centerIn: parent
                width:  42
                height: 42

                Text {
                    id: _sigil
                    anchors.centerIn: parent
                    text:           root.icon
                    color:          Qt.rgba(
                                        root.accent.r,
                                        root.accent.g,
                                        root.accent.b,
                                        0.75 + root._breathe * 3 + (_hov.hovered ? 0.20 : 0.0)
                                    )
                    font.pixelSize: 32
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                // Sigil bloom — dedicated glow layer on the sigil itself
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    blurEnabled:   false
                    shadowColor:   Qt.rgba(
                                       root.accent.r,
                                       root.accent.g,
                                       root.accent.b,
                                       _hov.hovered
                                           ? 0.90 + root._breathe * 2
                                           : 0.55 + root._breathe * 4
                                   )
                    shadowBlur:           0.95
                    shadowVerticalOffset:   0
                    shadowHorizontalOffset: 0
                }
            }

            // Position number — bottom right (mirror)
            Text {
                anchors { bottom: parent.bottom; right: parent.right; margins: 5 }
                text:           root.position.toString()
                color:          _hov.hovered
                    ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.90)
                    : Qt.rgba(1, 1, 1, 0.45 + root._breathe * 2)
                font.family:    TW.TransparentWorld.fontFamilyMono
                font.pixelSize: 12
                font.bold:      true
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            // Card outer glow — hover intensifies in accent color
            layer.enabled: !root.isRevealed
            layer.effect: MultiEffect {
                shadowEnabled: true
                blurEnabled:   false
                shadowColor: _hov.hovered
                    ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.60)
                    : Qt.rgba(0, 0.7, 1.0, 0.14 + root._breathe * 3)
                shadowBlur:           0.7
                shadowVerticalOffset:   0
                shadowHorizontalOffset: 0
            }
        }

        // ── Front face ────────────────────────────────────────────────
        Rectangle {
            id: _front
            anchors.fill: parent
            visible: root._flipAngle >= 90
            color:   "#0b1018"
            radius:  5
            border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.55)
            border.width: 1

            transform: Rotation {
                origin.x: _front.width  / 2
                origin.y: _front.height / 2
                axis { x: 0; y: 1; z: 0 }
                angle: 180
            }

            Rectangle {
                anchors.fill: parent
                radius: 5
                color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.06)
            }

            Column {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text:           root.icon
                    color:          root.accent
                    font.pixelSize: 24
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text:           root.foldLabel
                    color:          Qt.rgba(1, 1, 1, 0.90)
                    font.family:    TW.TransparentWorld.fontFamilyMono
                    font.pixelSize: 7
                    font.bold:      true
                    font.letterSpacing: 0.5
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text:           root.principle
                    color:          root.accent
                    font.family:    TW.TransparentWorld.fontFamilyMono
                    font.pixelSize: 7
                    font.letterSpacing: 1
                }
            }

            // Reveal order badge
            Rectangle {
                anchors { top: parent.top; right: parent.right; margins: 4 }
                width: 14; height: 14; radius: 7
                color:   root.accent
                visible: root.revealOrder >= 0
                Text {
                    anchors.centerIn: parent
                    text:           (root.revealOrder + 1).toString()
                    color:          "#000000"
                    font.pixelSize: 9
                    font.bold:      true
                }
            }

            layer.enabled: root.isRevealed
            layer.effect: MultiEffect {
                shadowEnabled: true
                blurEnabled:   false
                shadowColor:   Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.50)
                shadowBlur:    0.85
                shadowVerticalOffset:   0
                shadowHorizontalOffset: 0
            }
        }
    }

    TapHandler {
        onTapped: root.tapped()
        cursorShape: Qt.PointingHandCursor
    }

    HoverHandler {
        id: _hov
        cursorShape: Qt.PointingHandCursor
    }
}
