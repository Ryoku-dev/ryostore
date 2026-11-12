import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

// Liquid-glass surface.
// The compositor supplies the frosted blur of what's behind (Hyprland layerrule, see README).
// On top of that this draws, back to front:
//   ambient + contact shadow · optional coloured glow · body with a gentle vertical falloff ·
//   top gloss · inner "lensing" edge (light bending at the rim) · specular rim that is
//   brightest at the top-left and bottom-right corners, like Apple's Liquid Glass.
Item {
    id: root
    property real radius: 20
    property color tint: Theme.glassTint
    property bool rim: Config.s.glassRim && Theme.glass
    property bool sheen: Theme.glass
    property bool shadow: true
    property real shadowBlur: 30
    property real shadowY: 10
    property color glowColor: Theme.accent
    property real glowStrength: 0
    readonly property real r: Math.max(0, Math.min(radius, height / 2, width / 2))
    readonly property bool glassy: Theme.glass && tint.a < 0.999

    // where the two highlights sit (the corner directions of this shape)
    readonly property real cornerAngle: 180 - Math.atan2(Math.max(1, height), Math.max(1, width)) * 180 / Math.PI

    // ── shadows: drawn OUTSIDE the shape only ──
    // A RectangularShadow is a filled blurred rect, so left alone it stacks ~50%
    // black under the whole glass and kills the transparency. Masking out the
    // interior keeps the depth around the edge while the glass stays clear.
    Item {
        id: shadowLayer
        anchors.fill: parent
        anchors.margins: -48
        visible: root.shadow || root.glowStrength > 0.01
        layer.enabled: root.glassy && visible
        layer.effect: MultiEffect {
            maskEnabled: true
            maskInverted: true
            maskSource: shadowMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
        RectangularShadow {
            x: 48; y: 48; width: root.width; height: root.height
            visible: root.shadow
            radius: root.r
            blur: root.shadowBlur
            spread: -6
            offset.y: root.shadowY
            color: Theme.shadow
        }
        RectangularShadow {
            x: 48; y: 48; width: root.width; height: root.height
            visible: root.shadow
            radius: root.r
            blur: 5
            spread: -1
            offset.y: 1.5
            color: Theme.alpha(Theme.shadow, Theme.shadow.a * 0.7)
        }
        RectangularShadow {
            x: 48; y: 48; width: root.width; height: root.height
            visible: opacity > 0.01
            radius: root.r
            blur: 36
            spread: 2
            color: root.glowColor
            opacity: root.glowStrength
            Behavior on opacity { NumberAnimation { duration: 600 } }
            Behavior on color { ColorAnimation { duration: 500 } }
        }
    }
    Item {
        id: shadowMask
        anchors.fill: shadowLayer
        visible: false
        layer.enabled: shadowLayer.layer.enabled
        Rectangle { x: 48; y: 48; width: root.width; height: root.height; radius: root.r; color: "white" }
    }

    // ── body ──
    Rectangle {
        id: body
        anchors.fill: parent
        radius: root.r
        border.width: root.glassy ? 0 : 1
        border.color: Qt.rgba(1, 1, 1, Theme.dark ? 0.07 : 0.4)
        gradient: Gradient {
            GradientStop {
                position: 0
                color: root.glassy ? Theme.alpha(Theme.mix(root.tint, Qt.rgba(1, 1, 1, 1), Theme.dark ? 0.08 : 0.3), root.tint.a) : root.tint
                Behavior on color { ColorAnimation { duration: 400 } }
            }
            GradientStop {
                position: 1
                color: root.glassy ? Theme.alpha(Theme.mix(root.tint, Qt.rgba(0, 0, 0, 1), Theme.dark ? 0.12 : 0.02), root.tint.a) : root.tint
                Behavior on color { ColorAnimation { duration: 400 } }
            }
        }
    }

    // ── top gloss + bottom bounce light ──
    Rectangle {
        anchors.fill: parent
        visible: root.sheen && root.glassy
        radius: root.r
        gradient: Gradient {
            GradientStop { position: 0.0;  color: Qt.rgba(1, 1, 1, Theme.dark ? 0.085 : 0.30) }
            GradientStop { position: Math.min(0.5, 22 / Math.max(1, root.height)); color: Qt.rgba(1, 1, 1, Theme.dark ? 0.02 : 0.08) }
            GradientStop { position: 0.55; color: Qt.rgba(1, 1, 1, 0) }
            GradientStop { position: 0.9;  color: Qt.rgba(1, 1, 1, 0) }
            GradientStop { position: 1.0;  color: Qt.rgba(1, 1, 1, Theme.dark ? 0.04 : 0.14) }
        }
    }

    // ── inner edge light: light caught inside the glass's thickness ──
    // A soft band hugging the inside of the rim, bright along the top and faint
    // along the bottom (bounce), blurred and clipped to the shape. This is what
    // makes it read as a lens instead of a translucent plate.
    Item {
        id: edgeLight
        anchors.fill: parent
        visible: root.rim && root.glassy && root.width > 16 && root.height > 16
        layer.enabled: visible
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 16
            blur: 0.55
            maskEnabled: true
            maskSource: edgeMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                strokeColor: "transparent"
                fillRule: ShapePath.OddEvenFill
                fillGradient: LinearGradient {
                    x1: 0; y1: 0; x2: 0; y2: root.height
                    GradientStop { position: 0.0;  color: Qt.rgba(1, 1, 1, Theme.dark ? 0.30 : 0.55) }
                    GradientStop { position: Math.min(0.45, 18 / Math.max(1, root.height)); color: Qt.rgba(1, 1, 1, Theme.dark ? 0.06 : 0.15) }
                    GradientStop { position: 0.5;  color: Qt.rgba(1, 1, 1, 0) }
                    GradientStop { position: 0.85; color: Qt.rgba(1, 1, 1, 0) }
                    GradientStop { position: 1.0;  color: Qt.rgba(1, 1, 1, Theme.dark ? 0.16 : 0.35) }
                }
                PathRectangle { x: 0; y: 0; width: root.width; height: root.height; radius: root.r }
                PathRectangle {
                    readonly property real inset: Math.min(6, root.height / 5)
                    x: inset; y: inset
                    width: Math.max(0, root.width - 2 * inset); height: Math.max(0, root.height - 2 * inset)
                    radius: Math.max(0, root.r - inset)
                }
            }
        }
    }
    Rectangle {
        id: edgeMask
        anchors.fill: parent
        radius: root.r
        visible: false
        layer.enabled: edgeLight.visible
    }

    // ── inner lensing edge: three hairlines fading inward ──
    Repeater {
        model: root.rim && root.glassy && root.width > 12 && root.height > 12 ? 3 : 0
        Rectangle {
            required property int index
            anchors.fill: parent
            anchors.margins: index + 1
            radius: Math.max(0, root.r - index - 1)
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, (Theme.dark ? [0.13, 0.06, 0.025] : [0.34, 0.18, 0.07])[index])
        }
    }

    // ── dispersion: a faint spectral fringe just inside the rim (light splitting
    //    as it bends through the glass edge) ──
    Shape {
        anchors.fill: parent
        visible: root.rim && root.glassy && root.width > 16 && root.height > 16
        opacity: Theme.dark ? 0.16 : 0.22
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            strokeColor: "transparent"
            fillRule: ShapePath.OddEvenFill
            fillGradient: ConicalGradient {
                centerX: root.width / 2
                centerY: root.height / 2
                angle: root.cornerAngle + 20
                GradientStop { position: 0.00; color: "#7fd8ff" }
                GradientStop { position: 0.17; color: "#c9a2ff" }
                GradientStop { position: 0.33; color: "#ff9ec7" }
                GradientStop { position: 0.50; color: "#ffe08a" }
                GradientStop { position: 0.67; color: "#9effc9" }
                GradientStop { position: 0.83; color: "#8ab8ff" }
                GradientStop { position: 1.00; color: "#7fd8ff" }
            }
            PathRectangle { x: 1; y: 1; width: root.width - 2; height: root.height - 2; radius: Math.max(0, root.r - 1) }
            PathRectangle { x: 2.5; y: 2.5; width: root.width - 5; height: root.height - 5; radius: Math.max(0, root.r - 2.5) }
        }
    }

    // ── specular rim (ring = outer − inner, conical gradient: two corner highlights) ──
    Shape {
        anchors.fill: parent
        visible: root.rim && root.glassy && root.width > 4 && root.height > 4
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            strokeColor: "transparent"
            fillRule: ShapePath.OddEvenFill
            fillGradient: ConicalGradient {
                centerX: root.width / 2
                centerY: root.height / 2
                angle: root.cornerAngle
                GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, Theme.dark ? 0.70 : 1.0) }
                GradientStop { position: 0.10; color: Qt.rgba(1, 1, 1, Theme.dark ? 0.22 : 0.6) }
                GradientStop { position: 0.25; color: Qt.rgba(1, 1, 1, Theme.dark ? 0.06 : 0.25) }
                GradientStop { position: 0.40; color: Qt.rgba(1, 1, 1, Theme.dark ? 0.18 : 0.5) }
                GradientStop { position: 0.50; color: Qt.rgba(1, 1, 1, Theme.dark ? 0.45 : 0.9) }
                GradientStop { position: 0.60; color: Qt.rgba(1, 1, 1, Theme.dark ? 0.18 : 0.5) }
                GradientStop { position: 0.75; color: Qt.rgba(1, 1, 1, Theme.dark ? 0.06 : 0.25) }
                GradientStop { position: 0.90; color: Qt.rgba(1, 1, 1, Theme.dark ? 0.22 : 0.6) }
                GradientStop { position: 1.00; color: Qt.rgba(1, 1, 1, Theme.dark ? 0.70 : 1.0) }
            }
            PathRectangle { x: 0; y: 0; width: root.width; height: root.height; radius: root.r }
            PathRectangle { x: 1; y: 1; width: root.width - 2; height: root.height - 2; radius: Math.max(0, root.r - 1) }
        }
    }
}
