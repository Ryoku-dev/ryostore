import QtQuick
import QtQuick.Effects
import "../../common"
import "../../common/widgets"
import "../phone"

// The phone's now-playing card. Pure UI — QuickPanelFace.qml feeds it and turns
// its signals into player calls.
Item {
    id: root

    property string title: ""
    property string artist: ""
    property url art: ""
    property bool playing: false
    property real renderScale: 1

    signal toggleRequested()
    signal previousRequested()
    signal nextRequested()
    // The card is also the door to the lyrics tab (QuickPanel.qml).
    signal lyricsRequested()

    implicitWidth: 575
    implicitHeight: 130

    // Hovering lifts it a touch, so it reads as something you can open.
    scale: openArea.containsMouse ? 1.03 : 1
    Behavior on scale {
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        x: Theme.quickFlat ? 0 : 5
        y: 4
        width: parent.width
        height: root.implicitHeight
        radius: 41
        color: Theme.pLineShadow
        antialiasing: true
    }

    Rectangle {
        id: card

        width: parent.width
        height: root.implicitHeight
        radius: 41
        color: Theme.pSurface
        border.width: 3
        border.color: Theme.pLine
        antialiasing: true

        Item {
            id: artBox

            x: 18
            y: 18
            width: 94
            height: 94

            Rectangle {
                anchors.fill: parent
                radius: 24
                color: Theme.pSurfaceHover
                antialiasing: true
            }

            MaterialIcon {
                anchors.centerIn: parent
                visible: cover.status !== Image.Ready
                name: "music_note"
                size: 34
                color: Theme.pInkSub
            }

            Image {
                id: cover

                anchors.fill: parent
                source: root.art
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                // The same file is rewritten for the next track.
                cache: false
                sourceSize: Qt.size(188, 188)
                visible: false
            }

            Item {
                id: artMask

                anchors.fill: parent
                visible: false
                layer.enabled: true
                layer.smooth: true
                layer.textureSize: Qt.size(Math.ceil(width * root.renderScale * 2),
                                           Math.ceil(height * root.renderScale * 2))

                Rectangle {
                    anchors.fill: parent
                    radius: 24
                    color: "black"
                    antialiasing: true
                }
            }

            MultiEffect {
                anchors.fill: parent
                source: cover
                maskEnabled: true
                maskSource: artMask
                visible: cover.status === Image.Ready
            }
        }

        Column {
            x: 130
            width: 260
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: root.title
                color: Theme.pInk
                font.family: Theme.fontFamily
                font.pixelSize: 20
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: root.artist
                color: Theme.pInkSub
                font.family: Theme.fontFamily
                font.pixelSize: 15
            }
        }

        // The whole card opens the lyrics; the transport keys sit above this
        // and keep their own clicks.
        MouseArea {
            id: openArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.lyricsRequested()
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 22
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            TansuKey {
                capW: 40
                capH: 40
                radius: 20
                flatShadow: Theme.quickFlat
                hovered: prevArea.containsMouse
                pressed: prevArea.pressed

                MaterialIcon {
                    anchors.centerIn: parent
                    name: "skip_previous"
                    size: 22
                    fill: 1
                    color: Theme.pInk
                }

                MouseArea {
                    id: prevArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.previousRequested()
                }
            }

            TansuKey {
                capW: 46
                capH: 46
                radius: 23
                flatShadow: Theme.quickFlat
                lit: true
                hovered: playArea.containsMouse
                pressed: playArea.pressed

                MaterialIcon {
                    anchors.centerIn: parent
                    name: root.playing ? "pause" : "play_arrow"
                    size: 26
                    fill: 1
                    color: Theme.inkOnAccent
                }

                MouseArea {
                    id: playArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleRequested()
                }
            }

            TansuKey {
                capW: 40
                capH: 40
                radius: 20
                flatShadow: Theme.quickFlat
                hovered: nextArea.containsMouse
                pressed: nextArea.pressed

                MaterialIcon {
                    anchors.centerIn: parent
                    name: "skip_next"
                    size: 22
                    fill: 1
                    color: Theme.pInk
                }

                MouseArea {
                    id: nextArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.nextRequested()
                }
            }
        }
    }
}
