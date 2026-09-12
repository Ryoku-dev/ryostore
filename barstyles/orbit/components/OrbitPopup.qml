import QtQuick
import shell.services

Item {
    id: root

    default property alias contentData:
        contentHost.data

    property bool open: false

    property real anchorX: 0
    property real availableWidth: 0

    property real cardWidth: 300
    property real cardHeight: 200

    property real stemStartY: -12

    readonly property real localAnchor:
        Math.max(
            28,
            Math.min(
                root.width - 28,
                root.anchorX - root.x
            )
        )

    x: Math.max(
        12,
        Math.min(
            root.availableWidth -
            root.cardWidth -
            12,

            root.anchorX -
            root.cardWidth / 2
        )
    )

    y:
        root.open
            ? 58
            : 50

    width: root.cardWidth
    height: root.cardHeight

    opacity:
        root.open
            ? 1
            : 0

    scale:
        root.open
            ? 1
            : 0.925

    visible:
        root.open ||
        root.opacity > 0.01

    transformOrigin: Item.Top

    onOpenChanged: {
        if (root.open)
            routeSequence.restart();
    }

    Behavior on x {
        NumberAnimation {
            duration: 175
            easing.type: Easing.OutCubic
        }
    }

    Behavior on y {
        NumberAnimation {
            duration: 240
            easing.type: Easing.OutCubic
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration:
                root.open
                    ? 165
                    : 105

            easing.type: Easing.OutCubic
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration:
                root.open
                    ? 270
                    : 140

            easing.type:
                root.open
                    ? Easing.OutBack
                    : Easing.OutCubic
        }
    }

    // -------------------------------------------------------------------------
    // Signal route from pod into the panel
    // -------------------------------------------------------------------------

    Rectangle {
        id: stem

        x:
            root.localAnchor

        y:
            root.stemStartY

        width: 1

        height:
            root.open
                ? -root.stemStartY + 8
                : 0

        color:
            Theme.primary

        opacity:
            root.open
                ? 0.78
                : 0

        Behavior on height {
            NumberAnimation {
                duration: 185
                easing.type: Easing.OutCubic
            }
        }

        Behavior on opacity {
            NumberAnimation { duration: 105 }
        }
    }

    Rectangle {
        id: connectorDot

        x: stem.x - 2
        y: root.stemStartY - 2

        width: 5
        height: 5
        radius: width / 2

        color:
            Theme.primary

        opacity:
            root.open
                ? 1
                : 0

        scale:
            root.open
                ? 1
                : 0

        Behavior on opacity {
            NumberAnimation { duration: 100 }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 175
                easing.type: Easing.OutBack
            }
        }
    }

    Rectangle {
        id: packet

        x: stem.x - 1.5
        y: root.stemStartY

        width: 4
        height: 4
        radius: width / 2

        color:
            Theme.primary

        opacity: 0
    }

    // -------------------------------------------------------------------------
    // Dock: the panel is visually part of the route, not a detached card
    // -------------------------------------------------------------------------

    Rectangle {
        id: body

        x: 0
        y: 8

        width: parent.width
        height: parent.height - 8

        radius: 16

        color: Qt.rgba(
            Theme.surface.r,
            Theme.surface.g,
            Theme.surface.b,
            0.965
        )

        border.width: 1

        border.color: Qt.rgba(
            Theme.primary.r,
            Theme.primary.g,
            Theme.primary.b,
            0.34
        )
    }

    Rectangle {
        id: dock

        x:
            root.localAnchor - width / 2

        y: 4

        width: 42
        height: 9

        radius: 4

        color:
            Theme.surface

        border.width: 1

        border.color:
            Qt.rgba(
                Theme.primary.r,
                Theme.primary.g,
                Theme.primary.b,
                0.54
            )
    }

    // Left and right header rails deliberately have different visual weight.
    Rectangle {
        id: headerLeft

        x: 18
        y: 8

        width:
            Math.max(
                0,
                dock.x - x - 7
            )

        height: 1

        color:
            Theme.primary

        opacity: 0.28
    }

    Rectangle {
        id: headerRight

        x:
            dock.x +
            dock.width +
            7

        y: 8

        width:
            Math.max(
                0,
                root.width -
                x -
                26
            )

        height: 1

        color:
            Theme.outlineVariant

        opacity: 0.34
    }

    Rectangle {
        x: 0
        y: 28

        width: 3
        height: 26

        color:
            Theme.primary

        opacity: 0.28
    }

    Rectangle {
        x: root.width - 1
        y: 46

        width: 1
        height: 14

        color:
            Theme.outlineVariant

        opacity: 0.42
    }

    Rectangle {
        id: headerPacket

        y: 7

        width: 28
        height: 3
        radius: 2

        color:
            Theme.primary

        opacity: 0

        x:
            dock.x +
            dock.width / 2 -
            width / 2
    }

    SequentialAnimation {
        id: routeSequence

        PropertyAction {
            target: packet
            property: "y"
            value: root.stemStartY
        }

        PropertyAction {
            target: packet
            property: "opacity"
            value: 0
        }

        PropertyAction {
            target: headerPacket
            property: "opacity"
            value: 0
        }

        PauseAnimation {
            duration: 35
        }

        NumberAnimation {
            target: packet
            property: "opacity"

            from: 0
            to: 0.95

            duration: 55
        }

        NumberAnimation {
            target: packet
            property: "y"

            from: root.stemStartY
            to: 5

            duration: 150
            easing.type: Easing.InCubic
        }

        ParallelAnimation {
            NumberAnimation {
                target: packet
                property: "opacity"

                from: 0.95
                to: 0

                duration: 70
            }

            NumberAnimation {
                target: headerPacket
                property: "opacity"

                from: 0
                to: 0.85

                duration: 70
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: headerPacket
                property: "x"

                from:
                    dock.x +
                    dock.width / 2 -
                    headerPacket.width / 2

                to:
                    root.width -
                    headerPacket.width -
                    22

                duration: 250
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: headerPacket
                property: "width"

                from: 28
                to: 64

                duration: 250
                easing.type: Easing.OutCubic
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: headerPacket
                property: "opacity"

                from: 0.85
                to: 0

                duration: 180
            }

            NumberAnimation {
                target: headerPacket
                property: "width"

                from: 64
                to: 92

                duration: 180
            }
        }
    }

    MouseArea {
        anchors.fill: body
        acceptedButtons: Qt.AllButtons
        z: 0
    }

    Item {
        id: contentHost

        x: 16
        y: 24

        width: parent.width - 32
        height: parent.height - 38

        z: 2
    }
}
