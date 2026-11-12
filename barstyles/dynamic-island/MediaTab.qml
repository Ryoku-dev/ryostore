pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris

// Now Playing (Lock Screen style): big art with glow, scrubber, transport, volume, sources.
Item {
    id: root
    readonly property MprisPlayer p: Hub.player

    Column {
        anchors.centerIn: parent
        spacing: 8
        visible: !root.p
        Icon { anchors.horizontalCenter: parent.horizontalCenter; text: "music_off"; size: 44; color: Theme.fg3 }
        Txt { anchors.horizontalCenter: parent.horizontalCenter; text: "Not Playing"; size: 15; weight: Font.DemiBold; color: Theme.fg2 }
        Txt { anchors.horizontalCenter: parent.horizontalCenter; text: "Start music in any MPRIS player"; size: 12; color: Theme.fg3 }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 24
        visible: root.p !== null

        Item {
            Layout.preferredWidth: 200
            Layout.preferredHeight: 200
            Layout.alignment: Qt.AlignVCenter

            RectangularShadow {
                anchors.fill: art
                radius: art.radius
                blur: 40
                spread: 4
                offset.y: 10
                color: Theme.live
                opacity: Hub.playing ? 0.55 : 0.12
                scale: art.scale
                Behavior on opacity { NumberAnimation { duration: 500 } }
            }
            ArtImage {
                id: art
                anchors.fill: parent
                radius: 22
                source: Hub.artUrl
                scale: Hub.playing ? 1 : 0.86
                Behavior on scale { NumberAnimation { duration: 550; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Marquee {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        text: root.p ? (root.p.trackTitle || "Unknown Title") : ""
                        size: 21
                        weight: Font.Bold
                    }
                    Txt {
                        Layout.fillWidth: true
                        text: root.p ? (root.p.trackArtist || root.p.identity) : ""
                        size: 15
                        color: Theme.fg2
                    }
                }
                Visualizer { count: 6; maxHeight: 22; barWidth: 3.5; visible: Hub.playing }
            }

            // player sources
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 6
                visible: Hub.players.length > 1
                Repeater {
                    model: Hub.players
                    Rectangle {
                        id: chip
                        required property var modelData
                        readonly property bool sel: modelData === Hub.player
                        height: 22
                        width: chipRow.implicitWidth + 16
                        radius: 11
                        color: sel ? Theme.fill3 : Theme.fill
                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 4
                            Rectangle { visible: chip.modelData.isPlaying; width: 6; height: 6; radius: 3; color: Theme.green; anchors.verticalCenter: parent.verticalCenter }
                            Txt { text: chip.modelData.identity; size: 11; color: chip.sel ? Theme.fg : Theme.fg2 }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Hub.pinnedPlayer = chip.modelData }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            SliderBar {
                Layout.fillWidth: true
                value: Hub.progress
                color: Theme.fg
                barHeight: 6
                interactive: root.p !== null && root.p.canSeek
                onCommitted: v => { if (root.p && root.p.canSeek) root.p.position = v * root.p.length; }
            }
            RowLayout {
                Layout.fillWidth: true
                Txt { text: root.p ? Hub.fmtTime(root.p.position) : "0:00"; size: 11; color: Theme.fg2 }
                Item { Layout.fillWidth: true }
                Txt {
                    text: root.p && root.p.length > 0 ? "-" + Hub.fmtTime(root.p.length - root.p.position) : ""
                    size: 11
                    color: Theme.fg2
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 4
                IconButton {
                    icon: "shuffle"; size: 18
                    visible: root.p !== null && root.p.shuffleSupported
                    color: root.p && root.p.shuffle ? Theme.accent : Theme.fg2
                    onClicked: root.p.shuffle = !root.p.shuffle
                }
                Item { Layout.fillWidth: true }
                IconButton {
                    icon: "fast_rewind"; size: 32; fill: 1; pad: 6
                    enabled: !!(root.p && root.p.canGoPrevious)
                    onClicked: root.p.previous()
                }
                IconButton {
                    icon: Hub.playing ? "pause" : "play_arrow"; size: 42; fill: 1; pad: 4
                    onClicked: if (root.p) root.p.togglePlaying()
                }
                IconButton {
                    icon: "fast_forward"; size: 32; fill: 1; pad: 6
                    enabled: !!(root.p && root.p.canGoNext)
                    onClicked: root.p.next()
                }
                Item { Layout.fillWidth: true }
                IconButton {
                    visible: root.p !== null && root.p.loopSupported
                    icon: root.p && root.p.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                    size: 18
                    color: root.p && root.p.loopState !== MprisLoopState.None ? Theme.accent : Theme.fg2
                    onClicked: Hub.cycleLoop(root.p)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Icon { text: "volume_mute"; size: 15; fill: 1; color: Theme.fg2 }
                SliderBar {
                    Layout.fillWidth: true
                    barHeight: 5
                    value: Hub.muted ? 0 : Hub.volume
                    color: Theme.fg2
                    onMoved: v => Hub.setVolume(v)
                }
                Icon { text: "volume_up"; size: 15; fill: 1; color: Theme.fg2 }
                Icon { text: Hub.sinkIcon(); size: 16; fill: 1; color: Theme.accent }
            }
        }
    }
}
