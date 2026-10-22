pragma Singleton
import QtQuick

// Design-token shim for the Radio Atlas port.
//
// The Omarchy original reads two shell singletons the Ryoku plugin contract
// does not expose to plugin content: `qs.Ui`'s Style (spacing + type scale) and
// `qs.Commons`'s Color (menu surface, accent, urgent). Ryoku's own tokens live
// on `Ryoku.PluginKit.Singletons.Theme`, which plugin content may import, so
// this shim re-exposes the same names RadioAtlas.qml already uses, resolved
// from that Theme singleton instead of a hardcoded tint.
//
// Every value derives from the live palette, so the globe and the player follow
// the active wallpaper theme exactly as the rest of the shell does.

QtObject {
    id: style

    // --- type scale -------------------------------------------------------
    // Theme.font is the shell's UI face; the original used the shell body and
    // heading faces for its labels, so the family carries over directly.
    readonly property string fontFamily: "Space Grotesk"

    // Base size the original scaled its spacing against. Ryoku's shell text
    // sits at 13px on the bar and 14-15px in panels; 13 keeps the globe's dense
    // labels legible inside the panel's width budget.
    readonly property int fontBaseSize: 13
    readonly property int fontBaseSizeSmall: fontBaseSize - 1

    // Omarchy's Style.font was an object of named pixel sizes (font.caption,
    // font.heading, ...), not a QFont - the panel reads the members directly.
    readonly property QtObject font: QtObject {
        readonly property int caption: fontBaseSize - 2
        readonly property int heading: fontBaseSize + 2
        readonly property int body: fontBaseSize
    }
    readonly property real spacingScaleWithFont: 1.0

    // Omarchy's Style.font exposed a small named set (caption/heading/body/...).
    // Radio Atlas reads two of them; both resolve to the shell body size so the
    // port's proportions are unchanged.
    readonly property int caption: fontBaseSize - 2
    readonly property int heading: fontBaseSize + 2
    readonly property int body: fontBaseSize

    // --- geometry ---------------------------------------------------------
    // Radio Atlas addressed spacing by name (md for edge insets, sm for tight
    // gaps, lg for pane separation). The values follow the shell's own rhythm.
    readonly property QtObject spacing: QtObject {
        readonly property int xs: 4
        readonly property int sm: 8
        readonly property int md: 12
        readonly property int lg: 16
        readonly property int xl: 24
        readonly property int panelPadding: 12
        readonly property int cardGap: 16
    }

    readonly property int cornerRadius: Theme.radius

    // space(n) is the original's scale helper: it multiplied a token by the
    // active density multiplier. The panel host supplies `s` on its root, so
    // this is a plain helper the QML calls with a scale factor.
    function space(value) {
        return Math.round(Number(value) * (rootDensity > 0 ? rootDensity : 1))
    }

    // Set once by the entry point that mounts this, from the host's `s`.
    property real rootDensity: 1

    // --- fills ------------------------------------------------------------
    // The original resolved these from the shell's selection/hover roles.
    // Ryoku exposes the accent family on Theme: selection is the accent, hover
    // is the accent lifted so it reads as an affordance over the card surface.
    function selectedFillFor(base) {
        return Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.9)
    }

    function hoverFillFor(base) {
        return Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
    }
}
