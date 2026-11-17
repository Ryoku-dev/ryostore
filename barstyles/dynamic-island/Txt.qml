import QtQuick

Text {
    property real size: 13
    property int weight: Font.Medium
    font.family: Theme.font
    font.pixelSize: size
    font.weight: weight
    font.letterSpacing: size >= 20 ? -size * 0.022 : size >= 15 ? -0.2 : 0
    font.features: { "tnum": 1 }
    color: Theme.fg
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
    textFormat: Text.PlainText
    Behavior on color { ColorAnimation { duration: 200 } }
}
