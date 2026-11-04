import QtQuick
import "../../clock/components"

/** The number a tile is about: tall condensed digits (ClockStyle.axesDigitsBold). */
TileText {
    font.family: ClockStyle.fontMain
    font.variableAxes: ClockStyle.axesDigitsBold
    elide: Text.ElideRight
}
