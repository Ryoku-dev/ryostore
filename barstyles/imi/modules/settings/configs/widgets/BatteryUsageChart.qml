pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../../common"
import "../../../common/widgets"
import "../../../../services"

ColumnLayout {
    id: root

    visible: Battery.available
    spacing: 10

    readonly property var todayBuckets: {
        AppStats.history;
        return AppStats.batteryHours(AppStats.todayDate);
    }

    readonly property bool hasHistory: {
        for (const bucket of root.todayBuckets) {
            if (bucket)
                return true;
        }
        return false;
    }

    readonly property var rollup: {
        AppStats.history;
        return AppStats.batteryRollup([AppStats.todayDate], {});
    }

    readonly property var chartValues: {
        const values = [];
        let level = Math.max(0, Math.min(100, Battery.percentage * 100));
        for (const bucket of root.todayBuckets) {
            if (bucket)
                level = Math.max(0, Math.min(100, bucket.end));
            values.push(level);
        }
        return values;
    }

    readonly property real dischargedPercent: root.rollup.fullMwh > 0
        ? root.rollup.outMwh / root.rollup.fullMwh * 100
        : NaN
    readonly property real averageWatts: root.rollup.offAc > 0
        ? root.rollup.outMwh / 1000 / (root.rollup.offAc / 3600)
        : NaN

    function formatDischarge() {
        if (!root.hasHistory || isNaN(root.dischargedPercent))
            return "—";
        return "−" + Math.round(root.dischargedPercent) + "%";
    }

    function formatPower() {
        if (!root.hasHistory || isNaN(root.averageWatts))
            return "—";
        return root.averageWatts.toFixed(1) + " W";
    }

    Rectangle {
        id: card

        Layout.fillWidth: true
        implicitHeight: root.hasHistory ? 246 : 92
        radius: Appearance.rounding.large
        color: Appearance.colors.colLayer1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                MaterialSymbol {
                    text: "battery_saver"
                    iconSize: Appearance.font.pixelSize.huge
                    color: Appearance.colors.colPrimary
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    StyledText {
                        text: Translation.tr("Battery today")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnLayer1
                    }

                    StyledText {
                        text: root.hasHistory
                            ? Translation.tr("Charge level by hour")
                            : Translation.tr("History will appear as the sampler records")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                }

                StyledText {
                    visible: root.hasHistory
                    text: root.todayBuckets.filter(bucket => bucket !== null).length + " h"
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.Bold
                    color: Appearance.colors.colPrimary
                }
            }

            Graph {
                visible: root.hasHistory
                Layout.fillWidth: true
                Layout.preferredHeight: 112
                values: root.chartValues
                color: Appearance.colors.colPrimary
                fillOpacity: 0.2
            }

            RowLayout {
                visible: root.hasHistory
                Layout.fillWidth: true
                spacing: 0

                Repeater {
                    model: ["00", "06", "12", "18", "24"]

                    delegate: StyledText {
                        required property string modelData

                        Layout.fillWidth: true
                        text: modelData
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            RowLayout {
                visible: root.hasHistory
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 54
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colSurfaceContainerHighest

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 1

                        StyledText {
                            text: Translation.tr("Discharged today")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }

                        StyledText {
                            text: root.formatDischarge()
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnSurface
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 54
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colSurfaceContainerHighest

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 1

                        StyledText {
                            text: Translation.tr("Average draw")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }

                        StyledText {
                            text: root.formatPower()
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnSurface
                        }
                    }
                }
            }
        }
    }
}
