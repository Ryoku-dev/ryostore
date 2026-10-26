pragma Singleton
import QtQuick
import shell.services as Native

QtObject {
    readonly property color bg: Native.Theme.surface
    readonly property color text: Native.Theme.onSurface
    readonly property color textDim: Native.Theme.onSurfaceVariant
    readonly property color textFaint: Native.Theme.outline
    readonly property color accent: Native.Theme.primary
    readonly property color accent2: Native.Theme.secondary
    readonly property color danger: Native.Theme.error
    readonly property string iconFont: "JetBrainsMono Nerd Font"
    readonly property int radius: 8
    readonly property int animMed: 180
}
