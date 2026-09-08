import QtQuick
import QtQuick.Controls

Button {
    id: root
    hoverEnabled: true
    property bool toggled: false
    property string buttonText: ""
    property real buttonRadius: (typeof Appearance !== "undefined" && Appearance && Appearance.rounding) ? Appearance.rounding.small : 6
    property real buttonRadiusPressed: buttonRadius

    property real topLeftRadius: buttonRadius
    property real topRightRadius: buttonRadius
    property real bottomLeftRadius: buttonRadius
    property real bottomRightRadius: buttonRadius

    property bool rippleEnabled: true
    property bool pointingHandCursor: true
    property var downAction: null
    property var releaseAction: null
    property var altAction: null
    property var middleClickAction: null
    property var backClickAction: null
    property var enteredAction: null
    property var exitedAction: null
    property var pressedAction: null
    property var positionChangedAction: null
    property var canceledAction: null
    property bool useDynamicRadius: false

    property color colBackground: (typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colSecondaryContainer : "#222228"
    property color colBackgroundHover: (typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colSecondaryContainerHover : "#2d2d35"
    property color colBackgroundToggled: (typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colPrimary : "#ff5252"
    property color colBackgroundToggledHover: (typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colPrimaryHover : "#ff7777"
    property color colRipple: (typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colPrimaryContainerActive : "#3d3d45"
    property color colRippleToggled: colRipple

    readonly property color activeBg: toggled ? (hovered ? colBackgroundToggledHover : colBackgroundToggled) : (hovered ? colBackgroundHover : colBackground)

    background: Rectangle {
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        color: root.down ? (root.toggled ? root.colRippleToggled : root.colRipple) : root.activeBg
        border.width: 1
        border.color: root.hovered ? ((typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colPrimary : "#ff5252") : Qt.rgba(1, 1, 1, 0.08)
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }
    }

    scale: root.down ? 0.96 : (root.hovered ? 1.02 : 1.0)
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
}
