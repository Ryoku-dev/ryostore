import QtQuick
import shell.services as RyokuServices
import shell.barkit as Pill
import "../../.."
import "../../../services"
import "../../common"
import "../../common/widgets"
import "../../common/functions"

RippleButton {
    id: root
    property bool vertical: Config.options.bar.vertical
    property bool isMaterial: Config.options.bar.cornerStyle === 3
    property real buttonPadding: Appearance.spacing.space50

    visible: true

    implicitWidth: 32
    implicitHeight: 32

    buttonRadius: Appearance.rounding.full
    colBackground: isMaterial ? Appearance.colors.colPrimaryContainer : "transparent"
    colBackgroundHover: isMaterial ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer1Hover
    colRipple: isMaterial ? Appearance.colors.colLayer1Active : Appearance.colors.colLayer1Active
    colBackgroundToggled: Appearance.colors.colSecondaryContainer
    colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
    colRippleToggled: Appearance.colors.colSecondaryContainerActive
    toggled: false

    onPressed: {
        RyokuServices.ShellState.requestSurface("quick-settings", "", undefined);
    }

    Text {
        id: distroIcon
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -2
        text: "力"
        color: Appearance.colors.colOnPrimaryContainer
        renderType: Text.NativeRendering
        font.family: "Noto Sans CJK JP"
        font.pixelSize: root.isMaterial ? (root.vertical ? 18 : 16) : 15
        font.weight: Font.Bold
    }
}
