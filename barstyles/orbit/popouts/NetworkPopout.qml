import QtQuick

import shell.services
import shell.barkit as Pill

import "../components" as Orbit

Orbit.OrbitPopup {
    id: root

    cardWidth: 318

    cardHeight:
        Network.kind === "wifi"
            ? 214
            : 194

    readonly property bool connected:
        Network.kind.length > 0

    readonly property int strength:
        Math.round(Network.level * 100)

    readonly property string mainLabel:
        Network.kind === "wifi"
            ? (
                Network.activeSsid.length
                    ? Network.activeSsid
                    : "Wi-Fi"
            )
            : Network.kind === "ethernet"
                ? "Ethernet"
                : "Offline"

    readonly property string linkDetail:
        Network.kind === "wifi"
            ? root.strength + "% signal"
            : Network.kind === "ethernet"
                ? "Wired connection"
                : "No active route"

    Column {
        anchors.fill: parent
        spacing: 12

        Orbit.OrbitStage {
            width: parent.width
            open: root.open
            delay: 55
            spacing: 6

            Row {
                width: parent.width
                height: 21
                spacing: 8

                Pill.MaterialIcon {
                    anchors.verticalCenter:
                        parent.verticalCenter

                    text:
                        Network.vpnActive
                            ? "vpn_lock"
                            : Network.kind === "ethernet"
                                ? "lan"
                                : Network.kind === "wifi"
                                    ? "wifi"
                                    : "signal_wifi_off"

                    color:
                        root.connected
                            ? Theme.primary
                            : Theme.error

                    font.pixelSize: 16
                }

                Text {
                    anchors.verticalCenter:
                        parent.verticalCenter

                    text: "NETWORK"

                    color: Theme.onSurface

                    font.family: Theme.mono
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.55
                }

                Item {
                    width: 119
                    height: 1
                }

                Text {
                    anchors.verticalCenter:
                        parent.verticalCenter

                    text:
                        root.connected
                            ? "ONLINE"
                            : "OFFLINE"

                    color:
                        root.connected
                            ? Theme.primary
                            : Theme.error

                    font.family: Theme.mono
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.8
                }
            }
        }

        Orbit.OrbitStage {
            width: parent.width
            open: root.open
            delay: 105
            spacing: 4

            Text {
                width: parent.width

                text: root.mainLabel

                elide: Text.ElideRight

                color: Theme.onSurface

                font.family: Theme.fontPrimary
                font.pixelSize: 19
                font.weight: Font.DemiBold
            }

            Text {
                width: parent.width

                text: root.linkDetail.toUpperCase()

                color: Theme.onSurfaceVariant

                font.family: Theme.mono
                font.pixelSize: 9
                font.letterSpacing: 0.7
            }

            Item {
                visible:
                    Network.kind === "wifi"

                width: parent.width
                height: visible ? 12 : 0

                Rectangle {
                    anchors.verticalCenter:
                        parent.verticalCenter

                    width: parent.width
                    height: 4
                    radius: 2

                    color:
                        Theme.outlineVariant

                    Rectangle {
                        width:
                            parent.width *
                            Math.max(
                                0,
                                Math.min(
                                    1,
                                    Network.level
                                )
                            )

                        height: parent.height
                        radius: parent.radius

                        color:
                            Theme.primary

                        Behavior on width {
                            NumberAnimation {
                                duration: 180
                                easing.type:
                                    Easing.OutCubic
                            }
                        }
                    }
                }
            }
        }

        Orbit.OrbitStage {
            width: parent.width
            open: root.open
            delay: 155

            Row {
                width: parent.width
                spacing: 18

                Orbit.OrbitMetric {
                    width: 92

                    label: "VPN"

                    value:
                        Network.vpnActive
                            ? (
                                Network.vpnName.length
                                    ? Network.vpnName.toUpperCase()
                                    : "ACTIVE"
                            )
                            : "OFF"

                    accent:
                        Network.vpnActive
                }

                Orbit.OrbitMetric {
                    width: 92

                    label: "DNS"

                    value:
                        Network.dnsProvider.toUpperCase()
                }

                Orbit.OrbitMetric {
                    width: 78

                    label: "LINK"

                    value:
                        Network.kind === "wifi"
                            ? root.strength + "%"
                            : Network.kind === "ethernet"
                                ? "LAN"
                                : "NONE"

                    accent:
                        root.connected

                    warning:
                        !root.connected
                }
            }
        }

        Orbit.OrbitStage {
            width: parent.width
            open: root.open
            delay: 205

            Row {
                spacing: 8

                Orbit.OrbitIconButton {
                    icon:
                        Network.wifiRadio
                            ? "wifi"
                            : "wifi_off"

                    accent:
                        Network.wifiRadio

                    enabled:
                        Network.wifiPresent

                    onClicked:
                        Network.setWifiEnabled(
                            !Network.wifiRadio
                        )
                }

                Orbit.OrbitIconButton {
                    icon: "refresh"

                    enabled:
                        Network.wifiPresent &&
                        Network.wifiRadio

                    onClicked:
                        Network.refresh()
                }

                Text {
                    anchors.verticalCenter:
                        parent.verticalCenter

                    text:
                        Network.wifiPresent
                            ? Network.wifiRadio
                                ? "RADIO ON"
                                : "RADIO OFF"
                            : "NO WI-FI RADIO"

                    color:
                        Theme.onSurfaceVariant

                    font.family: Theme.mono
                    font.pixelSize: 9
                    font.letterSpacing: 0.65
                }
            }
        }
    }
}
