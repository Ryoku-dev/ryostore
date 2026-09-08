import QtQuick

Text {
    id: root
    property real iconSize: (typeof Appearance !== "undefined" && Appearance && Appearance.font && Appearance.font.pixelSize) ? Appearance.font.pixelSize.normal : 16
    property real fill: 0

    renderType: Text.NativeRendering
    antialiasing: true
    smooth: true
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter

    font {
        hintingPreference: Font.PreferNoHinting
        family: "Material Symbols Rounded"
        pixelSize: root.iconSize
        weight: Font.Normal
        variableAxes: ({
            "FILL": parseFloat(root.fill >= 0.5 ? 1 : 0),
            "wght": 400,
            "opsz": Math.max(20, Math.min(48, root.iconSize))
        })
    }
}
