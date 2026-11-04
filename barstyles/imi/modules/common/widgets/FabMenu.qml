import QtQuick
import QtQuick.Layouts
import ".."
import "."

Item {
    id: root

    property bool expanded: false
    property string icon: "add"
    property real fabSize: 56
    property real miniFabSize: 40
    property real spacing: 16
    property color colBackground: Appearance.colors.colPrimaryContainer
    property color colBackgroundHover: Appearance.colors.colPrimaryContainerHover
    property color colRipple: Appearance.colors.colPrimaryContainerActive
    property color colOnBackground: Appearance.colors.colOnPrimaryContainer
    property color colMiniFabBackground: Appearance.colors.colSurfaceContainerHigh
    property color colMiniFabBackgroundHover: Appearance.colors.colSurfaceContainerHighest
    property color colMiniFabRipple: Appearance.colors.colSurfaceContainerHighestActive
    property color colOnMiniFab: Appearance.colors.colOnSurface
    property color colScrim: Qt.rgba(0, 0, 0, 0.3)
    property bool enableShadow: true
    property bool enableLabels: true

    signal miniFabClicked(int index)

    property var actions: []

    implicitWidth: fabSize
    implicitHeight: fabSize + (expanded ? (actions.length * (miniFabSize + spacing)) : 0)

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Appearance.animation.elementMove.duration
            easing.type: Appearance.animation.elementMove.type
            easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
        }
    }

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: root.colScrim
        opacity: root.expanded ? 1 : 0
        visible: opacity > 0
        radius: Appearance.rounding.normal

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Easing.OutQuad
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = false
        }
    }

    Column {
        id: miniFabsColumn
        anchors.bottom: mainFab.top
        anchors.bottomMargin: root.spacing
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: root.spacing
        layoutDirection: Qt.RightToLeft

        Repeater {
            model: root.actions

            Item {
                width: miniFabRow.implicitWidth
                height: miniFabRow.implicitHeight
                opacity: root.expanded ? 1 : 0
                scale: root.expanded ? 1 : 0.3
                transformOrigin: Item.Bottom

                property int itemIndex: index
                property real animDelay: index * 50

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.animation.elementMove.duration
                        easing.type: Appearance.animation.elementMove.type
                        easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Appearance.animation.elementMove.duration
                        easing.type: Appearance.animation.elementMove.type
                        easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                    }
                }

                Row {
                    id: miniFabRow
                    spacing: 12
                    layoutDirection: Qt.RightToLeft

                    Loader {
                        active: root.enableLabels && modelData.label
                        visible: active
                        anchors.verticalCenter: parent.verticalCenter

                        sourceComponent: Rectangle {
                            width: labelText.implicitWidth + 20
                            height: 32
                            radius: height / 2
                            color: Appearance.colors.colSurfaceContainerHighest

                            StyledText {
                                id: labelText
                                anchors.centerIn: parent
                                text: modelData.label || ""
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnSurface
                            }
                        }
                    }

                    Loader {
                        active: root.enableShadow
                        anchors.verticalCenter: parent.verticalCenter
                        sourceComponent: StyledRectangularShadow {
                            target: miniFabBtn
                            radius: miniFabBtn.buttonRadius
                        }
                    }

                    RippleButton {
                        id: miniFabBtn
                        width: root.miniFabSize
                        height: root.miniFabSize
                        buttonRadius: Appearance.rounding.full

                        colBackground: root.colMiniFabBackground
                        colBackgroundHover: root.colMiniFabBackgroundHover
                        colRipple: root.colMiniFabRipple

                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: modelData.icon || ""
                            iconSize: 20
                            color: root.colOnMiniFab
                        }

                        onClicked: root.miniFabClicked(index)
                    }
                }
            }
        }
    }

    Loader {
        active: root.enableShadow
        anchors.fill: mainFab
        sourceComponent: StyledRectangularShadow {
            target: mainFab
            radius: mainFab.buttonRadius
        }
    }

    RippleButton {
        id: mainFab
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.fabSize
        height: root.fabSize
        buttonRadius: Appearance.rounding.full

        colBackground: root.colBackground
        colBackgroundHover: root.colBackgroundHover
        colRipple: root.colRipple

        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            text: root.expanded ? "close" : root.icon
            iconSize: 24
            color: root.colOnBackground
            rotation: root.expanded ? 45 : 0

            Behavior on rotation {
                NumberAnimation {
                    duration: Appearance.animation.elementMove.duration
                    easing.type: Appearance.animation.elementMove.type
                    easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                }
            }
        }

        onClicked: root.expanded = !root.expanded
    }
}
