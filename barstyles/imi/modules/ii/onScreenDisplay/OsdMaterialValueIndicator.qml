import "../../../services"
import "../../common"
import "../../common/widgets"
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

Item {
    id: root
    required property real value
    required property string icon
    property var shape
    property real maxLimit: 1.0
    property alias from: valueProgressBar.from
    property alias to: valueProgressBar.to
    property alias minimalFrom: minimalValueProgressBar.from
    property alias minimalTo: minimalValueProgressBar.to

    signal moved(real newValue)

    property bool rotateShape: Config.options.osd.material.rotateShape
    property bool shapedValues: Config.options.osd.material.shapedValues
    property bool minimal: Config.options.osd.material.minimal
    property bool circledShapes: Config.options.osd.material.circledShapes

    property real valueIndicatorVerticalPadding: 5
    property real valueIndicatorLeftPadding: 10
    property real valueIndicatorRightPadding: 10

    implicitWidth: Appearance.sizes.osdWidth + 2 * Appearance.sizes.elevationMargin + (root.minimal ? -40 : 40)
    implicitHeight: valueIndicator.implicitHeight + 2 * Appearance.sizes.elevationMargin + (root.minimal ? -18 : -10)

    StyledRectangularShadow {
        target: valueIndicator
    }

    Rectangle {
        id: valueIndicator
        anchors {
            fill: parent
            margins: Appearance.sizes.elevationMargin
        }
        radius: Appearance.rounding.full
        color: Config.options.appearance.transparency.popups ? Appearance.colors.colLayer0 : Appearance.m3colors.m3surfaceContainer

        implicitWidth: root.minimal ? 0 : valueRow.implicitWidth + 2 * 6
        implicitHeight: root.minimal ? minimalValueProgressBar.implicitHeight + 2 * Appearance.sizes.elevationMargin + 2 : valueRow.implicitHeight + 2 * 6

        RowLayout {
            id: valueRow
            anchors {
                fill: parent
                margins: 2
            }
            spacing: 10
            visible: !root.minimal

            Item {
                implicitWidth: 30
                implicitHeight: 30
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: valueIndicatorLeftPadding
                Layout.topMargin: valueIndicatorVerticalPadding
                Layout.bottomMargin: valueIndicatorVerticalPadding
                visible: root.shapedValues

                MaterialShapeWrappedMaterialSymbol {
                    id: symbolWrapper
                    rotation: root.rotateShape && !root.circledShapes ? root.value * 360 : 0
                    anchors.centerIn: parent
                    iconSize: Appearance.font.pixelSize.huge
                    shape: root.circledShapes ? MaterialShape.Shape.Circle : root.shape
                    text: root.icon

                    Behavior on rotation {
                        NumberAnimation {
                            duration: 350
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.5
                        }
                    }

                    color: root.value > root.maxLimit ? Appearance.colors.colErrorContainerActive : Appearance.colors.colSecondaryContainer
                    colSymbol: root.value > root.maxLimit ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnSecondaryContainer

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                    Behavior on colSymbol {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                }
            }

            Item {
                implicitWidth: 25
                implicitHeight: 30
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: valueIndicatorLeftPadding
                Layout.topMargin: valueIndicatorVerticalPadding
                Layout.bottomMargin: valueIndicatorVerticalPadding
                visible: !root.shapedValues

                MaterialSymbol {
                    id: symbol
                    anchors.centerIn: parent
                    color: root.value > root.maxLimit ? Appearance.colors.colErrorContainerActive : Appearance.colors.colPrimary
                    iconSize: Appearance.font.pixelSize.huge + 2
                    text: root.icon
                }
            }

            QuickSlider {
                id: valueProgressBar
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignVCenter
                configuration: StyledSlider.Configuration.M
                stopIndicatorValues: []
                materialSymbol: ""
                value: root.value
                onMoved: root.moved(valueProgressBar.value)
            }

            Item {
                implicitWidth: 25
                implicitHeight: 30
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 0
                Layout.rightMargin: valueIndicatorLeftPadding
                Layout.topMargin: valueIndicatorVerticalPadding
                Layout.bottomMargin: valueIndicatorVerticalPadding
                visible: !root.shapedValues

                StyledText {
                    id: value
                    anchors.centerIn: parent
                    color: root.value > root.maxLimit ? Appearance.colors.colErrorContainerActive : Appearance.colors.colPrimary
                    text: Math.round(root.value * 100)

                    font {
                        family: Appearance.font.family.numbers
                        pixelSize: Appearance.font.pixelSize.small
                        features: { "tnum": 1 }
                        letterSpacing: 0.2
                    }
                }
            }

            Item {
                implicitWidth: 30
                implicitHeight: 30
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 0
                Layout.rightMargin: valueIndicatorRightPadding
                Layout.topMargin: valueIndicatorVerticalPadding
                Layout.bottomMargin: valueIndicatorVerticalPadding
                visible: root.shapedValues

                MaterialShapeWrappedMaterialSymbol {
                    id: valueWrapper
                    anchors.centerIn: parent
                    rotation: root.rotateShape && !root.circledShapes ? root.value * 360 : 0
                    iconSize: Appearance.font.pixelSize.huge
                    shape: root.circledShapes ? MaterialShape.Shape.Circle : root.shape
                    text: Math.round(root.value * 100)
                    font {
                        family: Appearance.font.family.numbers
                        pixelSize: Appearance.font.pixelSize.small
                        features: { "tnum": 1 }
                        letterSpacing: 0.2
                    }

                    Behavior on rotation {
                        NumberAnimation {
                            duration: 350
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.5
                        }
                    }

                    color: root.value > root.maxLimit ? Appearance.colors.colErrorContainerActive : Appearance.colors.colSecondaryContainer
                    colSymbol: root.value > root.maxLimit ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnSecondaryContainer

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                    Behavior on colSymbol {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                }
            }
        }

        QuickSlider {
            id: minimalValueProgressBar
            anchors {
                fill: parent
                margins: Appearance.sizes.elevationMargin
            }
            materialSymbol: root.icon
            trackRadius: Appearance.rounding.full
            handleHeight: 34
            configuration: StyledSlider.Configuration.M
            stopIndicatorValues: []
            visible: root.minimal
            value: root.value
            onMoved: root.moved(minimalValueProgressBar.value)
        }
    }

    component QuickSlider: StyledSlider {
        id: quickSlider
        property string materialSymbol

        highlightColor: root.value > root.maxLimit ? Appearance.colors.colErrorContainerActive : Appearance.colors.colPrimary
        handleColor: root.value > root.maxLimit ? Appearance.colors.colErrorContainerActive : Appearance.colors.colPrimary

        configuration: StyledSlider.Configuration.M
        stopIndicatorValues: []
        dividerValues: []

        MaterialSymbol {
            id: leftIcon
            visible: materialSymbol.length > 0
            anchors.verticalCenter: quickSlider.verticalCenter

            property bool nearLeft: quickSlider.visualPosition <= 0.20
            anchors.left: nearLeft ? quickSlider.handle.right : quickSlider.left
            anchors.leftMargin: nearLeft ? 6 : 4

            iconSize: Appearance.font.pixelSize.huge - 1
            color: root.value > root.maxLimit ? Appearance.colors.colOnErrorContainer : (nearLeft ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnPrimary)
            text: materialSymbol

            Behavior on anchors.leftMargin {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
        }

        StyledText {
            id: rightValue
            visible: root.minimal
            anchors.verticalCenter: quickSlider.verticalCenter
            property bool nearRight: quickSlider.visualPosition >= 0.78
            anchors.right: nearRight ? quickSlider.handle.right : quickSlider.right
            anchors.rightMargin: nearRight ? 10 : 8

            color: root.value > root.maxLimit ? Appearance.colors.colOnErrorContainer : (nearRight ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer)
            text: Math.round(root.value * 100)
            font {
                family: Appearance.font.family.numbers
                pixelSize: Appearance.font.pixelSize.smallie
                features: { "tnum": 1 }
                letterSpacing: 0.2
            }

            Behavior on anchors.rightMargin {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
        }
    }
}