pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../../common"
import "../../../common/functions"
import "../../../common/widgets"
import "../../../../services"

GridLayout {
    id: root

    readonly property var choices: [
        {
            "label": Translation.tr("Monday first"),
            "dayLabel": Translation.tr("Monday"),
            "description": Translation.tr("Weeks begin on Monday"),
            "value": 0
        },
        {
            "label": Translation.tr("Sunday first"),
            "dayLabel": Translation.tr("Sunday"),
            "description": Translation.tr("Weeks begin on Sunday"),
            "value": 6
        }
    ]

    columns: (width > 0 ? width >= 480 : true) ? 2 : 1
    columnSpacing: 10
    rowSpacing: 10

    Repeater {
        model: root.choices

        delegate: RippleButton {
            id: weekChoice

            required property var modelData
            required property int index

            readonly property int choiceValue: modelData.value
            readonly property bool selected: Config.options.time.firstDayOfWeek === choiceValue

            Layout.fillWidth: true
            Layout.minimumWidth: root.columns === 2 ? 210 : 0
            implicitHeight: 148
            buttonRadius: Appearance.rounding.normal
            colBackground: selected ? Appearance.colors.colSecondaryContainer : Appearance.colors.colLayer1
            colBackgroundHover: selected ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colLayer1Hover
            colRipple: selected ? Appearance.colors.colSecondaryContainerActive : Appearance.colors.colLayer1Active
            onClicked: Config.options.time.firstDayOfWeek = choiceValue

            contentItem: ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MaterialSymbol {
                        text: "calendar_today"
                        iconSize: Appearance.font.pixelSize.large
                        color: weekChoice.selected ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            Layout.fillWidth: true
                            text: weekChoice.modelData.label
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Bold
                            color: weekChoice.selected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: weekChoice.modelData.description
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.variableAxes: Appearance.font.variableAxes.main
                            color: weekChoice.selected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colSubtext
                            opacity: 0.82
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        implicitWidth: selectedLabel.implicitWidth + 16
                        implicitHeight: 26
                        radius: Appearance.rounding.full
                        color: weekChoice.selected
                            ? Appearance.colors.colPrimary
                            : ColorUtils.transparentize(Appearance.colors.colLayer2)

                        StyledText {
                            id: selectedLabel
                            anchors.centerIn: parent
                            text: weekChoice.selected ? Translation.tr("Selected") : Translation.tr("Select")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.DemiBold
                            color: weekChoice.selected ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    MaterialSymbol {
                        text: "view_week"
                        iconSize: Appearance.font.pixelSize.normal
                        color: weekChoice.selected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colSubtext
                        opacity: 0.82
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Week layout preview")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.DemiBold
                        color: weekChoice.selected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                    }

                    Rectangle {
                        implicitWidth: firstDayLabel.implicitWidth + 14
                        implicitHeight: 24
                        radius: Appearance.rounding.full
                        color: weekChoice.selected
                            ? ColorUtils.transparentize(Appearance.colors.colPrimary)
                            : ColorUtils.transparentize(Appearance.colors.colLayer2)

                        StyledText {
                            id: firstDayLabel
                            anchors.centerIn: parent
                            text: Translation.tr("Starts %1").arg(weekChoice.modelData.dayLabel)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.DemiBold
                            color: weekChoice.selected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colSubtext
                        }
                    }
                }

                WeekRow {
                    Layout.fillWidth: true
                    date: DateTime.clock.date
                    locale: ({
                        "firstDayOfWeek": weekChoice.choiceValue === 0 ? 1 : 0
                    })

                    delegate: Component {
                        Item {
                            required property var model
                            required property int index

                            Layout.fillWidth: true
                            implicitHeight: 34

                            Rectangle {
                                anchors.centerIn: parent
                                width: 30
                                height: 30
                                radius: Appearance.rounding.full
                                color: index === 0
                                    ? Appearance.colors.colPrimary
                                    : ColorUtils.transparentize(Appearance.colors.colLayer2)

                                    StyledText {
                                    anchors.centerIn: parent
                                    text: Qt.locale().toString(model.date, "ddd")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: index === 0 ? Font.Bold : Font.Normal
                                    font.variableAxes: Appearance.font.variableAxes.rounded
                                    color: index === 0
                                        ? Appearance.colors.colOnPrimary
                                        : (weekChoice.selected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colSubtext)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
