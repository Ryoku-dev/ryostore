import QtQuick

Text {
    id: root
    property bool animateChange: false
    renderType: Text.QtRendering
    verticalAlignment: Text.AlignVCenter
    font.family: (typeof Appearance !== "undefined" && Appearance && Appearance.font && Appearance.font.family) ? Appearance.font.family.main : "Space Grotesk"
    font.pixelSize: (typeof Appearance !== "undefined" && Appearance && Appearance.font && Appearance.font.pixelSize) ? Appearance.font.pixelSize.normal : 14
    color: (typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colOnSurface : "#e6e1e1"
}
