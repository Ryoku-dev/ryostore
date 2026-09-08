import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Button {
    id: root
    property string materialIcon: ""
    property string nerdIcon: ""
    property string mainText: ""
    property real iconPixelSize: 18
    property int textPixelSize: 13
    property bool toggled: false
    property real buttonRadius: 8

    property color colText: (typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colOnSecondaryContainer : "#e6e1e1"
    property color colBackground: (typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colSecondaryContainer : "#222228"
    property color colBackgroundHover: (typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colSecondaryContainerHover : "#2d2d35"
    property color colBackgroundToggled: (typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colPrimary : "#ff5252"
    property color colBackgroundToggledHover: (typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colPrimaryHover : "#ff7777"
    property color colRipple: (typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colPrimaryContainerActive : "#3d3d45"
    property color colRippleToggled: colRipple

    readonly property color activeBg: toggled ? (hovered ? colBackgroundToggledHover : colBackgroundToggled) : (hovered ? colBackgroundHover : colBackground)

    hoverEnabled: true
    implicitHeight: 38
    implicitWidth: contentRow.implicitWidth + 24

    background: Rectangle {
        radius: root.buttonRadius
        color: root.down ? (root.toggled ? root.colRippleToggled : root.colRipple) : root.activeBg
        border.width: 1
        border.color: root.hovered ? ((typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colPrimary : "#ff5252") : Qt.rgba(1, 1, 1, 0.08)
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    contentItem: RowLayout {
        id: contentRow
        spacing: 8
        anchors.centerIn: parent

        MaterialSymbol {
            visible: root.materialIcon !== ""
            text: root.materialIcon
            iconSize: root.iconPixelSize
            color: root.toggled ? ((typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colOnPrimary : "#ffffff") : root.colText
        }

        StyledText {
            visible: root.mainText !== ""
            text: root.mainText
            font.pixelSize: root.textPixelSize
            font.weight: Font.DemiBold
            color: root.toggled ? ((typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colOnPrimary : "#ffffff") : root.colText
        }
    }
}
