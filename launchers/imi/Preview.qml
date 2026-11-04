import QtQuick
import Ryoku.Ui.Singletons

// What Ryoku Settings shows for this launcher: a still of the imi overview search surface, 720 x 250, drawn with Ryoku's tokens.
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
        id: sheet

        width: 520
        height: 210
        anchors.centerIn: parent
        radius: Tokens.radius
        color: Tokens.paperLift
        border.width: Tokens.border
        border.color: Tokens.lineStrong

        Column {
            anchors { fill: parent; margins: Tokens.s3 }
            spacing: Tokens.s2

            Rectangle {
                width: parent.width
                height: Tokens.px(40)
                radius: height / 2
                color: Tokens.tint10

                Row {
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: Tokens.s3; rightMargin: Tokens.s3 }
                    spacing: Tokens.s2

                    Rectangle {
                        width: Tokens.px(16)
                        height: width
                        radius: width / 2
                        color: Tokens.ink
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "fire"
                        color: Tokens.ink
                        font.family: Tokens.ui
                        font.pixelSize: Tokens.fRow
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Ctrl+Enter opens the web search"
                        color: Tokens.inkFaint
                        font.family: Tokens.ui
                        font.pixelSize: Tokens.fSmall
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Repeater {
                model: ["Applications", "Files & folders", "Continue with"]

                delegate: Column {
                    id: group
                    required property string modelData
                    required property int index
                    width: parent.width
                    spacing: Tokens.s1

                    Text {
                        text: group.modelData
                        color: Tokens.inkFaint
                        font.family: Tokens.ui
                        font.pixelSize: Tokens.fSmall
                    }

                    Row {
                        spacing: Tokens.s2
                        Rectangle {
                            width: Tokens.px(20)
                            height: width
                            radius: width / 2
                            color: group.index === 0 ? Tokens.ink : Tokens.lineStrong
                        }
                        Text {
                            text: group.index === 0 ? "Firefox" : group.index === 1 ? "fire-launcher-notes.md" : "Search the web for “fire”"
                            color: Tokens.ink
                            font.family: Tokens.ui
                            font.pixelSize: Tokens.fRow
                        }
                    }
                }
            }
        }
    }
}
