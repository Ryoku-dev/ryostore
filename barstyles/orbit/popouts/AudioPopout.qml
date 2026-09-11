import QtQuick

import shell.services
import shell.barkit as Pill

import "../components" as Orbit

Orbit.OrbitPopup {
    id: root

    cardWidth: 306
    cardHeight: 194

    readonly property var sink:
        Audio.sink

    readonly property bool ready:
        !!(sink && sink.audio)

    readonly property bool muted:
        ready &&
        sink.audio.muted

    readonly property int volume:
        ready
            ? Math.round(
                sink.audio.volume * 100
            )
            : 0

    function setVolume(value) {
        if (!root.ready)
            return;

        root.sink.audio.volume =
            Math.max(
                0,
                Math.min(
                    1,
                    value
                )
            );

        if (
            root.sink.audio.muted &&
            value > 0
        ) {
            root.sink.audio.muted = false;
        }
    }

    function stepVolume(value) {
        if (!root.ready)
            return;

        root.setVolume(
            root.sink.audio.volume +
            value
        );
    }

    Column {
        anchors.fill: parent
        spacing: 11

        Orbit.OrbitStage {
            width: parent.width
            open: root.open
            delay: 55

            Row {
                width: parent.width
                height: 21
                spacing: 8

                Pill.MaterialIcon {
                    anchors.verticalCenter:
                        parent.verticalCenter

                    text:
                        root.muted
                            ? "volume_off"
                            : "volume_up"

                    color:
                        root.muted
                            ? Theme.error
                            : Theme.primary

                    font.pixelSize: 16
                }

                Text {
                    anchors.verticalCenter:
                        parent.verticalCenter

                    text: "AUDIO"

                    color: Theme.onSurface

                    font.family: Theme.mono
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.55
                }

                Item {
                    width: 141
                    height: 1
                }

                Text {
                    anchors.verticalCenter:
                        parent.verticalCenter

                    text:
                        root.ready
                            ? root.muted
                                ? "MUTED"
                                : "ACTIVE"
                            : "OFFLINE"

                    color:
                        root.muted
                            ? Theme.error
                            : root.ready
                                ? Theme.primary
                                : Theme.onSurfaceVariant

                    font.family: Theme.mono
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                }
            }
        }

        Orbit.OrbitStage {
            width: parent.width
            open: root.open
            delay: 105

            Row {
                width: parent.width

                Text {
                    text:
                        root.ready
                            ? root.volume + "%"
                            : "--"

                    color:
                        root.muted
                            ? Theme.error
                            : Theme.onSurface

                    font.family: Theme.mono
                    font.pixelSize: 30
                    font.weight: Font.DemiBold
                }

                Item {
                    width: 14
                    height: 1
                }

                Column {
                    anchors.verticalCenter:
                        parent.verticalCenter

                    spacing: 2

                    Text {
                        text: "OUTPUT LEVEL"

                        color:
                            Theme.onSurfaceVariant

                        font.family: Theme.mono
                        font.pixelSize: 9
                        font.letterSpacing: 0.85
                    }

                    Text {
                        text:
                            root.muted
                                ? "Signal muted"
                                : root.ready
                                    ? "Drag or scroll to adjust"
                                    : "No active output"

                        color:
                            Theme.onSurfaceVariant

                        font.family:
                            Theme.fontPrimary

                        font.pixelSize: 10
                    }
                }
            }
        }

        Orbit.OrbitStage {
            width: parent.width
            open: root.open
            delay: 150

            Item {
                width: parent.width
                height: 34

                Rectangle {
                    id: track

                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter:
                            parent.verticalCenter
                    }

                    height: 5
                    radius: 2

                    color:
                        Theme.outlineVariant

                    Rectangle {
                        width:
                            track.width *
                            Math.max(
                                0,
                                Math.min(
                                    1,
                                    root.volume / 100
                                )
                            )

                        height: parent.height
                        radius: parent.radius

                        color:
                            root.muted
                                ? Theme.onSurfaceVariant
                                : Theme.primary

                        Behavior on width {
                            NumberAnimation {
                                duration:
                                    sliderMouse.pressed
                                        ? 0
                                        : 95

                                easing.type:
                                    Easing.OutCubic
                            }
                        }
                    }

                    Repeater {
                        model: 3

                        delegate: Rectangle {
                            required property int index

                            x:
                                track.width *
                                (
                                    (index + 1) /
                                    4
                                ) -
                                width / 2

                            anchors.verticalCenter:
                                parent.verticalCenter

                            width: 2
                            height: 2
                            radius: 1

                            color:
                                Theme.surface

                            opacity: 0.70
                        }
                    }

                    Rectangle {
                        x: Math.max(
                            0,
                            Math.min(
                                track.width - width,

                                track.width *
                                root.volume / 100 -
                                width / 2
                            )
                        )

                        anchors.verticalCenter:
                            parent.verticalCenter

                        width:
                            sliderMouse.pressed
                                ? 15
                                : 11

                        height: width
                        radius: 3

                        color:
                            Theme.primary

                        border.width: 1

                        border.color:
                            Theme.surface

                        Behavior on x {
                            NumberAnimation {
                                duration:
                                    sliderMouse.pressed
                                        ? 0
                                        : 95

                                easing.type:
                                    Easing.OutCubic
                            }
                        }
                    }

                    MouseArea {
                        id: sliderMouse

                        anchors {
                            left: parent.left
                            right: parent.right
                        }

                        y: -15
                        height: 35

                        cursorShape:
                            Qt.PointingHandCursor

                        onPressed: mouse =>
                            root.setVolume(
                                mouse.x / width
                            )

                        onPositionChanged: mouse => {
                            if (
                                sliderMouse.pressed
                            ) {
                                root.setVolume(
                                    mouse.x / width
                                );
                            }
                        }
                    }

                    WheelHandler {
                        onWheel: event =>
                            root.stepVolume(
                                event.angleDelta.y > 0
                                    ? 0.02
                                    : -0.02
                            )
                    }
                }
            }
        }

        Orbit.OrbitStage {
            width: parent.width
            open: root.open
            delay: 200

            Row {
                anchors.horizontalCenter:
                    parent.horizontalCenter

                spacing: 8

                Orbit.OrbitIconButton {
                    icon: "remove"

                    enabled:
                        root.ready

                    onClicked:
                        root.stepVolume(-0.05)
                }

                Orbit.OrbitIconButton {
                    icon:
                        root.muted
                            ? "volume_up"
                            : "volume_off"

                    danger:
                        root.muted

                    accent:
                        !root.muted

                    enabled:
                        root.ready

                    onClicked: {
                        if (root.ready) {
                            root.sink.audio.muted =
                                !root.sink.audio.muted;
                        }
                    }
                }

                Orbit.OrbitIconButton {
                    icon: "add"

                    enabled:
                        root.ready

                    onClicked:
                        root.stepVolume(0.05)
                }
            }
        }
    }
}
