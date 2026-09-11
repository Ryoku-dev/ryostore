import QtQuick
import shell.services

Item {
    id: root

    property real mediaCenter: width * 0.5
    property real workspaceCenter: 56
    property real targetCenter: width - 96
    property real mediaProgress: 0
    property bool mediaPlaying: false
    property bool engaged: false

    Rectangle {
        anchors.fill: parent
        height: 1
        color: Theme.outlineVariant
        opacity: 0.18
    }

    Rectangle {
        x: 0
        y: 0
        width: Math.max(28, root.workspaceCenter - 22)
        height: 1
        color: Theme.outlineVariant
        opacity: 0.62
    }

    Rectangle {
        x: Math.max(0, root.workspaceCenter + 18)
        y: 0
        width: Math.max(18, root.mediaCenter - x - 44)
        height: 1
        color: Theme.outlineVariant
        opacity: 0.28
    }

    Rectangle {
        id: mediaBed
        x: Math.max(0, root.mediaCenter - 78)
        y: -1
        width: 156
        height: 3
        radius: 2
        color: Theme.primary
        opacity: root.mediaPlaying ? 0.11 : 0.06
    }

    Rectangle {
        id: mediaProgressFill
        x: mediaBed.x
        y: 0
        width: mediaBed.width * Math.max(0, Math.min(1, root.mediaProgress))
        height: 1
        radius: 1
        color: Theme.primary
        opacity: root.mediaPlaying ? 0.88 : 0.38

        Behavior on width {
            NumberAnimation {
                duration: 100
                easing.type: Easing.Linear
            }
        }
    }

    Rectangle {
        visible: root.mediaPlaying

        x: mediaBed.x + Math.max(
            0,
            Math.min(
                mediaBed.width - width,
                mediaBed.width * root.mediaProgress - width / 2
            )
        )

        y: -2
        width: 5
        height: 5
        radius: width / 2
        color: Theme.primary
        opacity: 0.82

        Behavior on x {
            NumberAnimation {
                duration: 100
                easing.type: Easing.Linear
            }
        }
    }

    Rectangle {
        x: Math.min(root.width - 10, root.mediaCenter + 44)
        y: 0
        width: Math.max(18, root.targetCenter - x - 20)
        height: 1
        color: Theme.outlineVariant
        opacity: 0.28
    }

    Rectangle {
        x: Math.max(0, root.targetCenter + 20)
        y: 0
        width: Math.max(18, root.width - x)
        height: 1
        color: Theme.outlineVariant
        opacity: 0.62
    }

    Rectangle {
        x: Math.max(0, root.workspaceCenter - 18)
        y: -2
        width: 36
        height: 5
        radius: 3
        color: Theme.primary
        opacity: 0.10
    }

    Rectangle {
        x: Math.max(0, root.targetCenter - 18)
        y: -2
        width: 36
        height: 5
        radius: 3
        color: Theme.primary
        opacity: root.engaged ? 0.22 : 0.10

        Behavior on opacity {
            NumberAnimation { duration: 160 }
        }
    }

    Rectangle {
        id: scanA
        y: 0
        width: 120
        height: 1
        radius: 1
        color: Theme.primary
        opacity: 0.10
        x: -width

        SequentialAnimation on x {
            loops: Animation.Infinite
            running: true

            NumberAnimation {
                from: -scanA.width
                to: root.width
                duration: 5200
                easing.type: Easing.Linear
            }

            PauseAnimation { duration: 350 }
        }
    }

    Rectangle {
        id: scanB
        y: 0
        width: 54
        height: 1
        radius: 1
        color: Theme.primary
        opacity: 0.07
        x: -width

        SequentialAnimation on x {
            loops: Animation.Infinite
            running: true

            PauseAnimation { duration: 1450 }

            NumberAnimation {
                from: -scanB.width
                to: root.width
                duration: 3450
                easing.type: Easing.Linear
            }

            PauseAnimation { duration: 900 }
        }
    }

    Rectangle {
        id: engageSignal
        y: -1
        width: 18
        height: 3
        radius: 2
        color: Theme.primary
        opacity: 0
        x: root.mediaCenter - width / 2

        SequentialAnimation {
            id: engageAnim

            ScriptAction {
                script: {
                    engageSignal.x =
                        root.mediaCenter -
                        engageSignal.width / 2;
                    engageSignal.opacity = 0;
                }
            }

            NumberAnimation {
                target: engageSignal
                property: "opacity"
                from: 0
                to: 0.95
                duration: 70
            }

            ParallelAnimation {
                NumberAnimation {
                    target: engageSignal
                    property: "x"
                    from: root.mediaCenter - engageSignal.width / 2
                    to: root.targetCenter - 24
                    duration: 230
                    easing.type: Easing.InOutCubic
                }

                NumberAnimation {
                    target: engageSignal
                    property: "width"
                    from: 18
                    to: 48
                    duration: 230
                    easing.type: Easing.OutCubic
                }
            }

            ParallelAnimation {
                NumberAnimation {
                    target: engageSignal
                    property: "opacity"
                    from: 0.95
                    to: 0
                    duration: 230
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: engageSignal
                    property: "width"
                    from: 48
                    to: 84
                    duration: 230
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    onEngagedChanged: {
        if (engaged)
            engageAnim.restart();
    }
}
