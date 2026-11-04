pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import "../../../common"
import "../../../common/functions"
import "../../../common/widgets"
import "../../../../services"

GridLayout {
    id: root

    columns: (width > 0 ? width >= 460 : true) ? 2 : 1
    columnSpacing: 10
    rowSpacing: 10

    readonly property var clockDisplayAxes: ({
        "wght": 680,
        "wdth": 86,
        "ROND": 100,
        "opsz": 64,
        "GRAD": 35
    })
    readonly property var dateDisplayAxes: ({
        "wght": 640,
        "wdth": 92,
        "ROND": 100,
        "opsz": 48,
        "GRAD": 20
    })

    readonly property date effectiveDate: {
        if (Config.options.time.secondPrecision)
            return previewClock.date;
        return new Date(Math.floor(previewClock.date.getTime() / 60000) * 60000);
    }

    readonly property string effectiveTimeFormat: {
        const baseFormat = String(Config.options.time.format ?? "hh:mm");
        const withoutLiterals = baseFormat.replace(/'[^']*'/g, "");
        if (!Config.options.bar.clock.showSeconds || /s/.test(withoutLiterals))
            return baseFormat;

        const suffixMatch = baseFormat.match(/(\s+(?:ap|AP|a|A))$/);
        if (suffixMatch)
            return baseFormat.slice(0, -suffixMatch[1].length) + ":" + Config.options.time.secondsFormat + suffixMatch[1];
        return baseFormat + ":" + Config.options.time.secondsFormat;
    }

    readonly property string clockText: Qt.locale().toString(root.effectiveDate, root.effectiveTimeFormat)
    readonly property string dateText: Qt.locale().toString(root.effectiveDate, Config.options.time.dateFormat)

    SystemClock {
        id: previewClock
        precision: SystemClock.Seconds
    }

    Rectangle {
        id: clockCard
        Layout.fillWidth: true
        Layout.minimumWidth: root.columns === 2 ? 210 : 0
        implicitHeight: 166
        radius: Appearance.rounding.large
        color: Appearance.colors.colPrimaryContainer
        clip: true
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: clockCard.width
                height: clockCard.height
                radius: clockCard.radius
            }
        }

        MaterialShape {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: -18
            anchors.topMargin: -24
            implicitSize: 132
            rotation: 18
            shape: MaterialShape.Shape.SoftBurst
            color: Appearance.colors.colOnPrimaryContainer
            opacity: 0.1
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol {
                    text: "schedule"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colOnPrimaryContainer
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Clock")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.variableAxes: Appearance.font.variableAxes.rounded
                    color: Appearance.colors.colOnPrimaryContainer
                }
            }

            Item {
                Layout.fillHeight: true
            }

            StyledText {
                Layout.fillWidth: true
                text: root.clockText
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.hugeass * 2.05
                font.variableAxes: root.clockDisplayAxes
                font.weight: Font.Bold
                font.letterSpacing: 1.2
                font.features: ({ "tnum": 1 })
                color: Appearance.colors.colOnPrimaryContainer
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: Config.options.time.secondPrecision
                    ? Translation.tr("Second precision enabled")
                    : Translation.tr("Updates once per minute")
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.variableAxes: Appearance.font.variableAxes.main
                color: Appearance.colors.colOnPrimaryContainer
                opacity: 0.75
            }
        }
    }

    Rectangle {
        id: dateCard
        Layout.fillWidth: true
        Layout.minimumWidth: root.columns === 2 ? 210 : 0
        implicitHeight: 166
        radius: Appearance.rounding.large
        color: Appearance.colors.colTertiaryContainer
        clip: true
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: dateCard.width
                height: dateCard.height
                radius: dateCard.radius
            }
        }

        MaterialShape {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: -18
            anchors.topMargin: -24
            implicitSize: 132
            rotation: -16
            shape: MaterialShape.Shape.Cookie9Sided
            color: Appearance.colors.colOnTertiaryContainer
            opacity: 0.1
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol {
                    text: "calendar_month"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colOnTertiaryContainer
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Date")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.variableAxes: Appearance.font.variableAxes.rounded
                    color: Appearance.colors.colOnTertiaryContainer
                }
            }

            Item {
                Layout.fillHeight: true
            }

            StyledText {
                Layout.fillWidth: true
                text: root.dateText
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.hugeass * 1.72
                font.variableAxes: root.dateDisplayAxes
                font.weight: Font.Bold
                font.letterSpacing: 0.45
                color: Appearance.colors.colOnTertiaryContainer
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Live preview · %1").arg(String(Config.options.time.dateFormat))
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.variableAxes: Appearance.font.variableAxes.main
                color: Appearance.colors.colOnTertiaryContainer
                opacity: 0.75
                elide: Text.ElideRight
            }
        }
    }
}
