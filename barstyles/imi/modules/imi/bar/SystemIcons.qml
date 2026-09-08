pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import shell.services as RyokuServices
import shell.barkit as Pill
import "../../../shared" as Shared
import "../../../popouts" as Popouts
import "../../.."
import "../../../services"
import "../../common"
import "../../common/widgets"
import "../../common/functions"

Item {
    id: root
    property bool vertical: Config.options.bar.vertical
    property bool isMaterial: Config.options.bar.cornerStyle === 3

    implicitWidth: root.vertical ? 32 : (mainRow.implicitWidth + 2)
    implicitHeight: root.vertical ? (mainRow.implicitHeight + 2) : 32
    width: implicitWidth
    height: implicitHeight

    readonly property color hoverDarkenColor: Qt.rgba(0, 0, 0, 0.18)
    readonly property int iconSize: 15

    RowLayout {
        id: mainRow
        anchors.centerIn: parent
        spacing: 6

        // ──────────────────────────────────────────────
        // Pill 1: System Indicators (Audio, Connectivity, Notifications)
        // ──────────────────────────────────────────────
        Rectangle {
            id: statusPill
            implicitWidth: flow.implicitWidth + 14
            implicitHeight: 28
            radius: 14
            color: root.isMaterial ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Background
            border.width: root.isMaterial ? 0 : 1
            border.color: Appearance.colors.colLayer0Border
            Layout.alignment: Qt.AlignVCenter

            RowLayout {
                id: flow
                anchors.centerIn: parent
                spacing: 4

                // 1. Audio & Volume Chip
                Rectangle {
                    id: audioCell
                    implicitWidth: audioRow.implicitWidth + 12
                    implicitHeight: 22
                    radius: 11
                    color: (audioHh.hovered || audioPop.shown) ? root.hoverDarkenColor : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Layout.alignment: Qt.AlignVCenter

                    HoverHandler { id: audioHh }

                    WheelHandler {
                        onWheel: (e) => {
                            const delta = e.angleDelta.y > 0 ? 0.05 : -0.05;
                            if (Audio.sink && Audio.sink.audio) {
                                Audio.sink.audio.volume = Math.max(0, Math.min(1.5, Audio.sink.audio.volume + delta));
                            }
                        }
                    }

                    TapHandler {
                        onTapped: {
                            if (Audio.sink && Audio.sink.audio) {
                                Audio.sink.audio.muted = !Audio.sink.audio.muted;
                            }
                        }
                    }

                    Shared.Popout {
                        id: audioPop
                        target: audioCell
                        targetHovered: audioHh.hovered
                        preferredWidth: 300
                        preferredHeight: 260
                        namespace: "ryoku-bar-popout"
                        content: Component {
                            Popouts.AudioPopout { open: true }
                        }
                    }

                    Row {
                        id: audioRow
                        anchors.centerIn: parent
                        spacing: 5

                        Pill.MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: (Audio.sink && Audio.sink.audio && Audio.sink.audio.muted) ? "volume_off" : "volume_up"
                            font.pixelSize: root.iconSize
                            color: root.isMaterial ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                        }

                        Pill.MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Audio.source?.audio?.muted ?? false
                            text: "mic_off"
                            font.pixelSize: root.iconSize
                            color: root.isMaterial ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                        }
                    }
                }

                // 2. Connectivity Chip (Wi-Fi + Bluetooth)
                Rectangle {
                    id: connCell
                    implicitWidth: connRow.implicitWidth + 12
                    implicitHeight: 22
                    radius: 11
                    color: (connHh.hovered || connPop.shown) ? root.hoverDarkenColor : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Layout.alignment: Qt.AlignVCenter

                    HoverHandler { id: connHh }

                    Shared.Popout {
                        id: connPop
                        target: connCell
                        targetHovered: connHh.hovered
                        preferredWidth: 300
                        preferredHeight: 260
                        namespace: "ryoku-bar-popout"
                        content: Component {
                            Popouts.ConnectivityPopout { open: true }
                        }
                    }

                    Row {
                        id: connRow
                        anchors.centerIn: parent
                        spacing: 6

                        Pill.MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Network.wifiConnected ? "wifi" : (Network.kind === "ethernet" ? "lan" : "wifi_off")
                            font.pixelSize: root.iconSize
                            color: root.isMaterial ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                        }

                        Pill.MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Boolean(BluetoothStatus.available)
                            text: BluetoothStatus.connected ? "bluetooth_connected" : (BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled")
                            font.pixelSize: root.iconSize
                            color: root.isMaterial ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                        }
                    }
                }

                // 3. Notifications Chip
                Rectangle {
                    id: notifCell
                    implicitWidth: 22
                    implicitHeight: 22
                    radius: 11
                    color: (notifHh.hovered || notifPop.shown) ? root.hoverDarkenColor : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Layout.alignment: Qt.AlignVCenter

                    HoverHandler { id: notifHh }

                    TapHandler {
                        onTapped: {
                            Notifications.silent = !Notifications.silent;
                        }
                    }

                    Shared.Popout {
                        id: notifPop
                        target: notifCell
                        targetHovered: notifHh.hovered
                        preferredWidth: 320
                        preferredHeight: 340
                        namespace: "ryoku-bar-popout"
                        content: Component {
                            Popouts.NotificationInbox { open: true }
                        }
                    }

                    Pill.MaterialIcon {
                        anchors.centerIn: parent
                        text: Notifications.silent ? "notifications_off" : "notifications"
                        font.pixelSize: root.iconSize
                        color: root.isMaterial ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                    }
                }
            }
        }

        // ──────────────────────────────────────────────
        // Pill 2: Dedicated Stash Pill
        // ──────────────────────────────────────────────
        Rectangle {
            id: stashPill
            implicitWidth: 28
            implicitHeight: 28
            radius: 14
            color: stashHh.hovered
                ? (root.isMaterial ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSecondaryContainer)
                : (root.isMaterial ? Appearance.colors.colSecondaryContainer : Appearance.colors.colLayer0Background)
            border.width: root.isMaterial ? 0 : 1
            border.color: Appearance.colors.colLayer0Border
            Behavior on color { ColorAnimation { duration: 150 } }
            Layout.alignment: Qt.AlignVCenter

            HoverHandler { id: stashHh }

            TapHandler {
                onTapped: {
                    RyokuServices.ShellState.requestSurface("stash", "", undefined);
                }
            }

            Pill.MaterialIcon {
                anchors.centerIn: parent
                text: "inventory_2"
                font.pixelSize: root.iconSize
                color: root.isMaterial ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
            }
        }
    }
}
