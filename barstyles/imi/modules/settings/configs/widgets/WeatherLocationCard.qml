pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../../common"
import "../../../common/widgets"
import "../../../../services"

Rectangle {
    id: root

    readonly property bool automaticLocation: Config.options.bar.weather.enableGPS
    readonly property string configuredCity: String(Config.options.bar.weather.city || "").trim()
    readonly property string activeCity: {
        if (!root.automaticLocation)
            return root.configuredCity.length > 0 ? root.configuredCity : Translation.tr("City not set");

        if (Weather.location && Weather.location.valid && Weather.location.city)
            return String(Weather.location.city);

        const weatherCity = Weather.data && Weather.data.city ? String(Weather.data.city) : "";
        if (weatherCity.length > 0 && weatherCity !== "City")
            return weatherCity;

        return Translation.tr("Finding your location");
    }
    readonly property string currentTemperature: {
        const value = Weather.data && Weather.data.temp ? String(Weather.data.temp).trim() : "";
        return value.length > 0 ? value : Translation.tr("No reading");
    }

    Layout.fillWidth: true
    implicitHeight: cardLayout.implicitHeight + 32
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer1

    ColumnLayout {
        id: cardLayout

        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            MaterialShapeWrappedMaterialSymbol {
                text: root.automaticLocation ? "my_location" : "location_city"
                shape: root.automaticLocation ? MaterialShape.Shape.Circle : MaterialShape.Shape.Cookie4Sided
                iconSize: Appearance.font.pixelSize.large
                padding: 8
                color: Appearance.colors.colPrimaryContainer
                colSymbol: Appearance.colors.colOnPrimaryContainer
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Weather location")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.automaticLocation
                        ? Translation.tr("Automatic location · %1").arg(root.activeCity)
                        : Translation.tr("Manual city · %1").arg(root.activeCity)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                implicitWidth: temperatureChipContent.implicitWidth + Appearance.font.pixelSize.small
                implicitHeight: temperatureChipContent.implicitHeight + Appearance.font.pixelSize.smallest
                radius: Appearance.rounding.full
                color: Appearance.colors.colPrimaryContainer
                Accessible.name: Translation.tr("Current temperature: %1").arg(root.currentTemperature)

                RowLayout {
                    id: temperatureChipContent
                    anchors.centerIn: parent
                    spacing: Appearance.font.pixelSize.smallest

                    MaterialSymbol {
                        text: "thermostat"
                        iconSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnPrimaryContainer
                    }

                    StyledText {
                        text: root.currentTemperature
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                }
            }
        }

        ConfigSwitch {
            Layout.fillWidth: true
            buttonIcon: "my_location"
            text: Translation.tr("Follow my live location")
            checked: root.automaticLocation
            forceUniformRadius: true
            normalColor: Appearance.colors.colLayer3
            highlightColor: Appearance.colors.colSecondaryContainer
            onCheckedChanged: Config.options.bar.weather.enableGPS = checked
        }

        MaterialTextArea {
            Layout.fillWidth: true
            visible: !root.automaticLocation
            placeholderText: Translation.tr("City name")
            text: Config.options.bar.weather.city
            wrapMode: TextEdit.Wrap
            Accessible.name: Translation.tr("City name")
            Accessible.description: Translation.tr("Enter the city used for manual weather location")
            onTextChanged: Config.options.bar.weather.city = text
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledText {
                text: Translation.tr("How should temperatures be shown?")
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.DemiBold
                color: Appearance.colors.colSubtext
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width >= 360 ? 2 : 1
                columnSpacing: 8
                rowSpacing: 8

                RippleButton {
                    id: celsiusButton

                    readonly property bool selected: !Config.options.bar.weather.useUSCS

                    Layout.fillWidth: true
                    implicitHeight: Appearance.font.pixelSize.hugeass * 2
                    buttonRadius: Appearance.rounding.full
                    colBackground: selected ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
                    colBackgroundHover: selected ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer2Hover
                    colRipple: selected ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer2Active
                    Accessible.name: Translation.tr("Celsius")
                    Accessible.description: Translation.tr("Use Celsius temperature units")
                    Accessible.checked: selected
                    onClicked: Config.options.bar.weather.useUSCS = false

                    contentItem: Item {
                        implicitWidth: celsiusContent.implicitWidth
                        implicitHeight: celsiusContent.implicitHeight

                        RowLayout {
                            id: celsiusContent
                            anchors.centerIn: parent
                            spacing: Appearance.font.pixelSize.smallest

                            MaterialSymbol {
                                text: "device_thermostat"
                                iconSize: Appearance.font.pixelSize.normal
                                fill: celsiusButton.selected ? 1 : 0
                                color: celsiusButton.selected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                            }

                            StyledText {
                                text: Translation.tr("Celsius · °C")
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.DemiBold
                                color: celsiusButton.selected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                            }
                        }
                    }
                }

                RippleButton {
                    id: fahrenheitButton

                    readonly property bool selected: Config.options.bar.weather.useUSCS

                    Layout.fillWidth: true
                    implicitHeight: Appearance.font.pixelSize.hugeass * 2
                    buttonRadius: Appearance.rounding.full
                    colBackground: selected ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
                    colBackgroundHover: selected ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer2Hover
                    colRipple: selected ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer2Active
                    Accessible.name: Translation.tr("Fahrenheit")
                    Accessible.description: Translation.tr("Use Fahrenheit temperature units")
                    Accessible.checked: selected
                    onClicked: Config.options.bar.weather.useUSCS = true

                    contentItem: Item {
                        implicitWidth: fahrenheitContent.implicitWidth
                        implicitHeight: fahrenheitContent.implicitHeight

                        RowLayout {
                            id: fahrenheitContent
                            anchors.centerIn: parent
                            spacing: Appearance.font.pixelSize.smallest

                            MaterialSymbol {
                                text: "device_thermostat"
                                iconSize: Appearance.font.pixelSize.normal
                                fill: fahrenheitButton.selected ? 1 : 0
                                color: fahrenheitButton.selected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                            }

                            StyledText {
                                text: Translation.tr("Fahrenheit · °F")
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.DemiBold
                                color: fahrenheitButton.selected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                            }
                        }
                    }
                }
            }
        }
    }
}
