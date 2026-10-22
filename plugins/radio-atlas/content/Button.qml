import QtQuick

// Port shim for the Omarchy shell's icon button. Radio Atlas' panel declares
// (24 of) these with: iconText, tooltipText, active, focusable, foreground,
// accent, enabled, hot and per-corner radii. Material Symbols Outlined stands
// in for the Font Awesome codepoints the original styles used.
Rectangle {
    id: root

    // Metrics: the panel derives layout sizes from implicitWidth/Height
    // (playerIconMetrics), so both must be real values.
    implicitWidth: icon.implicitWidth + horizontalPadding * 2
    implicitHeight: iconPixelSize + verticalPadding * 2

    property real iconPixelSize: 14
    readonly property int labelPad: 6
    readonly property int spaceV: 6
    readonly property bool _plain: background === "transparent"

    property string iconText: ""
    property string text: ""
    property int fontSize: 0
    property bool bold: false
    property string tooltipText: ""
    property bool active: false
    property bool focusable: false
    property bool selected: false
    property bool leftAlign: false
    property string background: "transparent"
    property real horizontalPadding: 0
    property real verticalPadding: 0
    property color foreground: "#ffffff"
    property color accent: "#ffffff"
    property real accentColor: 0 // unused in the original too

    readonly property bool hot: hoverHandler.hovered
    color: !_plain ? background
        : enabled && (root.hot || (focusable && focus)) ? Qt.rgba(foreground.r, foreground.g, foreground.b, 0.12)
        : (root.active ? Qt.rgba(accent.r, accent.g, accent.b, 0.16) : "transparent")
    border.width: 0

    signal clicked()

    function _material(text) {
        var map = {
            "\uf005": "\uE838", // star
            "\uf006": "\uE838", // star outline (approximated)
            "\uf00d": "\uE5CD", // close
            "\uf026": "\uE55F", // volume off
            "\uf028": "\uE1D8", // volume up
            "\uf048": "\uE045", // skip previous
            "\uf04b": "\uE037", // play
            "\uf04c": "\uE034", // pause
            "\uf04d": "\uE047", // stop
            "\uf051": "\uE044", // skip next
            "\uf067": "\uE8FF", // zoom in
            "\uf068": "\uE900", // zoom out
            "\uf074": "\uE55D", // shuffle/random
            "\uf0a1": "\uE1B8"  // audio output
        }
        return map[text] || text
    }

    Text {
        id: icon
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: root.leftAlign ? parent.left : undefined
        anchors.leftMargin: root.leftAlign ? root.labelPad : 0
        anchors.horizontalCenter: root.leftAlign ? undefined : parent.horizontalCenter
        text: root.iconText === "" ? root.text : root._material(root.iconText)
        font.family: root.iconText === "" ? "Space Grotesk" : "Material Symbols Outlined"
        font.bold: root.bold
        font.pixelSize: root.fontSize > 0 ? root.fontSize
            : (root.iconText === "" ? root.iconPixelSize + 2 : root.iconPixelSize)
        font.weight: root.active ? Font.DemiBold : Font.Normal
        color: root.enabled ? (root.hot ? root.accent : root.active ? root.accent : root.foreground)
                            : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.35)
        renderType: Text.NativeRendering
    }

    HoverHandler { id: hoverHandler }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        enabled: root.enabled
        hoverEnabled: true
        onClicked: root.clicked()
    }

    Keys.onReturnPressed: if (focusable && focus) root.clicked()
}
