import QtQuick
import Ryoku.Ui.Singletons

// What Ryoku Settings shows for Mandara: a still of her plate —
// centred, the beam lit, one lane locked as a rune chip.
Item {
    id: root

    property var settings: ({})
    signal editRequested(string key, var value)

    implicitWidth: 720
    implicitHeight: 250

    Rectangle {
        anchors.fill: parent
        color: Tokens.paper
    }

    Rectangle {
        width: 460
        height: col.implicitHeight + Tokens.s4 * 2
        anchors.centerIn: parent
        radius: Tokens.radius
        color: Tokens.paperLift
        border.width: Tokens.border
        border.color: Tokens.lineStrong

        Text {
            anchors { right: parent.right; rightMargin: Tokens.s3
                      bottom: parent.bottom; bottomMargin: -Tokens.s4 }
            text: "曼"
            font.pixelSize: Tokens.px(96)
            color: Tokens.ink
            opacity: 0.05
        }

        Column {
            id: col
            anchors { left: parent.left; right: parent.right
                      top: parent.top; margins: Tokens.s4 }
            spacing: Tokens.s2

            Row {
                spacing: Tokens.s2
                Rectangle {
                    width: chipRow.implicitWidth + 18
                    height: 24
                    radius: 6
                    color: Qt.rgba(0.13, 0.83, 0.93, 0.13)
                    border.width: 1
                    border.color: Qt.rgba(0.13, 0.83, 0.93, 0.8)
                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 5
                        Text { text: "◈"; color: "#22D3EE"; font.pixelSize: 12
                               anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "APPS"; color: Qt.rgba(1, 1, 1, 0.9)
                               font.family: "monospace"; font.pixelSize: 11
                               font.bold: true; font.letterSpacing: 1
                               anchors.verticalCenter: parent.verticalCenter }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "TAB cycles · ⌫ releases"
                    color: Tokens.inkFaint
                    font.family: Tokens.ui
                    font.pixelSize: Tokens.fSmall
                }
            }

            Text {
                text: "speak or command"
                color: Tokens.inkFaint
                font.family: Tokens.ui
                font.pixelSize: Tokens.fValue
            }

            Rectangle {
                width: parent.width
                height: 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#22D3EE" }
                    GradientStop { position: 1.0; color: "#A78BFA" }
                }
                opacity: 0.85
            }

            Repeater {
                model: [
                    { glyph: "", name: "Ghostty", hint: "APP", sel: true },
                    { glyph: "›", name: "Run  systemctl status", hint: "COMMAND", sel: false },
                    { glyph: "✦", name: "Lock screen", hint: "ACTION", sel: false }
                ]
                delegate: Rectangle {
                    required property var modelData
                    width: col.width
                    height: Tokens.rowH
                    radius: Tokens.radius
                    color: modelData.sel ? Tokens.tint10 : "transparent"

                    Rectangle {
                        visible: modelData.sel
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: 2
                        color: "#22D3EE"
                    }
                    Text {
                        anchors { left: parent.left; leftMargin: Tokens.s3 + Tokens.px(24)
                                  verticalCenter: parent.verticalCenter }
                        text: modelData.name
                        color: Tokens.ink
                        font.family: Tokens.ui
                        font.pixelSize: Tokens.fRow
                    }
                    Text {
                        anchors { right: parent.right; rightMargin: Tokens.s3
                                  verticalCenter: parent.verticalCenter }
                        text: modelData.hint
                        color: Tokens.inkFaint
                        font.family: "monospace"
                        font.pixelSize: Tokens.fSmall
                        font.letterSpacing: 1
                    }
                }
            }

            Item {
                width: parent.width
                height: Tokens.fSmall + 4
                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: "M A N D A R A"
                    color: Tokens.inkFaint
                    font.family: "monospace"
                    font.pixelSize: Tokens.fSmall
                    opacity: 0.8
                }
                Text {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: "APPS locked"
                    color: Tokens.inkFaint
                    font.family: Tokens.ui
                    font.pixelSize: Tokens.fSmall
                }
            }
        }
    }
}
