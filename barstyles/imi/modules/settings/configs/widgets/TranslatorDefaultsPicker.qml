pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../../common"
import "../../../common/widgets"
import "../../../../services"

GridLayout {
    id: root

    property var languageModel: []

    columns: (width > 0 ? width >= 520 : true) ? 3 : 1
    columnSpacing: 12
    rowSpacing: 10

    function modelIndexFor(value) {
        const index = root.languageModel.findIndex(item => item.value === value);
        return index >= 0 ? index : 0;
    }

    function swapLanguages() {
        const source = Config.options.language.translator.defaultSourceLanguage;
        const target = Config.options.language.translator.defaultTargetLanguage;
        Config.options.language.translator.defaultSourceLanguage = target;
        Config.options.language.translator.defaultTargetLanguage = source;
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.minimumWidth: root.columns === 3 ? 190 : 0
        implicitHeight: sourceLayout.implicitHeight + 28
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1

        ColumnLayout {
            id: sourceLayout

            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol {
                    text: "language"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colPrimary
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("From")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colSubtext
                    font.capitalization: Font.AllUppercase
                }
            }

            StyledComboBox {
                id: sourceSelector

                Layout.fillWidth: true
                Layout.preferredHeight: 44
                buttonIcon: "translate"
                textRole: "displayName"
                model: root.languageModel
                currentIndex: root.modelIndexFor(Config.options.language.translator.defaultSourceLanguage)
                onActivated: index => {
                    Config.options.language.translator.defaultSourceLanguage = model[index].value;
                }
            }
        }
    }

    RippleButton {
        Layout.alignment: Qt.AlignCenter
        implicitWidth: 48
        implicitHeight: 48
        buttonRadius: Appearance.rounding.full
        colBackground: Appearance.colors.colPrimary
        colBackgroundHover: Appearance.colors.colPrimaryHover
        colRipple: Appearance.colors.colPrimaryActive
        onClicked: root.swapLanguages()

        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            text: root.columns === 3 ? "swap_horiz" : "swap_vert"
            iconSize: Appearance.font.pixelSize.huge
            color: Appearance.colors.colOnPrimary
        }

        StyledToolTip {
            text: Translation.tr("Swap source and target languages")
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.minimumWidth: root.columns === 3 ? 190 : 0
        implicitHeight: targetLayout.implicitHeight + 28
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1

        ColumnLayout {
            id: targetLayout

            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol {
                    text: "glyphs"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colTertiary
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("To")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colSubtext
                    font.capitalization: Font.AllUppercase
                }
            }

            StyledComboBox {
                id: targetSelector

                Layout.fillWidth: true
                Layout.preferredHeight: 44
                buttonIcon: "translate"
                textRole: "displayName"
                model: root.languageModel
                currentIndex: root.modelIndexFor(Config.options.language.translator.defaultTargetLanguage)
                onActivated: index => {
                    Config.options.language.translator.defaultTargetLanguage = model[index].value;
                }
            }
        }
    }
}
