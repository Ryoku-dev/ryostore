import QtQuick
import shell.services
import shell.barkit as Pill

Item {
    id: root

    property string icon: "circle"
    property string label: ""
    property bool active: false
    property bool warning: false
    property bool clickable: true
    property bool selected: false

    signal activated(real centerX)

    readonly property bool expanded:
        (hover.hovered || root.selected) &&
        root.label.length > 0

    implicitWidth:
        expanded
            ? Math.max(48, content.implicitWidth + 18)
            : 30

    implicitHeight: 32

    scale:
        root.selected
            ? 1.055
            : hover.hovered
                ? 1.035
                : 1

    y:
        root.selected
            ? -2
            : hover.hovered
                ? -1
                : 0

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 175
            easing.type: Easing.OutCubic
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutCubic
        }
    }

    Behavior on y {
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width
        height: 28
        radius: 14

        color:
            root.expanded || root.selected
                ? Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.96)
                : "transparent"

        border.width:
            root.expanded || root.selected
                ? 1
                : 0

        border.color:
            root.selected
                ? Theme.primary
                : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.40)

        Behavior on color {
            ColorAnimation { duration: 130 }
        }

        Row {
            id: content
            anchors.centerIn: parent
            spacing: 6

            Item {
                width: 22
                height: 22

                Rectangle {
                    anchors.centerIn: parent
                    visible: root.selected
                    width: 27
                    height: 27
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.primary
                    opacity: 0.26

                    SequentialAnimation on scale {
                        running: root.selected
                        loops: Animation.Infinite

                        NumberAnimation {
                            from: 0.94
                            to: 1.16
                            duration: 760
                            easing.type: Easing.InOutSine
                        }

                        NumberAnimation {
                            from: 1.16
                            to: 0.94
                            duration: 760
                            easing.type: Easing.InOutSine
                        }
                    }

                    SequentialAnimation on opacity {
                        running: root.selected
                        loops: Animation.Infinite

                        NumberAnimation {
                            from: 0.32
                            to: 0.12
                            duration: 760
                            easing.type: Easing.InOutSine
                        }

                        NumberAnimation {
                            from: 0.12
                            to: 0.32
                            duration: 760
                            easing.type: Easing.InOutSine
                        }
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: root.active || root.selected ? 22 : 18
                    height: width
                    radius: width / 2

                    color:
                        root.warning
                            ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.18)
                            : root.active || root.selected
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                                : Theme.surface

                    border.width: 1
                    border.color:
                        root.warning
                            ? Theme.error
                            : root.active || root.selected
                                ? Theme.primary
                                : Theme.outlineVariant

                    Behavior on width {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Pill.MaterialIcon {
                    anchors.centerIn: parent
                    text: root.icon
                    font.pixelSize: 13

                    color:
                        root.warning
                            ? Theme.error
                            : root.active || root.selected
                                ? Theme.primary
                                : Theme.onSurfaceVariant
                }
            }

            Text {
                visible: root.expanded
                text: root.label
                color: Theme.onSurface
                font.family: Theme.mono
                font.pixelSize: 10
                font.weight: Font.Medium
                opacity: root.expanded ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 110 }
                }
            }
        }
    }

    HoverHandler { id: hover }

    TapHandler {
        enabled: root.clickable
        cursorShape: Qt.PointingHandCursor

        onTapped: {
            const p = root.mapToItem(null, root.width / 2, root.height / 2);
            root.activated(p.x);
        }
    }
}
