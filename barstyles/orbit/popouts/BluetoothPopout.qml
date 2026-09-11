pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Bluetooth

import shell.services
import shell.barkit as Pill

import "../components" as Orbit

Orbit.OrbitPopup {
    id: root

    cardWidth: 324

    cardHeight:
        174 +
        Math.min(
            3,
            root.connectedDevices.length
        ) * 38

    readonly property var adapter:
        Bluetooth.defaultAdapter

    readonly property bool adapterOn:
        adapter !== null &&
        adapter.enabled

    readonly property var connectedDevices: {
        if (
            !root.adapterOn ||
            !Bluetooth.devices
        ) {
            return [];
        }

        const values =
            Bluetooth.devices.values || [];

        const out = [];

        for (
            let i = 0;
            i < values.length;
            ++i
        ) {
            if (
                values[i] &&
                values[i].connected
            ) {
                out.push(values[i]);
            }
        }

        return out;
    }

    function materialIcon(device) {
        const icon =
            device && device.icon
                ? String(
                    device.icon
                ).toLowerCase()
                : "";

        if (
            icon.indexOf("headset") >= 0 ||
            icon.indexOf("headphone") >= 0
        ) {
            return "headphones";
        }

        if (icon.indexOf("mouse") >= 0)
            return "mouse";

        if (icon.indexOf("keyboard") >= 0)
            return "keyboard";

        if (
            icon.indexOf("gaming") >= 0 ||
            icon.indexOf("joypad") >= 0
        ) {
            return "sports_esports";
        }

        if (icon.indexOf("phone") >= 0)
            return "smartphone";

        if (icon.indexOf("speaker") >= 0)
            return "speaker";

        return "bluetooth";
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
                height: 32
                spacing: 8

                Pill.MaterialIcon {
                    anchors.verticalCenter:
                        parent.verticalCenter

                    text:
                        root.adapterOn
                            ? "bluetooth_connected"
                            : "bluetooth_disabled"

                    color:
                        root.adapterOn
                            ? Theme.primary
                            : Theme.onSurfaceVariant

                    font.pixelSize: 16
                }

                Text {
                    anchors.verticalCenter:
                        parent.verticalCenter

                    text: "BLUETOOTH"

                    color: Theme.onSurface

                    font.family: Theme.mono
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.35
                }

                Item {
                    width: 111
                    height: 1
                }

                Orbit.OrbitIconButton {
                    width: 34
                    height: 32

                    icon:
                        root.adapterOn
                            ? "power_settings_new"
                            : "power"

                    accent:
                        root.adapterOn

                    enabled:
                        root.adapter !== null

                    onClicked: {
                        if (root.adapter) {
                            root.adapter.enabled =
                                !root.adapter.enabled;
                        }
                    }
                }
            }
        }

        Orbit.OrbitStage {
            width: parent.width
            open: root.open
            delay: 105

            Row {
                width: parent.width
                spacing: 16

                Orbit.OrbitMetric {
                    width: 94

                    label: "RADIO"

                    value:
                        root.adapter === null
                            ? "MISSING"
                            : root.adapterOn
                                ? "ON"
                                : "OFF"

                    accent:
                        root.adapterOn
                }

                Orbit.OrbitMetric {
                    width: 94

                    label: "LINKED"

                    value:
                        root.adapterOn
                            ? String(
                                root.connectedDevices.length
                            )
                            : "0"

                    accent:
                        root.connectedDevices.length > 0
                }

                Orbit.OrbitMetric {
                    width: 88

                    label: "STATE"

                    value:
                        root.adapterOn
                            ? root.connectedDevices.length > 0
                                ? "ACTIVE"
                                : "IDLE"
                            : "OFF"
                }
            }
        }

        Orbit.OrbitStage {
            width: parent.width
            open: root.open
            delay: 160
            spacing: 2

            Text {
                visible:
                    root.adapterOn &&
                    root.connectedDevices.length === 0

                text: "No connected devices"

                color:
                    Theme.onSurfaceVariant

                font.family: Theme.fontPrimary
                font.pixelSize: 11
            }

            Repeater {
                model:
                    root.connectedDevices.slice(
                        0,
                        3
                    )

                delegate: Item {
                    id: deviceRow

                    required property var modelData

                    width: parent.width
                    height: 38

                    readonly property int battery:
                        BtLink.batteryLevel(
                            modelData
                        )

                    Rectangle {
                        anchors.fill: parent

                        radius: 7

                        color:
                            rowHover.hovered
                                ? Theme.surfaceContainerLow
                                : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: 100
                            }
                        }
                    }

                    Pill.MaterialIcon {
                        anchors {
                            left: parent.left
                            leftMargin: 4

                            verticalCenter:
                                parent.verticalCenter
                        }

                        text:
                            root.materialIcon(
                                deviceRow.modelData
                            )

                        color:
                            Theme.primary

                        font.pixelSize: 15
                    }

                    Column {
                        anchors {
                            left: parent.left
                            leftMargin: 30

                            right: batteryText.left
                            rightMargin: 8

                            verticalCenter:
                                parent.verticalCenter
                        }

                        spacing: 1

                        Text {
                            width: parent.width

                            text:
                                BtLink.label(
                                    deviceRow.modelData
                                )

                            elide:
                                Text.ElideRight

                            color:
                                Theme.onSurface

                            font.family:
                                Theme.fontPrimary

                            font.pixelSize: 11
                            font.weight: Font.Medium
                        }

                        Text {
                            text:
                                BtLink.typeLabel(
                                    deviceRow.modelData
                                ).toUpperCase()

                            color:
                                Theme.onSurfaceVariant

                            font.family: Theme.mono
                            font.pixelSize: 9
                            font.letterSpacing: 0.65
                        }
                    }

                    Text {
                        id: batteryText

                        anchors {
                            right: parent.right
                            rightMargin: 5

                            verticalCenter:
                                parent.verticalCenter
                        }

                        visible:
                            deviceRow.battery >= 0

                        text:
                            deviceRow.battery >= 0
                                ? deviceRow.battery + "%"
                                : ""

                        color:
                            Theme.onSurfaceVariant

                        font.family: Theme.mono
                        font.pixelSize: 9
                    }

                    HoverHandler {
                        id: rowHover
                    }
                }
            }
        }
    }
}
