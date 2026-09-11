import QtQuick

import shell.services
import shell.barkit as Pill

import "../components" as Orbit

Orbit.OrbitPopup {
    id: root

    cardWidth: 302
    cardHeight: 208

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
                        Battery.charging
                            ? "battery_charging_full"
                            : "battery_full"

                    color:
                        Battery.low
                            ? Theme.error
                            : Theme.primary

                    font.pixelSize: 16
                }

                Text {
                    anchors.verticalCenter:
                        parent.verticalCenter

                    text: "POWER"

                    color: Theme.onSurface

                    font.family: Theme.mono
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.55
                }
            }
        }

        Orbit.OrbitStage {
            width: parent.width
            open: root.open
            delay: 105
            spacing: 6

            Row {
                width: parent.width

                Text {
                    text:
                        Battery.present
                            ? Battery.pct + "%"
                            : "--"

                    color:
                        Battery.low
                            ? Theme.error
                            : Theme.onSurface

                    font.family: Theme.mono
                    font.pixelSize: 30
                    font.weight: Font.DemiBold
                }

                Item {
                    width: 16
                    height: 1
                }

                Column {
                    anchors.verticalCenter:
                        parent.verticalCenter

                    spacing: 2

                    Text {
                        text:
                            Battery.stateLabel

                        color:
                            Theme.onSurface

                        font.family:
                            Theme.fontPrimary

                        font.pixelSize: 11
                        font.weight: Font.Medium
                    }

                    Text {
                        text:
                            Battery.hasTime
                                ? Battery.timeStr
                                : Battery.onAc
                                    ? "EXTERNAL POWER"
                                    : "BATTERY POWER"

                        color:
                            Theme.onSurfaceVariant

                        font.family: Theme.mono
                        font.pixelSize: 9
                        font.letterSpacing: 0.65
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 5
                radius: 2

                color:
                    Theme.outlineVariant

                Rectangle {
                    width:
                        parent.width *
                        Battery.frac

                    height: parent.height
                    radius: parent.radius

                    color:
                        Battery.low
                            ? Theme.error
                            : Theme.primary

                    Behavior on width {
                        NumberAnimation {
                            duration: 200
                            easing.type:
                                Easing.OutCubic
                        }
                    }
                }
            }
        }

        Orbit.OrbitStage {
            width: parent.width
            open: root.open
            delay: 165

            Row {
                width: parent.width
                spacing: 12

                Orbit.OrbitMetric {
                    width: 84

                    label: "HEALTH"

                    value:
                        Battery.healthSupported
                            ? Battery.health + "%"
                            : "--"
                }

                Orbit.OrbitMetric {
                    width: 84

                    label: "DRAW"

                    value:
                        Math.abs(
                            Battery.rateW
                        ).toFixed(1) + " W"

                    accent:
                        Math.abs(
                            Battery.rateW
                        ) > 0.1
                }

                Orbit.OrbitMetric {
                    width: 86

                    label: "SOURCE"

                    value:
                        Battery.onAc
                            ? "AC"
                            : "CELL"

                    accent:
                        Battery.onAc
                }
            }
        }
    }
}
