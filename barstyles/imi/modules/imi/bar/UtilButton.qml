import QtQuick
import QtQuick.Layouts
import "../../common"
import "../../common/widgets"
import "../../common/models"
import "../../common/functions"

Item {
    id: root
    signal clicked(event: var)
    property alias iconText: symbol.text
    property bool isActive: false
    property bool forceHovered: false

    implicitWidth: 26
    implicitHeight: 26

    property bool hovered: mouseArea.containsMouse || forceHovered

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.full
        color: root.hovered ? Appearance.colors.colPrimary : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.8)

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }

        MaterialSymbol {
            id: symbol
            anchors.centerIn: parent
            iconSize: Appearance.font.pixelSize.large
            color: root.hovered ? Appearance.colors.colOnPrimary : Appearance.colors.colPrimary

            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: (e) => root.clicked(e)
    }
}
