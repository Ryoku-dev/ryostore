import "../../common"
import "../../common/widgets"
import "../clock/components"
import QtQuick
import QtQuick.Layouts

/** Label beside a control in a condition or action form. */
StyledText {
    font.pixelSize: ClockStyle.textNormal
    font.weight: Font.Medium
    color: ClockStyle.colOnSurface
}
