pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../../common"
import "../../../common/widgets"
import "../../../../services"

GridLayout {
    id: root

    readonly property var validPositions: ["top_left", "top_right", "bottom_left", "bottom_right"]
    readonly property string configuredPosition: Config.options.notifications.position ?? "top_right"
    readonly property string selectedPosition: validPositions.includes(configuredPosition) ? configuredPosition : "top_right"

    columns: width >= Appearance.font.pixelSize.hugeass * 21 ? 2 : 1
    columnSpacing: Appearance.font.pixelSize.small
    rowSpacing: Appearance.font.pixelSize.small

    Repeater {
        model: [
            { "label": Translation.tr("Top left"), "icon": "north_west", "value": "top_left" },
            { "label": Translation.tr("Top right"), "icon": "north_east", "value": "top_right" },
            { "label": Translation.tr("Bottom left"), "icon": "south_west", "value": "bottom_left" },
            { "label": Translation.tr("Bottom right"), "icon": "south_east", "value": "bottom_right" }
        ]

        delegate: RippleButton {
            id: positionChoice

            required property var modelData
            required property int index

            readonly property bool selected: root.selectedPosition === modelData.value

            Layout.fillWidth: true
            Layout.minimumWidth: root.columns === 2 ? Appearance.font.pixelSize.hugeass * 10 : 0
            implicitHeight: Appearance.font.pixelSize.hugeass * 4.8
            buttonRadius: Appearance.rounding.normal
            colBackground: selected ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
            colBackgroundHover: selected ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer2Hover
            colRipple: selected ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer2Active
            Accessible.name: positionChoice.modelData.label
            Accessible.description: Translation.tr("Select notification position: %1").arg(positionChoice.modelData.label)
            Accessible.checked: positionChoice.selected
            onClicked: Config.options.notifications.position = modelData.value

            contentItem: Item {
                implicitWidth: positionContent.implicitWidth
                implicitHeight: positionContent.implicitHeight

                RowLayout {
                    id: positionContent
                    anchors.centerIn: parent
                    spacing: Appearance.font.pixelSize.small

                    MaterialShapeWrappedMaterialSymbol {
                        Layout.alignment: Qt.AlignVCenter
                        iconSize: Appearance.font.pixelSize.huge
                        padding: Appearance.font.pixelSize.smallest
                        text: positionChoice.modelData.icon
                        shape: positionChoice.selected ? MaterialShape.Shape.Cookie4Sided : MaterialShape.Shape.Circle
                        color: positionChoice.selected ? Appearance.colors.colPrimary : Appearance.colors.colLayer3
                        colSymbol: positionChoice.selected ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer3
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: Appearance.font.pixelSize.smallest

                        StyledText {
                            Layout.fillWidth: true
                            text: positionChoice.modelData.label
                            font.pixelSize: Appearance.font.pixelSize.huge
                            font.weight: Font.DemiBold
                            font.variableAxes: Appearance.font.variableAxes.titleRounded
                            color: positionChoice.selected
                                ? Appearance.colors.colOnPrimaryContainer
                                : Appearance.colors.colOnLayer2
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: positionChoice.selected
                                ? Translation.tr("Current position")
                                : Translation.tr("Choose this corner")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            color: positionChoice.selected
                                ? Appearance.colors.colOnPrimaryContainer
                                : Appearance.colors.colSubtext
                        }
                    }

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignVCenter
                        text: positionChoice.selected ? "check_circle" : "radio_button_unchecked"
                        iconSize: Appearance.font.pixelSize.larger
                        fill: positionChoice.selected ? 1 : 0
                        color: positionChoice.selected
                            ? Appearance.colors.colOnPrimaryContainer
                            : Appearance.colors.colSubtext
                    }
                }
            }
        }
    }
}
