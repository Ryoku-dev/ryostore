import QtQuick
import QtQuick.Controls

Button {
    id: root
    hoverEnabled: true
    property bool toggled: false
    property string buttonText: ""
    property bool bounce: true
    property real baseWidth: 100
    property real baseHeight: 48
    property color colBackground: (typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colSecondaryContainer : "#222228"
    property color colBackgroundHover: (typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colSecondaryContainerHover : "#2d2d35"
    property color colBackgroundToggled: (typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colPrimary : "#ff5252"
    property color colBackgroundToggledHover: (typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colPrimaryHover : "#ff7777"
    property color color: root.toggled ? (root.hovered ? colBackgroundToggledHover : colBackgroundToggled) : (root.hovered ? colBackgroundHover : colBackground)

    property real leftRadius: 6
    property real rightRadius: 6

    background: Rectangle {
        topLeftRadius: root.leftRadius
        topRightRadius: root.rightRadius
        bottomLeftRadius: root.leftRadius
        bottomRightRadius: root.rightRadius
        color: root.color
        Behavior on color { ColorAnimation { duration: 120 } }
    }
}
