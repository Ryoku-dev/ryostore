/* InseiHub.qml — Ase's Living Portal (Unbound)
 * ============================================
 * Simplified, holographic HUD. Ase floats directly on the overlay
 * surrounded by her 7 orbital sigils. No rigid shell.
 *
 * §14.8 — Cooperative + FBO, dynamic orbital physics.
 */
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import "../tw" as TW
import "."

Item {
    id: root

    // ── Geometry ──────────────────────────────────────────────────────
    readonly property real _width:   340
    readonly property real _height:  400
    readonly property real _aseSize: 180   // companion scale target
    readonly property real _orbitR:  110   // default orbit radius
    readonly property real _activeR: 85    // radius when fold is drawn

    width:          _width
    height:         _height
    implicitWidth:  _width
    implicitHeight: _height

    // ── Position Reporting ────────────────────────────────────────────
    function _reportPosition() {
        TW.ArOrchestrator.aseWidgetCenterX = 0.5
        TW.ArOrchestrator.aseWidgetCenterY = 0.0
    }
    Component.onCompleted: Qt.callLater(_reportPosition)

    // ── Derived State ─────────────────────────────────────────────────
    readonly property color  _accent:    TW.ArOrchestrator.prismaticColor
    readonly property bool   _thinking:  TW.ArOrchestrator.thinkingPhase > 0
    readonly property string _phase:     TW.ArOrchestrator.scryCommPhase || "idle"
    readonly property bool   _online:    TW.ArOrchestrator.daemonState === "alive"
    readonly property var    _drawn:     TW.ArOrchestrator.aseDrawnFolds || []
    readonly property string _activeMode: TW.ArOrchestrator.intelActiveMode || ""
    readonly property real   _cmdPulse:  TW.ArOrchestrator.commandPulse || 0.0
    readonly property real   _animPhase: TW.ArOrchestrator.animationPhase || 0.0

    // Style accent — bleeds with breathingStyle
    readonly property color _styleAccent: {
        var s = TW.ArOrchestrator.breathingStyle || "moon"
        var sa = TW.TransparentWorld.styleAccents
        return sa[s] ? Qt.color(sa[s]) : _accent
    }

    // ── Fold Definitions (Sibyl Trinity Alignment) ───────────────────
    readonly property var _folds: [
        { id: "eye",     sigil: "◉", color: TW.TransparentWorld.accentEye      },
        { id: "phantom", sigil: "⊗", color: TW.TransparentWorld.accentPhantom  },
        { id: "blade",   sigil: "⚔", color: TW.TransparentWorld.accentBlade    },
        { id: "sage",    sigil: "◈", color: TW.TransparentWorld.accentSage     },
        { id: "shroud",  sigil: "☁", color: TW.TransparentWorld.accentShroud   },
        { id: "forge",   sigil: "⬡", color: TW.TransparentWorld.accentForgeFold },
        { id: "mirror",  sigil: "◌", color: TW.TransparentWorld.accentMirror   }
    ]

    // ── Animation Clock ───────────────────────────────────────────────
    property real _time: 0.0
    NumberAnimation on _time {
        from: 0; to: 100000; duration: 100000000
        loops: Animation.Infinite
        running: root.visible
    }

    // ── Viewport Center ───────────────────────────────────────────────
    readonly property real _cx: width / 2
    readonly property real _cy: height * 0.45

    // ── Companion — Ase Unbound ───────────────────────────────────────
    Item {
        id: _aseContainer
        x: root._cx - root._aseSize / 2
        y: root._cy - root._aseSize / 2
        width:  root._aseSize
        height: root._aseSize
        z: 10

        // InseiSoul — the living void
        ShaderEffect {
            anchors.fill: parent
            property real time:            root._time * (root._thinking ? 2.2 : 1.0)
            property real tpsBeat:         Math.min(1.0, (TW.ArOrchestrator.shiguruiTokensPerSec || 0) / 30.0)
            property real inferring:       root._thinking ? 1.0 : 0.0
            property real disciplineHue:   0.55 // Default
            property real commandPulse:    root._cmdPulse
            property real obeliskOpen:     1.0
            property real cursorX:         0.5
            property real cursorY:         0.5
            property real w:               width
            property real h:               height
            property real mistDensity:     root._online ? 0.0 : 0.6
            property real receivePulse:    0.0
            fragmentShader: "../shaders/InseiSoul.frag.qsb"
        }

        InseiCompanion {
            id: _ase
            anchors.centerIn: parent
            scale:     root._aseSize / 260.0
            foldColor: root._accent
            time:      root._time * (root._thinking ? 2.2 : 1.0)
        }

        // Action potential ripple
        Rectangle {
            anchors.centerIn: parent
            width:  parent.width * 1.5; height: width; radius: width / 2
            color:  "transparent"
            border.width: 1.5
            border.color: Qt.rgba(root._accent.r, root._accent.g, root._accent.b, 0.4)
            opacity: 0.0
            scale:   0.5

            SequentialAnimation on opacity {
                running: root._cmdPulse > 0.1
                NumberAnimation { from: 0.6; to: 0.0; duration: 800; easing.type: Easing.OutCubic }
            }
            SequentialAnimation on scale {
                running: root._cmdPulse > 0.1
                NumberAnimation { from: 0.5; to: 1.5; duration: 800; easing.type: Easing.OutCubic }
            }
        }
    }

    // ── Orbital Sigils — 7 dynamic indicators ─────────────────────────
    Repeater {
        model: root._folds.length
        delegate: Item {
            id: _sigilItem
            required property int index

            readonly property var   _fd:      root._folds[index]
            readonly property bool  _drawn:   root._drawn.indexOf(_fd.id) >= 0
            readonly property bool  _active:  root._activeMode === _fd.id
            readonly property color _col:     _fd.color

            // Orbital physics
            readonly property real _baseAngle: (index / 7.0) * Math.PI * 2
            readonly property real _drift:     Math.sin(root._time * 0.001 + _baseAngle) * 0.1
            readonly property real _angle:     _baseAngle + (root._time * 0.0005) + _drift
            
            readonly property real _targetR:   _sigilItem._drawn ? root._activeR : root._orbitR
            property real _currentR: _targetR
            Behavior on _currentR { NumberAnimation { duration: 800; easing.type: Easing.OutBack } }

            x: root._cx + _currentR * Math.cos(_angle) - 16
            y: root._cy + _currentR * Math.sin(_angle) - 16
            width:  32
            height: 32
            z: 20

            // Sigil Glyph
            Text {
                anchors.centerIn: parent
                text:  _fd.sigil
                color: _sigilItem._drawn
                    ? Qt.rgba(_col.r, _col.g, _col.b, 1.0)
                    : Qt.rgba(_col.r, _col.g, _col.b, 0.3)
                font.pixelSize: _sigilItem._drawn ? 20 : 16
                Behavior on color { ColorAnimation { duration: 400 } }
                Behavior on font.pixelSize { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }

                layer.enabled: _sigilItem._drawn
                layer.effect: MultiEffect {
                    shadowEnabled: true; blurEnabled: false
                    shadowColor:   Qt.rgba(_col.r, _col.g, _col.b, 0.6)
                    shadowBlur:    0.8
                }
            }

            // Interaction
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler {
                onTapped: {
                    if (_sigilItem._drawn)
                        TW.ArOrchestrator.aseHubRecallFold = _sigilItem._fd.id
                    else
                        TW.ArOrchestrator.aseHubDrawFold   = _sigilItem._fd.id
                }
            }
        }
    }

    // ── Live Hash — cascading below Ase ───────────────────────────────
    InseiLiveHash {
        id: _hash
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: _aseContainer.bottom
        anchors.topMargin: 20
        width:   300
        active:  root._online
        entropy: 0.8 + 0.2 * Math.sin(root._time * 0.002)
        password: "shigurui:zenith" // Synthetic seed
        tappedFolds: root._drawn
        opacity: root._online ? 0.7 : 0.0
        Behavior on opacity { NumberAnimation { duration: 600 } }
    }

}
