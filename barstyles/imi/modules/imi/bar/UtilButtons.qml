pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import shell.services as RyokuServices
import "../../.."
import "../../../services"
import "../../common"
import "../../common/widgets"

Item {
    id: root

    property bool vertical: false
    property bool borderless: Config.options.bar.borderless
    readonly property bool isMaterial: Config.options.bar.cornerStyle === 3

    implicitWidth: isMaterial && !root.vertical ? flow.implicitWidth : root.vertical ? Appearance.sizes.verticalBarWidth - 14 : flow.implicitWidth + 4
    implicitHeight: isMaterial && root.vertical ? flow.implicitHeight: isMaterial ? 32 : root.vertical ? flow.implicitHeight + 4 : Appearance.sizes.barHeight

    Flow {
        id: flow
        anchors.centerIn: parent
        flow: root.vertical ? Flow.TopToBottom : Flow.LeftToRight
        spacing: isMaterial ? Appearance.spacing.space25 : Appearance.spacing.space50

        Loader {
            active: Config.options.bar.utilButtons.showScreenSnip
            visible: active
            sourceComponent: isMaterial ? screenSnipM3 : legacyScreenSnip
        }

        Component {
            id: screenSnipM3
            UtilButton {
                iconText: "screenshot_region"
                onClicked: Quickshell.execDetached(["sh", "-c", "flock -n -o /tmp/ryoshot.lock qs -c ryoshot"])
            }
        }

        Component {
            id: legacyScreenSnip
            CircleUtilButton {
                onClicked: Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "region", "screenshot"])
                MaterialSymbol {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 1; text: "screenshot_region"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer2
                }
            }
        }

        Loader {
            active: Config.options.bar.utilButtons.showColorPicker
            visible: active
            sourceComponent: isMaterial ? colorPickerM3 : legacyColorPicker
        }
        Component {
            id: colorPickerM3
            UtilButton {
                iconText: "colorize"
                onClicked: Quickshell.execDetached(["hyprpicker", "-a"])
            }
        }
        Component {
            id: legacyColorPicker
            CircleUtilButton {
                onClicked: Quickshell.execDetached(["hyprpicker", "-a"])
                MaterialSymbol {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 1; text: "colorize"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer2
                }
            }
        }

        Loader {
            active: Config.options.bar.utilButtons.showScreenRecord
            visible: active
            sourceComponent: isMaterial ? screenRecordM3 : legacyScreenRecord
        }

        Component {
            id: legacyScreenRecord
            Item {
                id: recordingItem
                implicitWidth: btn.implicitWidth + timerRevealer.implicitWidth
                implicitHeight: btn.implicitHeight

                property bool isRecording: Persistent.states.record.enable
                property int elapsedSeconds: 0

                onIsRecordingChanged: {
                    if (!isRecording) elapsedSeconds = 0
                }

                function formatTime(s) {
                    return Math.floor(s / 60).toString().padStart(2, '0') + ":" + (s % 60).toString().padStart(2, '0')
                }

                Timer {
                    interval: 1000
                    repeat: true
                    running: recordingItem.isRecording
                    onTriggered: recordingItem.elapsedSeconds++
                }

                CircleUtilButton {
                    id: btn
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    colBackground: recordingItem.isRecording ? Appearance.colors.colPrimaryContainer : "transparent"
                    buttonRadius: recordingItem.isRecording ? Appearance.rounding.normal : implicitHeight / 2
                    onClicked: Quickshell.execDetached([Directories.recordScriptPath])

                    Behavior on colBackground { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
                    Behavior on buttonRadius { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic } }

                    MaterialSymbol {
                        horizontalAlignment: Qt.AlignHCenter
                        fill: 1
                        text: recordingItem.isRecording ? "stop_circle" : "screen_record"
                        iconSize: Appearance.font.pixelSize.large
                        color: recordingItem.isRecording ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer2
                        Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
                    }
                }

                Revealer {
                    id: timerRevealer
                    anchors.left: btn.right
                    anchors.leftMargin: Appearance.spacing.space100
                    anchors.verticalCenter: btn.verticalCenter
                    reveal: recordingItem.isRecording && !root.vertical

                    StyledText {
                        width: implicitWidth
                        text: recordingItem.formatTime(recordingItem.elapsedSeconds)
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.features: { "tnum": 1 }
                        font.letterSpacing: -0.3
                        color: Appearance.colors.colOnLayer2
                        rightPadding: Appearance.spacing.space100
                        Component.onCompleted: width = implicitWidth
                    }
                }
            }
        }

        Component {
            id: screenRecordM3
            UtilButton {
                iconText: Persistent.states.record.enable ? "stop_circle" : "screen_record"
                forceHovered: Persistent.states.record.enable
                onClicked: Quickshell.execDetached([Directories.recordScriptPath])
            }
        }

        Loader {
            active: Config.options.bar.utilButtons.showWallpaperToggle
            visible: active
            sourceComponent: isMaterial ? wallpaperM3 : legacyWallpaper
        }
        Component {
            id: wallpaperM3
            UtilButton {
                iconText: "imagesmode"
                onClicked: Quickshell.execDetached(["sh", "-c", "flock -n -o /tmp/ryowalls.lock qs -c ryowalls"])
            }
        }
        Component {
            id: legacyWallpaper
            CircleUtilButton {
                onClicked: Quickshell.execDetached(["sh", "-c", "flock -n -o /tmp/ryowalls.lock qs -c ryowalls"])
                MaterialSymbol {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 0; text: "imagesmode"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer2
                }
            }
        }
    }
}
