pragma Singleton

import QtQuick

// Fūin's colours: Jurai's shipped palette ("Jurai", config/palettes/default.json
// in the shell), carried as constants. In the shell these four roles come from
// a valence source and everything else is derived from them in HSL; the theme
// keeps the derivations and fixes the four roles, so the face is the shell's
// face in the shell's own colours on any machine.
//
// The three state roles never come from a palette: they are a semantic code.
// Only `alert` reaches the lock face (a failed password), in its dark variant.
QtObject {
    id: root

    readonly property color background: "#12160F"
    readonly property color text: "#EAF1E6"
    readonly property color primary: "#B9DE6B"
    readonly property color secondary: "#3FBFA0"

    readonly property color alert: "#FF6B5D"

    readonly property bool isDark: luminance(background) < 0.5

    readonly property color surface: lift(background, 0.045)
    readonly property color elevated: lift(background, 0.045)
    readonly property color apsara: lift(background, 0.075)

    readonly property color textMuted: Qt.alpha(text, 0.56)
    readonly property color textFaint: Qt.alpha(text, 0.38)
    readonly property color border: Qt.alpha(text, isDark ? 0.09 : 0.14)

    // The outline family: line, node and rim at three lightnesses of the
    // background's own hue (borrowing the primary's when it has none).
    readonly property real structuralHue: hueOf(background, primary)
    readonly property real structuralSaturation: saturationOf(background, primary)

    readonly property color line: structural(isDark ? 0.32 : 0.72)
    readonly property color node: structural(isDark ? 0.43 : 0.62)
    readonly property color rim: structural(isDark ? 0.55 : 0.50)

    function hueOf(bg, accent) {
        return bg.hslSaturation > 0.05 && bg.hslHue >= 0 ? bg.hslHue : Math.max(0, accent.hslHue);
    }

    function saturationOf(bg, accent) {
        return Math.max(Math.min(bg.hslSaturation + 0.04, 0.40),
                        Math.min(accent.hslSaturation * 0.33, 0.28));
    }

    function structuralWith(bg, accent, lightness) {
        return Qt.hsla(root.hueOf(bg, accent), root.saturationOf(bg, accent), lightness, 1);
    }

    function structural(lightness) {
        return root.structuralWith(root.background, root.primary, lightness);
    }

    // The gradient simulates light: one source, from above — the top lighter,
    // the bottom darker and more saturated, same hue throughout.
    function gradientTop(base) {
        return Qt.hsla(Math.max(0, base.hslHue),
                       Math.min(1, base.hslSaturation + 0.14),
                       Math.min(1, base.hslLightness + 0.16),
                       base.a);
    }

    function gradientBottom(base) {
        return Qt.hsla(Math.max(0, base.hslHue),
                       Math.max(0, base.hslSaturation - 0.15),
                       Math.max(0, base.hslLightness - 0.15),
                       base.a);
    }

    function luminance(colour) {
        return 0.2126 * colour.r + 0.7152 * colour.g + 0.0722 * colour.b;
    }

    // Moves a colour away from the background's side: lighter on a dark
    // valence, darker on a light one, keeping hue and saturation.
    function lift(colour, amount) {
        const step = root.isDark ? amount : -amount;
        return Qt.hsla(Math.max(0, colour.hslHue),
                       colour.hslSaturation,
                       Math.max(0, Math.min(1, colour.hslLightness + step)),
                       colour.a);
    }
}
