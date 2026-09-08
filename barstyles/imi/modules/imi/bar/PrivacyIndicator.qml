pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import shell.services
import shell.barkit as Pill
import "../../.."
import "../../common"
import "../../common/widgets"
import "../../../services"
import "../../../shared" as Shared

Item {
    id: root

    property bool vertical: Config.options.bar.vertical
    property bool isMaterial: Config.options.bar.cornerStyle === 3

    readonly property bool micOn: Boolean(MediaCapture.micActive)
    readonly property bool cameraOn: Boolean(MediaCapture.cameraActive)
    readonly property bool screencastOn: Boolean(MediaCapture.screencastActive || ScreenRecord.recording)
    readonly property bool shown: micOn || cameraOn || screencastOn

    visible: implicitWidth > 0
    implicitWidth: shown ? (chip.implicitWidth + (isMaterial ? 16 : 10)) : 0
    implicitHeight: vertical ? (chip.implicitHeight + 8) : Appearance.sizes.barHeight
    width: implicitWidth
    height: implicitHeight

    Behavior on implicitWidth {
        NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
    }

    HoverHandler { id: hh }

    Shared.Popout {
        target: root
        targetHovered: hh.hovered
        preferredWidth: 240
        preferredHeight: 180
        namespace: "ryoku-bar-popout"
        content: Component {
            Rectangle {
                id: card
                width: 240
                implicitHeight: col.implicitHeight + 24
                radius: Theme.radiusWindow
                color: Theme.surface
                border.width: 1
                border.color: Theme.outlineVariant

                ColumnLayout {
                    id: col
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        margins: 14
                    }
                    spacing: 10

                    RowLayout {
                        spacing: 8
                        Layout.fillWidth: true

                        Pill.MaterialIcon {
                            text: "security"
                            font.pixelSize: 18
                            color: Theme.primary
                        }

                        StyledText {
                            text: "Privacy & Permissions"
                            font.weight: Font.Bold
                            font.pixelSize: 14
                            color: Theme.onSurface
                            Layout.fillWidth: true
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.outlineVariant
                    }

                    RowLayout {
                        spacing: 10
                        visible: root.micOn
                        Layout.fillWidth: true

                        Pill.MaterialIcon {
                            text: "mic"
                            font.pixelSize: 16
                            color: Theme.primary
                        }

                        StyledText {
                            text: "Microphone Active"
                            font.pixelSize: 12
                            color: Theme.onSurface
                            Layout.fillWidth: true
                        }
                    }

                    RowLayout {
                        spacing: 10
                        visible: root.cameraOn
                        Layout.fillWidth: true

                        Pill.MaterialIcon {
                            text: "videocam"
                            font.pixelSize: 16
                            color: Theme.primary
                        }

                        StyledText {
                            text: "Camera Active"
                            font.pixelSize: 12
                            color: Theme.onSurface
                            Layout.fillWidth: true
                        }
                    }

                    RowLayout {
                        spacing: 10
                        visible: root.screencastOn
                        Layout.fillWidth: true

                        Pill.MaterialIcon {
                            text: "screen_share"
                            font.pixelSize: 16
                            color: Theme.primary
                        }

                        StyledText {
                            text: "Screen Sharing / Recording"
                            font.pixelSize: 12
                            color: Theme.onSurface
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: chip
        anchors.centerIn: parent
        implicitWidth: iconsRow.implicitWidth + 12
        implicitHeight: 22
        radius: 11
        color: Appearance.colors.colLayer1Hover

        Row {
            id: iconsRow
            anchors.centerIn: parent
            spacing: 6

            Pill.MaterialIcon {
                visible: root.micOn
                text: "mic"
                font.pixelSize: 13
                color: Appearance.colors.colOnPrimaryContainer
            }

            Pill.MaterialIcon {
                visible: root.cameraOn
                text: "videocam"
                font.pixelSize: 13
                color: Appearance.colors.colOnPrimaryContainer
            }

            Pill.MaterialIcon {
                visible: root.screencastOn
                text: "screen_share"
                font.pixelSize: 13
                color: Appearance.colors.colOnPrimaryContainer
            }
        }
    }
}
