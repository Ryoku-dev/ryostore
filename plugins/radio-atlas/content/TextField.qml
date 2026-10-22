import QtQuick
import QtQuick.Controls as QQC

// Port shim for the Omarchy shell's search TextField: a stock Controls field
// re-styled through the port's foreground/accent tokens. The local file wins
// the implicit directory import, so the panel's unqualified `TextField`
// resolves here.
QQC.TextField {
    id: root

    property color foreground: "#ffffff"
    property color accent: "#ffffff"

    placeholderTextColor: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.45)
    selectionColor: Qt.rgba(accent.r, accent.g, accent.b, 0.35)
    selectedTextColor: root.foreground
    color: foreground

    background: Rectangle {
        radius: height / 2
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
        border.width: root.activeFocus ? 1 : 0
        border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.55)
    }
}
