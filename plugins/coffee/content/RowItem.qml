pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.PluginKit.Singletons

// One key/value row in the Coffee panel and desktop card: a mono uppercase key
// on the left, its value on the right. The row hides itself when it has no
// value, so an absent field leaves no empty line. Colour comes from the kit
// Theme; nothing is hardcoded.
Item {
    id: row

    property real s: 1
    property string label: ""
    property string value: ""
    property real keyWidth: 64

    width: parent ? parent.width : 0
    visible: value.length > 0
    height: visible ? Math.max(17 * s, valueText.implicitHeight) : 0

    Text {
        id: keyText
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: row.keyWidth * row.s
        text: row.label
        color: Theme.faint
        font.family: Theme.mono
        font.pixelSize: 9 * row.s
        font.letterSpacing: 1.2 * row.s
        font.capitalization: Font.AllUppercase
        elide: Text.ElideRight
    }

    Text {
        id: valueText
        anchors.left: keyText.right
        anchors.leftMargin: 6 * row.s
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: row.value
        color: Theme.cream
        font.family: Theme.mono
        font.pixelSize: 10.5 * row.s
        elide: Text.ElideMiddle
        horizontalAlignment: Text.AlignRight
    }
}
