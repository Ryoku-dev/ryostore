import QtQuick
import Quickshell
import Quickshell.Io
import "."

Item {
    id: root
    implicitWidth: 340
    implicitHeight: 140

    // Quotes Database
    property var quotesList: [
        { text: "Simplicity is prerequisite for reliability.", author: "Edsger W. Dijkstra", tag: "Design" },
        { text: "Make it work, make it right, make it fast.", author: "Kent Beck", tag: "Craft" },
        { text: "Design is not just what it looks like and feels like. Design is how it works.", author: "Steve Jobs", tag: "Vision" },
        { text: "Programs must be written for people to read, and only incidentally for machines to execute.", author: "Harold Abelson", tag: "Clarity" },
        { text: "The details are not the details. They make the design.", author: "Charles Eames", tag: "Art" },
        { text: "Talk is cheap. Show me the code.", author: "Linus Torvalds", tag: "Linux" }
    ]
    property int currentQuoteIndex: 0

    function nextQuote() {
        root.currentQuoteIndex = (root.currentQuoteIndex + 1) % root.quotesList.length
    }


    // Theme Palette
    readonly property color colBg: Theme.colBg
    readonly property color colBadgeBg: Theme.colPillBg
    readonly property color colAccent: Theme.colAccent
    readonly property color colTextPrimary: Theme.colTextPrimary
    readonly property color colTextSecondary: Theme.colTextSecondary

    property var activeQuote: root.quotesList[root.currentQuoteIndex] || root.quotesList[0]

    // ─── Scaled Visual Content ───
    Item {
        id: scaledContent
        width: 340
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

                // Header Row: INSPIRATION Badge + Tag + Refresh Button
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
                                color: root.colAccent
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "INSPIRATION"
                                color: root.colTextPrimary
                                font.pixelSize: 9
                                font.bold: true
                                font.letterSpacing: 0.6
                                font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                            }
                        }
                    }

                    Item {
                        width: Math.max(0, parent.width - parent.children[0].width - refreshBtn.width)
                        height: 1
                    }

                    // Refresh Button
                    Rectangle {
                        id: refreshBtn
                        width: 24
                        height: 24
                        radius: 12
                        color: refArea.containsMouse ? "#33FFFFFF" : root.colBadgeBg
                        antialiasing: true

                        Text {
                            anchors.centerIn: parent
                            text: "↻"
                            color: "#FFFFFF"
                            font.pixelSize: 14
                            font.bold: true
                        }

                        MouseArea {
                            id: refArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.nextQuote()
                        }
                    }
                }

                // Middle Quote Body Text
                Text {
                    width: parent.width
                    height: 52
                    text: "“" + root.activeQuote.text + "”"
                    color: root.colTextPrimary
                    font.pixelSize: 12
                    font.italic: true
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    maximumLineCount: 3
                    lineHeight: 1.15
                    font.family: "Google Sans Flex, Google Sans, Inter, Georgia, serif"
                }

                // Bottom Author Tag Row
                Row {
                    width: parent.width
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "— " + root.activeQuote.author
                        color: root.colAccent
                        font.pixelSize: 11
                        font.bold: true
                        font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                    }

                    Item {
                        width: Math.max(0, parent.width - parent.children[0].width - tagBadge.width)
                        height: 1
                    }

                    Rectangle {
                        id: tagBadge
                        height: 18
                        width: tagText.implicitWidth + 12
                        radius: 9
                        color: root.colBadgeBg
                        antialiasing: true

                        Text {
                            id: tagText
                            anchors.centerIn: parent
                            text: root.activeQuote.tag
                            color: root.colTextSecondary
                            font.pixelSize: 9
                            font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                        }
                    }
                }
            }
        }
    }
}
