import QtQuick
import QtQuick.Shapes

// Jurai's mark, drawn: the Tree-Thunder, cut — 樹雷, the shell's own
// name as a glyph. Lightning branches for a crown, one trunk, roots
// for a stance, and a mast spike in the palette's second voice where
// the branches meet. Flat terminals, miter joins: a rune, cut, not
// sketched. Picked by the captain 2026-10-21 (Tree-Thunder from the
// second board, Rune-Cut temper from the third), retiring the
// pill-and-thread (Akusen's drawing, honoured in the lineage).
// Ryo-Ohki is the ship's mascot; this is her signature.
//
// Geometry lives in a 100-box, in units of the mark's height. A
// stroke cannot carry the old mark's gradient, so the tones step:
// crown in the light tone, trunk in the base, roots in the deep one
// — the same light-over-deep law, told in three voices. All tones
// come from `base` (and Theme.secondary for the spike), so the mark
// retints with the palette. `assets/icons/mark.svg` is the same
// sign as a line icon.
Item {
    id: root

    property color base: Theme.primary
    property color accent: Theme.secondary

    readonly property real unit: height
    readonly property real u: unit / 100

    implicitHeight: 64
    implicitWidth: unit

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // The crown — both limbs, in the light tone.
        ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.gradientTop(root.base)
            strokeWidth: 7 * root.u
            capStyle: ShapePath.SquareCap
            joinStyle: ShapePath.MiterJoin

            PathMove { x: 18 * root.u; y: 8 * root.u }
            PathLine { x: 36 * root.u; y: 20 * root.u }
            PathLine { x: 31 * root.u; y: 33 * root.u }
            PathLine { x: 50 * root.u; y: 46 * root.u }
            PathMove { x: 82 * root.u; y: 8 * root.u }
            PathLine { x: 64 * root.u; y: 20 * root.u }
            PathLine { x: 69 * root.u; y: 33 * root.u }
            PathLine { x: 50 * root.u; y: 46 * root.u }
        }

        // The trunk — the base tone, crown to root.
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.base
            strokeWidth: 7 * root.u
            capStyle: ShapePath.SquareCap
            joinStyle: ShapePath.MiterJoin

            PathMove { x: 50 * root.u; y: 46 * root.u }
            PathLine { x: 50 * root.u; y: 78 * root.u }
        }

        // The roots — the deep tone, her stance.
        ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.gradientBottom(root.base)
            strokeWidth: 7 * root.u
            capStyle: ShapePath.SquareCap
            joinStyle: ShapePath.MiterJoin

            PathMove { x: 50 * root.u; y: 64 * root.u }
            PathLine { x: 35 * root.u; y: 76 * root.u }
            PathLine { x: 38 * root.u; y: 86 * root.u }
            PathMove { x: 50 * root.u; y: 64 * root.u }
            PathLine { x: 65 * root.u; y: 76 * root.u }
            PathLine { x: 62 * root.u; y: 86 * root.u }
        }

        // The mast spike — 雷 seated at the junction, second voice.
        ShapePath {
            fillColor: root.accent
            strokeColor: "transparent"

            PathMove { x: 46 * root.u; y: 46 * root.u }
            PathLine { x: 50 * root.u; y: 3 * root.u }
            PathLine { x: 54 * root.u; y: 46 * root.u }
        }
    }
}
