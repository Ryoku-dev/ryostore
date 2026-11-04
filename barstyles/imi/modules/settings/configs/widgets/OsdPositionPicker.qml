import QtQuick
import QtQuick.Layouts
import "../../../common"
import "../../../common/widgets"
import "../../../../services"

GridLayout {
    id: root

    readonly property var validPositions: ["left", "right"]
    readonly property string configuredPosition: Config.options.osd.position ?? "right"
    readonly property string selectedPosition: validPositions.includes(configuredPosition) ? configuredPosition : "right"

    columns: width >= Appearance.font.pixelSize.hugeass * 21 ? 2 : 1
    columnSpacing: Appearance.font.pixelSize.small
    rowSpacing: Appearance.font.pixelSize.small
    Layout.fillWidth: true

    Repeater {
        model: [
            {
                "label": Translation.tr("Left"),
                "subtitle": Translation.tr("Docked on left screen edge"),
                "icon": "align_horizontal_left",
                "value": "left"
            },
            {
                "label": Translation.tr("Right"),
                "subtitle": Translation.tr("Docked on right screen edge"),
                "icon": "align_horizontal_right",
                "value": "right"
            }
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
            Accessible.description: Translation.tr("Select OSD position: %1").arg(positionChoice.modelData.label)
            Accessible.checked: positionChoice.selected
            onClicked: {
                Config.options.osd.position = positionChoice.modelData.value;
                GlobalStates.osdVolumeOpen = true;
                GlobalStates.osdInteraction();
            }

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
                            text: positionChoice.modelData.subtitle
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
