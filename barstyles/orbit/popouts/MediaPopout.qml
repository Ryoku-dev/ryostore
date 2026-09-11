import QtQuick
import Quickshell.Widgets

import shell.services
import shell.barkit as Pill

import "../components" as Orbit

Orbit.OrbitPopup {
    id: root

    cardWidth: 390
    cardHeight: 288
    stemStartY: -10

    readonly property var player:
        Media.player

    readonly property bool present:
        Media.present

    readonly property bool playing:
        Media.playing

    readonly property string title:
        root.player
            ? (
                root.player.trackTitle ||
                "Nothing playing"
            )
            : "Nothing playing"

    readonly property string artist:
        root.player
            ? Theme.joinArtists(
                root.player.trackArtists,
                root.player.trackArtist
            )
            : ""

    readonly property bool seekable:
        root.present &&
        !Media.radio &&
        root.player !== null &&
        root.player.canSeek &&
        root.player.length > 0

    readonly property real position:
        root.player
            ? root.player.position
            : 0

    readonly property real length:
        root.seekable
            ? root.player.length
            : 0

    readonly property real fraction:
        root.length > 0
            ? Math.max(
                0,
                Math.min(
                    1,
                    root.position /
                    root.length
                )
            )
            : 0

    function fmtTime(seconds) {
        let sec = Math.max(0, Math.floor(seconds));
        const h = Math.floor(sec / 3600);
        const m = Math.floor((sec % 3600) / 60);
        const r = sec % 60;
        const ss = (r < 10 ? "0" : "") + r;

        if (h > 0)
            return h + ":" + (m < 10 ? "0" : "") + m + ":" + ss;

        return m + ":" + ss;
    }

    function seekFraction(value) {
        if (!root.seekable || root.length <= 0)
            return;

        const fraction = Math.max(0, Math.min(1, value));
        Music.seek(fraction * root.length);
    }

    onTitleChanged: {
        trackIntro.restart();
        artIntro.restart();
    }

    Timer {
        interval: 500
        repeat: true
        running: root.open && root.player !== null && root.player.isPlaying

        onTriggered: {
            if (root.player)
                root.player.positionChanged();
        }
    }

    Column {
        anchors.fill: parent
        spacing: 11

        Orbit.OrbitStage {
            width: parent.width
            open: root.open
            delay: 50

            Row {
                width: parent.width
                height: 22
                spacing: 8

                Pill.MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "music_note"
                    color: Theme.primary
                    font.pixelSize: 16
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "NOW PLAYING"
                    color: Theme.onSurface
                    font.family: Theme.mono
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.40
                }

                Item {
                    width: 178
                    height: 1
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter

                    text:
                        Media.radio
                            ? "LIVE"
                            : root.playing
                                ? "PLAYING"
                                : "PAUSED"

                    color:
                        Media.radio
                            ? Theme.error
                            : root.playing
                                ? Theme.primary
                                : Theme.onSurfaceVariant

                    font.family: Theme.mono
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.7
                }
            }
        }

        Orbit.OrbitStage {
            width: parent.width
            open: root.open
            delay: 95

            Row {
                width: parent.width
                height: 112
                spacing: 15

                Item {
                    id: artBlock

                    width: 112
                    height: 112
                    opacity: 1
                    scale: 1
                    transformOrigin: Item.Center

                    SequentialAnimation {
                        id: artIntro

                        ParallelAnimation {
                            PropertyAction {
                                target: artBlock
                                property: "opacity"
                                value: 0.45
                            }

                            PropertyAction {
                                target: artBlock
                                property: "scale"
                                value: 0.965
                            }
                        }

                        PauseAnimation {
                            duration: 30
                        }

                        ParallelAnimation {
                            NumberAnimation {
                                target: artBlock
                                property: "opacity"
                                from: 0.45
                                to: 1
                                duration: 190
                                easing.type: Easing.OutCubic
                            }

                            NumberAnimation {
                                target: artBlock
                                property: "scale"
                                from: 0.965
                                to: 1
                                duration: 250
                                easing.type: Easing.OutBack
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 15

                        color:
                            Qt.rgba(
                                Theme.primary.r,
                                Theme.primary.g,
                                Theme.primary.b,
                                0.08
                            )

                        border.width: 1

                        border.color:
                            Qt.rgba(
                                Theme.primary.r,
                                Theme.primary.g,
                                Theme.primary.b,
                                0.26
                            )
                    }

                    ClippingRectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: 11
                        color: Theme.surfaceContainer

                        Pill.MaterialIcon {
                            anchors.centerIn: parent
                            visible: art.status !== Image.Ready
                            text: "music_note"
                            color: Theme.onSurfaceVariant
                            font.pixelSize: 34
                        }

                        Image {
                            id: art
                            anchors.fill: parent
                            source: root.player ? (root.player.trackArtUrl || "") : ""
                            asynchronous: true
                            cache: true
                            smooth: true
                            mipmap: true
                            fillMode: Image.PreserveAspectCrop
                        }

                        MouseArea {
                            anchors.fill: parent

                            enabled:
                                root.player !== null &&
                                root.player.canTogglePlaying

                            cursorShape:
                                enabled
                                    ? Qt.PointingHandCursor
                                    : Qt.ArrowCursor

                            onClicked:
                                Media.toggle()
                        }
                    }
                }

                Item {
                    id: trackBlock

                    width:
                        parent.width -
                        127

                    height:
                        parent.height

                    opacity: 1

                    transform:
                        Translate {
                            id: trackShift
                            y: 0
                        }

                    SequentialAnimation {
                        id: trackIntro

                        ParallelAnimation {
                            PropertyAction {
                                target: trackBlock
                                property: "opacity"
                                value: 0
                            }

                            PropertyAction {
                                target: trackShift
                                property: "y"
                                value: 7
                            }
                        }

                        PauseAnimation {
                            duration: 25
                        }

                        ParallelAnimation {
                            NumberAnimation {
                                target: trackBlock
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: 175
                                easing.type: Easing.OutCubic
                            }

                            NumberAnimation {
                                target: trackShift
                                property: "y"
                                from: 7
                                to: 0
                                duration: 225
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    Column {
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }

                        spacing: 6

                        Text {
                            width: parent.width
                            text: root.title
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            color: Theme.onSurface
                            font.family: Theme.display
                            font.pixelSize: 20
                            font.weight: Font.DemiBold
                            lineHeight: 0.98
                        }

                        Text {
                            width: parent.width
                            text: root.artist
                            elide: Text.ElideRight
                            color: Theme.onSurfaceVariant
                            font.family: Theme.fontPrimary
                            font.pixelSize: 11
                        }

                        Row {
                            spacing: 8

                            Orbit.OrbitEqualizer {
                                running: root.playing
                                accentColor: Theme.primary
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter

                                text:
                                    Media.radio
                                        ? "BROADCAST"
                                        : root.seekable
                                            ? "SEEKABLE"
                                            : "MPRIS"

                                color: Theme.onSurfaceVariant
                                font.family: Theme.mono
                                font.pixelSize: 9
                                font.letterSpacing: 0.65
                            }
                        }
                    }
                }
            }
        }

        Orbit.OrbitStage {
            visible: !Media.radio
            width: parent.width
            open: root.open
            delay: 160
            spacing: 5

            Item {
                width: parent.width
                height: 26

                opacity:
                    root.seekable
                        ? 1
                        : 0.38

                Rectangle {
                    id: seekTrack

                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }

                    height:
                        seekMouse.pressed
                            ? 6
                            : seekHover.hovered
                                ? 5
                                : 4

                    radius: 2
                    color: Theme.outlineVariant

                    Behavior on height {
                        NumberAnimation {
                            duration: 110
                            easing.type: Easing.OutCubic
                        }
                    }

                    Rectangle {
                        width: seekTrack.width * root.fraction
                        height: parent.height
                        radius: parent.radius
                        color: Theme.primary

                        Behavior on width {
                            NumberAnimation {
                                duration: seekMouse.pressed ? 0 : 90
                                easing.type: Easing.Linear
                            }
                        }
                    }

                    Rectangle {
                        x: Math.max(
                            0,
                            Math.min(
                                seekTrack.width - width,
                                seekTrack.width * root.fraction - width / 2
                            )
                        )

                        anchors.verticalCenter: parent.verticalCenter

                        width:
                            seekMouse.pressed
                                ? 14
                                : seekHover.hovered
                                    ? 11
                                    : 9

                        height: width
                        radius: 3
                        color: Theme.primary
                        border.width: 1
                        border.color: Theme.surface

                        Behavior on x {
                            NumberAnimation {
                                duration: seekMouse.pressed ? 0 : 90
                                easing.type: Easing.Linear
                            }
                        }

                        Behavior on width {
                            NumberAnimation {
                                duration: 100
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    HoverHandler {
                        id: seekHover

                        cursorShape:
                            root.seekable
                                ? Qt.PointingHandCursor
                                : Qt.ArrowCursor
                    }

                    MouseArea {
                        id: seekMouse

                        anchors {
                            left: parent.left
                            right: parent.right
                        }

                        y: -10
                        height: 26
                        enabled: root.seekable

                        cursorShape:
                            enabled
                                ? Qt.PointingHandCursor
                                : Qt.ArrowCursor

                        onPressed: mouse =>
                            root.seekFraction(
                                mouse.x / width
                            )

                        onPositionChanged: mouse => {
                            if (seekMouse.pressed) {
                                root.seekFraction(
                                    mouse.x / width
                                );
                            }
                        }
                    }
                }
            }

            Row {
                width: parent.width

                Text {
                    width: parent.width / 2
                    text: root.fmtTime(root.position)
                    color: Theme.onSurfaceVariant
                    font.family: Theme.mono
                    font.pixelSize: 9
                }

                Text {
                    width: parent.width / 2
                    horizontalAlignment: Text.AlignRight

                    text:
                        "-" +
                        root.fmtTime(
                            Math.max(
                                0,
                                root.length -
                                root.position
                            )
                        )

                    color: Theme.onSurfaceVariant
                    font.family: Theme.mono
                    font.pixelSize: 9
                }
            }
        }

        Orbit.OrbitStage {
            width: parent.width
            open: root.open
            delay: 215
            y: -5

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 9

                Orbit.OrbitIconButton {
                    icon: "skip_previous"

                    enabled:
                        root.player !== null &&
                        root.player.canGoPrevious

                    onClicked: {
                        if (root.player)
                            root.player.previous();
                    }
                }

                Orbit.OrbitIconButton {
                    width: 48
                    height: 38

                    icon:
                        root.playing
                            ? "pause"
                            : "play_arrow"

                    accent: true

                    enabled:
                        root.player !== null &&
                        root.player.canTogglePlaying

                    onClicked:
                        Media.toggle()
                }

                Orbit.OrbitIconButton {
                    icon: "skip_next"

                    enabled:
                        root.player !== null &&
                        root.player.canGoNext

                    onClicked: {
                        if (root.player)
                            root.player.next();
                    }
                }
            }
        }
    }
}
