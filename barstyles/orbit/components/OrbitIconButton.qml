import QtQuick
import shell.services
import shell.barkit as Pill

Item {
    id: root

    property string icon: "circle"
    property bool accent: false
    property bool danger: false

    signal clicked()

    implicitWidth: 38
    implicitHeight: 34

    opacity: enabled ? 1 : 0.34

    scale:
        press.pressed
            ? 0.94
            : hover.hovered
                ? 1.025
                : 1

    y:
        press.pressed
            ? 1
            : 0

    Behavior on scale {
        NumberAnimation {
            duration: 105
            easing.type: Easing.OutCubic
        }
    }

    Behavior on y {
        NumberAnimation {
            duration: 90
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 10

        color:
            root.danger
                ? Qt.rgba(
                    Theme.error.r,
                    Theme.error.g,
                    Theme.error.b,
                    hover.hovered ? 0.20 : 0.12
                )
                : root.accent
                    ? Qt.rgba(
                        Theme.primary.r,
                        Theme.primary.g,
                        Theme.primary.b,
                        hover.hovered ? 0.22 : 0.13
                    )
                    : hover.hovered
                        ? Theme.surfaceContainer
                        : Theme.surfaceContainerLow

        border.width: 1

        border.color:
            root.danger
                ? Qt.rgba(
                    Theme.error.r,
                    Theme.error.g,
                    Theme.error.b,
                    0.42
                )
                : root.accent
                    ? Qt.rgba(
                        Theme.primary.r,
                        Theme.primary.g,
                        Theme.primary.b,
                        0.44
                    )
                    : Qt.rgba(
                        Theme.outlineVariant.r,
                        Theme.outlineVariant.g,
                        Theme.outlineVariant.b,
                        0.50
                    )

        Behavior on color {
            ColorAnimation { duration: 105 }
        }
    }

    Rectangle {
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
        }

        width:
            root.accent || root.danger || hover.hovered
                ? 14
                : 6

        height: 1

        color:
            root.danger
                ? Theme.error
                : Theme.primary

        opacity:
            root.accent || root.danger
                ? 0.72
                : hover.hovered
                    ? 0.48
                    : 0.14

        Behavior on width {
            NumberAnimation {
                duration: 130
                easing.type: Easing.OutCubic
            }
        }

        Behavior on opacity {
            NumberAnimation { duration: 110 }
        }
    }

    Pill.MaterialIcon {
        anchors.centerIn: parent

        text: root.icon

        fill:
            root.accent || root.danger
                ? 1
                : 0

        font.pixelSize: 16

        color:
            root.danger
                ? Theme.error
                : root.accent
                    ? Theme.primary
                    : Theme.onSurface
    }

    HoverHandler {
        id: hover

        cursorShape:
            root.enabled
                ? Qt.PointingHandCursor
                : Qt.ArrowCursor
    }

    TapHandler {
        id: press
        enabled: root.enabled

        onTapped:
            root.clicked()
    }
}
