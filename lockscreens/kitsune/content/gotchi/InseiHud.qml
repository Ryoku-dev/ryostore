/* InseiHud.qml — Gate Telemetry Strip
 * =====================================
 * 7 fold sigil dots + entropy bar + live hash.
 * Dots fill with fold color as each card is tapped.
 * Centered under InseiCompanion.
 */
import QtQuick
import QtQuick.Effects
import "../tw" as TW

Item {
    id: root

    property real   entropy:    0.0
    property int    locked:     0
    property string password:   ""
    property bool   isLoading:  false
    property real   time:       0.0
    property var    tappedFolds: []   // fold IDs in tap order

    implicitHeight: 52
    implicitWidth:  320
    opacity: entropy > 0 || isLoading ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 400 } }

    // Canonical fold order + sigils + colors — matches backend
    readonly property var _folds: [
        { id: "truth",      sigil: "◉", color: "#4ade80" },
        { id: "power",      sigil: "⊗", color: "#f43f5e" },
        { id: "wisdom",     sigil: "⚔", color: "#00B4D8" },
        { id: "judgment",   sigil: "◈", color: "#9B1FA0" },
        { id: "life",       sigil: "☁", color: "#818cf8" },
        { id: "love",       sigil: "⬡", color: "#f59e0b" },
        { id: "discipline", sigil: "◌", color: "#6366f1" }
    ]

    Column {
        anchors.centerIn: parent
        spacing: 6

        // ── 7 fold sigil dots ─────────────────────────────────────────
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14

            Repeater {
                model: root._folds.length
                delegate: Item {
                    required property int index
                    width: 22; height: 22

                    readonly property var   _fd:     root._folds[index]
                    readonly property bool  _tapped: root.tappedFolds.indexOf(_fd.id) >= 0
                    readonly property int   _order:  root.tappedFolds.indexOf(_fd.id)
                    readonly property color _col:    Qt.color(_fd.color)

                    // Outer glow ring — visible when tapped
                    Rectangle {
                        anchors.centerIn: parent
                        width: 20; height: 20; radius: 10
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.rgba(_col.r, _col.g, _col.b, _tapped ? 0.45 : 0.0)
                        Behavior on border.color { ColorAnimation { duration: 300 } }
                    }

                    // Sigil text
                    Text {
                        anchors.centerIn: parent
                        text:  _fd.sigil
                        color: _tapped
                            ? Qt.rgba(_col.r, _col.g, _col.b, 1.0)
                            : Qt.rgba(1, 1, 1, 0.18)
                        font.pixelSize: 13
                        Behavior on color { ColorAnimation { duration: 250 } }

                        // Pop-in scale when tapped
                        scale: _tapped ? 1.0 : 0.85
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

                        layer.enabled: _tapped
                        layer.effect: MultiEffect {
                            shadowEnabled: true; blurEnabled: false
                            shadowColor:   Qt.rgba(_col.r, _col.g, _col.b, 0.75)
                            shadowBlur:    0.90
                            shadowVerticalOffset: 0; shadowHorizontalOffset: 0
                        }
                    }

                    // Tap order number — tiny, below sigil, fades in when tapped
                    Text {
                        anchors { top: parent.bottom; horizontalCenter: parent.horizontalCenter; topMargin: 1 }
                        text:    _order >= 0 ? (_order + 1).toString() : ""
                        color:   Qt.rgba(_col.r, _col.g, _col.b, 0.55)
                        font.family:    TW.TransparentWorld.fontFamilyMono
                        font.pixelSize: 7
                        font.bold:      true
                        opacity: _tapped ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }
                }
            }
        }

        // ── Entropy bar ───────────────────────────────────────────────
        Item {
            width:  320
            height: 2
            anchors.horizontalCenter: parent.horizontalCenter

            Rectangle {
                anchors.fill: parent; radius: 1
                color: Qt.rgba(TW.TransparentWorld.accentWater.r, TW.TransparentWorld.accentWater.g, TW.TransparentWorld.accentWater.b, 0.10)
                Rectangle {
                    height: parent.height; radius: 1
                    width:  parent.width * root.entropy
                    color:  TW.TransparentWorld.accentWater
                    opacity: 0.6 + 0.4 * Math.sin(root.time * 1.8)
                    Behavior on width { NumberAnimation { duration: 80 } }
                }
            }
        }

        // ── Live hash ─────────────────────────────────────────────────
        InseiLiveHash {
            anchors.horizontalCenter: parent.horizontalCenter
            width:    320
            active:   root.entropy > 0 && !root.isLoading
            password: root.password
            entropy:  root.entropy
            tappedFolds: root.tappedFolds
        }
    }
}
