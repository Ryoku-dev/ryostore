pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import shell.services as RyokuServices
import shell.barkit as Pill
import "../../.."
import "../../common"
import "../../common/widgets"
import "../../../shared" as Shared
import "../../../popouts" as Popouts

Item {
    id: root

    property bool vertical: false
    property bool borderless: Config.options.bar.borderless
    property bool isMaterial: Config.options.bar.cornerStyle === 3

    implicitWidth: rowr.implicitWidth + (isMaterial ? 16 : 10)
    implicitHeight: vertical ? (rowr.implicitHeight + 8) : Appearance.sizes.baseBarHeight
    width: implicitWidth
    height: implicitHeight
    visible: true

    onVisibleChanged: RyokuServices.AudioBars.setActive(root, visible)
    Component.onCompleted: RyokuServices.AudioBars.setActive(root, visible)
    Component.onDestruction: RyokuServices.AudioBars.setActive(root, false)

    HoverHandler { id: hh }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: 11
        color: hh.hovered ? Qt.rgba(0, 0, 0, 0.18) : "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    Shared.Popout {
        target: root
        targetHovered: hh.hovered
        preferredWidth: 300
        preferredHeight: 180
        namespace: "ryoku-bar-popout"
        content: Component {
            Popouts.MediaPopout {}
        }
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onTapped: (eventPoint, button) => {
            if (button === Qt.LeftButton) {
                RyokuServices.Media.player?.togglePlaying();
            } else if (button === Qt.RightButton) {
                RyokuServices.Media.player?.next();
            } else if (button === Qt.MiddleButton) {
                RyokuServices.Media.player?.previous();
            }
        }
    }

    Row {
        id: rowr
        anchors.centerIn: parent
        spacing: 8

        // Rounded Album Art
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 22
            radius: Appearance.rounding.small
            clip: true
            color: Appearance.colors.colLayer1Hover

            Image {
                id: art
                anchors.fill: parent
                source: RyokuServices.Media.player ? (RyokuServices.Media.player.trackArtUrl || "") : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: art.status === Image.Ready && art.source !== ""
            }

            Pill.MaterialIcon {
                anchors.centerIn: parent
                text: "music_note"
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnSecondaryContainer
                visible: !art.visible
            }
        }

        // Title · Artist (Single line, elided, dynamic font)
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            width: (RyokuServices.Media.line) ? Math.min(160, implicitWidth) : 0
            visible: RyokuServices.Media.line !== ""
            text: RyokuServices.Media.line || ""
            elide: Text.ElideRight
            color: Appearance.colors.colOnSecondaryContainer
            font.pixelSize: Appearance.font.pixelSize.small
        }

        // Live Audio Visualizer Bars
        Pill.MusicBars {
            anchors.verticalCenter: parent.verticalCenter
            orient: "vertical"
            bands: 7
            s: 1.0
            width: 24
            height: 14
            running: RyokuServices.Media.playing
            opacity: RyokuServices.Media.playing ? 1 : 0.4
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
    }
}
