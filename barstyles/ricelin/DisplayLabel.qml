import QtQuick
import "Singletons"

/**
 * Single-line value label for the display picker. Splits a "WIDTH×HEIGHT" string on
 * the multiplication sign and lays it out as digits · separator · digits, all in the
 * shell font with tabular figures so the numbers never jump to a fallback face. The
 * separator is rendered smaller and dimmer in its own Text. Labels without a "×"
 * (refresh rates) render as one plain run.
 */
Row {
    id: lbl

    property real s: 1
    property string text: ""
    property color color: Theme.cream
    property int weight: Font.DemiBold

    readonly property int xSplit: lbl.text.indexOf("×")
    spacing: 0

    Text {
        text: lbl.xSplit >= 0 ? lbl.text.substring(0, lbl.xSplit) : lbl.text
        color: lbl.color
        font.family: Theme.font
        font.pixelSize: 10.5 * lbl.s
        font.weight: lbl.weight
        font.features: { "tnum": 1 }
    }

    Text {
        visible: lbl.xSplit >= 0
        leftPadding: 2 * lbl.s
        rightPadding: 2 * lbl.s
        text: "×"
        color: Qt.alpha(lbl.color, 0.55)
        font.family: Theme.font
        font.pixelSize: 9 * lbl.s
        font.weight: Font.Medium
    }

    Text {
        visible: lbl.xSplit >= 0
        text: lbl.xSplit >= 0 ? lbl.text.substring(lbl.xSplit + 1) : ""
        color: lbl.color
        font.family: Theme.font
        font.pixelSize: 10.5 * lbl.s
        font.weight: lbl.weight
        font.features: { "tnum": 1 }
    }
}
