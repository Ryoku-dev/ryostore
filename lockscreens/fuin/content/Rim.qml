import QtQuick
import QtQuick.Shapes

// The lit border. One light source, from above, on every surface in the shell.
//
// It is a **shape on the edge**, not a border colour: it runs from the rim
// colour at the top to the line colour at mid-height, and stays there below. A
// `Rectangle` cannot do that — `border.color` is flat — and a gradient
// rectangle behind a translucent fill would show through the glass. So the rim
// is a ring: two rounded rectangles in one path with an odd-even fill, which
// leaves the inside untouched.
//
// It is never clipped. Any `clip: true` on a apsara eats it, which is exactly
// what made the outline vanish in the first window title.
Shape {
    id: root

    // Set by the surface it outlines.
    property real radius: 0
    property color topColour: Theme.rim
    property color bottomColour: Theme.line

    // The Night City cut: two corners of the outline are chamfered
    // (top-right, bottom-left) when this is above zero. The ring then
    // runs dim in the line colour, and the lit stretches — the top
    // edge and the two cuts, where the light from above lands — burn
    // in the light colour at the light's level.
    property real chamfer: 0
    property color lightColor: Theme.rim
    // Below zero: the legacy gradient answers. At or above: the
    // segments' alpha follows the level.
    property real lightLevel: -1
    readonly property real cut: Math.max(0, Math.min(root.chamfer,
                            Math.min(root.width, root.height) / 3))
    readonly property bool cutMode: root.cut > 0

    // A hairline is a critical dimension: rounded to the physical pixel or it
    // smears and disappears under fractional scaling.
    readonly property real thickness: Metrics.rim(Screen.devicePixelRatio)

    // The curve renderer antialiases the ring properly at this width; the
    // geometry renderer leaves it ragged on the caps.
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillRule: ShapePath.OddEvenFill
        strokeWidth: -1

        fillGradient: LinearGradient {
            x1: 0
            y1: 0
            x2: 0
            // The light reaches the line colour at mid-height and stays there:
            // the gradient pads below its last stop.
            y2: Math.max(1, root.height / 2)

            GradientStop { position: 0; color: root.cutMode ? "transparent" : root.topColour }
            GradientStop { position: 1; color: root.cutMode ? "transparent" : root.bottomColour }
        }

        PathRectangle {
            width: root.width
            height: root.height
            radius: root.radius
        }

        PathRectangle {
            x: root.thickness
            y: root.thickness
            width: Math.max(0, root.width - root.thickness * 2)
            height: Math.max(0, root.height - root.thickness * 2)
            // Concentric: the inner radius is the outer minus the inset, and
            // never below zero.
            radius: Metrics.innerRadius(root.radius, root.thickness)
        }
    }

    // The dim ring in cut mode: the chamfered silhouette, odd-even.
    ShapePath {
        fillRule: ShapePath.OddEvenFill
        strokeWidth: -1
        fillColor: root.cutMode ? root.bottomColour : "transparent"

        PathMove { x: 0; y: 0 }
        PathLine { x: root.width - root.cut; y: 0 }
        PathLine { x: root.width; y: root.cut }
        PathLine { x: root.width; y: root.height }
        PathLine { x: root.cut; y: root.height }
        PathLine { x: 0; y: root.height - root.cut }
        PathLine { x: 0; y: 0 }
        PathMove { x: root.thickness; y: root.thickness }
        PathLine { x: root.width - root.cut - root.thickness * 0.4; y: root.thickness }
        PathLine { x: root.width - root.thickness; y: root.cut + root.thickness * 0.4 }
        PathLine { x: root.width - root.thickness; y: root.height - root.thickness }
        PathLine { x: root.cut + root.thickness * 0.4; y: root.height - root.thickness }
        PathLine { x: root.thickness; y: root.height - root.cut - root.thickness * 0.4 }
        PathLine { x: root.thickness; y: root.thickness }
    }

    // The lit stretches: the top edge and the two cuts, stroked in
    // the light colour. Their alpha is the beam's level when one is
    // given; otherwise a steady burn at the rim colour's own alpha.
    ShapePath {
        strokeColor: root.cutMode ? Qt.rgba(root.lightColor.r, root.lightColor.g, root.lightColor.b,
                                            root.lightLevel >= 0 ? 0.15 + 0.85 * root.lightLevel : 0.85)
                                  : "transparent"
        strokeWidth: root.thickness
        fillColor: "transparent"
        capStyle: ShapePath.FlatCap

        PathMove { x: root.thickness / 2; y: root.thickness / 2 }
        PathLine { x: root.width - root.cut; y: root.thickness / 2 }
        PathLine { x: root.width - root.thickness / 2; y: root.cut }
        PathMove { x: root.cut; y: root.height - root.thickness / 2 }
        PathLine { x: root.thickness / 2; y: root.height - root.cut }
    }
}
