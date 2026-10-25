pragma Singleton

import QtQuick

// Two voices, declared as roles rather than by name so a machine without the
// intended faces degrades instead of breaking. The theme bundles both faces
// (content/fonts, SIL Open Font License), so the roles resolve to them; the
// theme.conf keys fontExpressive / fontTechnical can name others.
//
//   If the door measured it, technical — Orbitron.
//   If it came from a human, expressive — Spectral.
//
// Sizes are not here: they follow the density step and live in Metrics.step().
QtObject {
    id: root

    readonly property string expressive: Config.get("fonts.expressive", "Spectral")
    readonly property string expressiveFallback: "serif"

    readonly property string technical: Config.get("fonts.technical", "Orbitron")
    readonly property string technicalFallback: "sans-serif"

    readonly property int weightValue: Font.Medium      // 500 — primary values
    readonly property int weightLabel: Font.Medium      // 500 — titles and labels
    readonly property int weightSecondary: Font.Normal  // 400 — secondary values, names
    readonly property int weightTitle: Font.Bold        // 700 — titles beside expressive text

    // Labels are uppercase and tracked out.
    readonly property real labelTracking: 0.06          // em

    // Continuously changing figures must use tabular numerals, or their
    // width dances on every update.
    function tabular(font) {
        font.features = { "tnum": 1 };
        return font;
    }

    // Letter spacing is declared in em and in pixels by Qt.
    function tracking(pixelSize, em) {
        return pixelSize * em;
    }
}
