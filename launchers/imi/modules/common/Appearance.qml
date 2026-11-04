pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "functions"
import shell.services as HostServices


Singleton {
    id: root

    // Bundled families (licenses in assets/fonts), registered process-wide
    // so every user gets the same look without installing anything.
    FontLoader { source: Qt.resolvedUrl("../../assets/fonts/GoogleSansFlex.ttf") }
    FontLoader { source: Qt.resolvedUrl("../../assets/fonts/MaterialSymbolsRounded.ttf") }
    FontLoader { source: Qt.resolvedUrl("../../assets/fonts/JetBrainsMonoNerdFont-Regular.ttf") }

    property QtObject m3colors
    property QtObject animation
    property QtObject animationCurves
    property QtObject colors
    property QtObject rounding
    property QtObject font
    property QtObject sizes
    property QtObject spacing
    property string syntaxHighlightingTheme

    // Host palette. Colors come from Ryoku's matugen pipeline through
    // shell.services Theme; the barstyle keeps no private colour source.
    readonly property bool hostDark: HostServices.Theme.surface.hslLightness < 0.5
    readonly property string hostWallpaper: String(HostServices.Session.wallpaper ?? "")

    readonly property int windowRounding: {
        let rv = Config.options.appearance.roundingValue;
        if (rv <= 0)
            return 0;
        return Math.round(18 * rv / 24.0);
    }

    // Transparency. The quadratic functions were derived from analysis of hand-picked transparency values.
    ColorQuantizer {
        id: wallColorQuant
        property bool wallpaperIsVideo: root.hostWallpaper !== "" && (root.hostWallpaper.endsWith(".mp4") || root.hostWallpaper.endsWith(".webm") || root.hostWallpaper.endsWith(".mkv") || root.hostWallpaper.endsWith(".avi") || root.hostWallpaper.endsWith(".mov"))
        source: root.hostWallpaper !== "" ? Qt.resolvedUrl(root.hostWallpaper) : ""
        depth: 0 // 2^0 = 1 color
        rescaleSize: 10
    }
    property real wallpaperVibrancy: (wallColorQuant.colors[0]?.hslSaturation + wallColorQuant.colors[0]?.hslLightness) / 2 || 0
    property real autoBackgroundTransparency: { // y = 0.5768x^2 - 0.759x + 0.2896
        let x = wallpaperVibrancy;
        let y = 0.5768 * (x * x) - 0.759 * (x) + 0.2896;
        return Math.max(0, Math.min(0.22, y)) - 0.12 * (m3colors.darkmode ? 0 : 1);
    }
    property real autoContentTransparency: 0.9
    property real backgroundTransparency: Config?.options.appearance.transparency.enable ? Config?.options.appearance.transparency.automatic ? autoBackgroundTransparency : Config?.options.appearance.transparency.backgroundTransparency : 0
    property real contentTransparency: Config?.options.appearance.transparency.enable ? (Config?.options.appearance.transparency.automatic ? autoContentTransparency : Config?.options.appearance.transparency.contentTransparency) : 0

    m3colors: QtObject {
        property bool darkmode: root.hostDark
        property bool transparent: false
        property color m3background: HostServices.Theme.surface
        property color m3onBackground: HostServices.Theme.onSurface
        property color m3surface: HostServices.Theme.surface
        property color m3surfaceDim: HostServices.Theme.surfaceContainerLow
        property color m3surfaceBright: HostServices.Theme.surfaceContainerHigh
        property color m3surfaceContainerLowest: HostServices.Theme.surfaceContainerLowest
        property color m3surfaceContainerLow: HostServices.Theme.surfaceContainerLow
        property color m3surfaceContainer: HostServices.Theme.surfaceContainer
        property color m3surfaceContainerHigh: HostServices.Theme.surfaceContainerHigh
        property color m3surfaceContainerHighest: HostServices.Theme.surfaceContainerHighest
        property color m3onSurface: HostServices.Theme.onSurface
        property color m3surfaceVariant: HostServices.Theme.surfaceVariant
        property color m3onSurfaceVariant: HostServices.Theme.onSurfaceVariant
        property color m3inverseSurface: HostServices.Theme.inverseSurface
        property color m3inverseOnSurface: HostServices.Theme.inverseOnSurface
        property color m3outline: HostServices.Theme.outline
        property color m3outlineVariant: HostServices.Theme.outlineVariant
        property color m3shadow: HostServices.Theme.shadow
        property color m3scrim: HostServices.Theme.scrim
        property color m3surfaceTint: HostServices.Theme.surfaceTint
        property color m3primary: HostServices.Theme.primary
        property color m3onPrimary: HostServices.Theme.onPrimary
        property color m3primaryContainer: HostServices.Theme.primaryContainer
        property color m3onPrimaryContainer: HostServices.Theme.onPrimaryContainer
        property color m3inversePrimary: HostServices.Theme.primary
        property color m3secondary: HostServices.Theme.secondary
        property color m3onSecondary: HostServices.Theme.onSecondary
        property color m3secondaryContainer: HostServices.Theme.secondaryContainer
        property color m3onSecondaryContainer: HostServices.Theme.onSecondaryContainer
        property color m3tertiary: HostServices.Theme.tertiary
        property color m3onTertiary: HostServices.Theme.onTertiary
        property color m3tertiaryContainer: HostServices.Theme.tertiaryContainer
        property color m3onTertiaryContainer: HostServices.Theme.onTertiaryContainer
        property color m3error: HostServices.Theme.error
        property color m3onError: HostServices.Theme.onError
        property color m3errorContainer: HostServices.Theme.errorContainer
        property color m3onErrorContainer: HostServices.Theme.onErrorContainer
        property color m3primaryFixed: HostServices.Theme.primary
        property color m3primaryFixedDim: HostServices.Theme.primary
        property color m3onPrimaryFixed: HostServices.Theme.onPrimary
        property color m3onPrimaryFixedVariant: HostServices.Theme.onPrimaryContainer
        property color m3secondaryFixed: HostServices.Theme.secondary
        property color m3secondaryFixedDim: HostServices.Theme.secondary
        property color m3onSecondaryFixed: HostServices.Theme.onSecondary
        property color m3onSecondaryFixedVariant: HostServices.Theme.onSecondaryContainer
        property color m3tertiaryFixed: HostServices.Theme.tertiary
        property color m3tertiaryFixedDim: HostServices.Theme.tertiary
        property color m3onTertiaryFixed: HostServices.Theme.onTertiary
        property color m3onTertiaryFixedVariant: HostServices.Theme.onTertiaryContainer
        property color m3success: "#B5CCBA"
        property color m3onSuccess: "#213528"
        property color m3successContainer: "#374B3E"
        property color m3onSuccessContainer: "#D1E9D6"
        property color term0: "#EDE4E4"
        property color term1: "#B52755"
        property color term2: "#A97363"
        property color term3: "#AF535D"
        property color term4: "#A67F7C"
        property color term5: "#B2416B"
        property color term6: "#8D76AD"
        property color term7: "#272022"
        property color term8: "#0E0D0D"
        property color term9: "#B52755"
        property color term10: "#A97363"
        property color term11: "#AF535D"
        property color term12: "#A67F7C"
        property color term13: "#B2416B"
        property color term14: "#8D76AD"
        property color term15: "#221A1A"
    }

    colors: QtObject {
        property color colSubtext: m3colors.m3outline
        // Layer 0
        property color colLayer0Base: ColorUtils.mix(m3colors.m3background, m3colors.m3primary, Config.options.appearance.extraBackgroundTint ? 0.99 : 1)
        property color colLayer0: ColorUtils.transparentize(colLayer0Base, root.backgroundTransparency)
        property color colOnLayer0: m3colors.m3onBackground
        property color colLayer0Hover: ColorUtils.transparentize(ColorUtils.mix(colLayer0, colOnLayer0, 0.9, root.contentTransparency))
        property color colLayer0Active: ColorUtils.transparentize(ColorUtils.mix(colLayer0, colOnLayer0, 0.8, root.contentTransparency))
        property color colLayer0Border: ColorUtils.mix(root.m3colors.m3outlineVariant, colLayer0, 0.4)
        // Layer 1
        property color colLayer1Base: m3colors.m3surfaceContainerLow
        property color colLayer1: ColorUtils.solveOverlayColor(colLayer0Base, colLayer1Base, 1 - root.contentTransparency)
        property color colOnLayer1: m3colors.m3onSurfaceVariant
        property color colOnLayer1Inactive: ColorUtils.mix(colOnLayer1, colLayer1, 0.45)
        property color colLayer1Hover: ColorUtils.transparentize(ColorUtils.mix(colLayer1, colOnLayer1, 0.92), root.contentTransparency)
        property color colLayer1Active: ColorUtils.transparentize(ColorUtils.mix(colLayer1, colOnLayer1, 0.85), root.contentTransparency)
        // Layer 2
        property color colLayer2Base: m3colors.m3surfaceContainer
        property color colLayer2: ColorUtils.solveOverlayColor(colLayer1Base, colLayer2Base, 1 - root.contentTransparency)
        property color colLayer2Hover: ColorUtils.solveOverlayColor(colLayer1Base, ColorUtils.mix(colLayer2Base, colOnLayer2, 0.90), 1 - root.contentTransparency)
        property color colLayer2Active: ColorUtils.solveOverlayColor(colLayer1Base, ColorUtils.mix(colLayer2Base, colOnLayer2, 0.80), 1 - root.contentTransparency)
        property color colLayer2Disabled: ColorUtils.solveOverlayColor(colLayer1Base, ColorUtils.mix(colLayer2Base, m3colors.m3background, 0.8), 1 - root.contentTransparency)
        property color colOnLayer2: m3colors.m3onSurface
        property color colOnLayer2Disabled: ColorUtils.mix(colOnLayer2, m3colors.m3background, 0.4)
        // Layer 3
        property color colLayer3Base: m3colors.m3surfaceContainerHigh
        property color colLayer3: ColorUtils.solveOverlayColor(colLayer2Base, colLayer3Base, 1 - root.contentTransparency)
        property color colLayer3Hover: ColorUtils.solveOverlayColor(colLayer2Base, ColorUtils.mix(colLayer3Base, colOnLayer3, 0.90), 1 - root.contentTransparency)
        property color colLayer3Active: ColorUtils.solveOverlayColor(colLayer2Base, ColorUtils.mix(colLayer3Base, colOnLayer3, 0.80), 1 - root.contentTransparency)
        property color colOnLayer3: m3colors.m3onSurface
        // Layer 4
        property color colLayer4Base: m3colors.m3surfaceContainerHighest
        property color colLayer4: ColorUtils.solveOverlayColor(colLayer3Base, colLayer4Base, 1 - root.contentTransparency)
        property color colLayer4Hover: ColorUtils.solveOverlayColor(colLayer3Base, ColorUtils.mix(colLayer4Base, colOnLayer4, 0.90), 1 - root.contentTransparency)
        property color colLayer4Active: ColorUtils.solveOverlayColor(colLayer3Base, ColorUtils.mix(colLayer4Base, colOnLayer4, 0.80), 1 - root.contentTransparency)
        property color colOnLayer4: m3colors.m3onSurface
        // Primary
        property color colPrimary: m3colors.m3primary
        property color colOnPrimary: m3colors.m3onPrimary
        property color colPrimaryHover: ColorUtils.mix(colors.colPrimary, colLayer1Hover, 0.87)
        property color colPrimaryActive: ColorUtils.mix(colors.colPrimary, colLayer1Active, 0.7)
        property color colPrimaryContainer: m3colors.m3primaryContainer
        property color colPrimaryContainerHover: ColorUtils.mix(colors.colPrimaryContainer, colors.colOnPrimaryContainer, 0.9)
        property color colPrimaryContainerActive: ColorUtils.mix(colors.colPrimaryContainer, colors.colOnPrimaryContainer, 0.8)
        property color colOnPrimaryContainer: m3colors.m3onPrimaryContainer
        // Secondary
        property color colSecondary: m3colors.m3secondary
        property color colSecondaryHover: ColorUtils.mix(m3colors.m3secondary, colLayer1Hover, 0.85)
        property color colSecondaryActive: ColorUtils.mix(m3colors.m3secondary, colLayer1Active, 0.4)
        property color colOnSecondary: m3colors.m3onSecondary
        property color colSecondaryContainer: m3colors.m3secondaryContainer
        property color colSecondaryContainerHover: ColorUtils.mix(m3colors.m3secondaryContainer, m3colors.m3onSecondaryContainer, 0.90)
        property color colSecondaryContainerActive: ColorUtils.mix(m3colors.m3secondaryContainer, m3colors.m3onSecondaryContainer, 0.54)
        property color colOnSecondaryContainer: m3colors.m3onSecondaryContainer
        // Tertiary
        property color colTertiary: m3colors.m3tertiary
        property color colTertiaryHover: ColorUtils.mix(m3colors.m3tertiary, colLayer1Hover, 0.85)
        property color colTertiaryActive: ColorUtils.mix(m3colors.m3tertiary, colLayer1Active, 0.4)
        property color colTertiaryContainer: m3colors.m3tertiaryContainer
        property color colTertiaryContainerHover: ColorUtils.mix(m3colors.m3tertiaryContainer, m3colors.m3onTertiaryContainer, 0.90)
        property color colTertiaryContainerActive: ColorUtils.mix(m3colors.m3tertiaryContainer, colLayer1Active, 0.54)
        property color colOnTertiary: m3colors.m3onTertiary
        property color colOnTertiaryContainer: m3colors.m3onTertiaryContainer
        // Surface
        property color colBackgroundSurfaceContainer: ColorUtils.transparentize(m3colors.m3surfaceContainer, root.backgroundTransparency)
        property color colBackgroundSurfaceContainerAccent: ColorUtils.transparentize(
            ColorUtils.mix(m3colors.m3surfaceContainer, m3colors.m3primaryContainer,
                           1.0 - (Config.options.search.appearance.accentPanels ? Config.options.search.appearance.accentStrength : 0.0)),
            root.backgroundTransparency)
        property color colSurfaceContainerLow: ColorUtils.solveOverlayColor(m3colors.m3background, m3colors.m3surfaceContainerLow, 1 - root.contentTransparency)
        property color colSurfaceContainer: ColorUtils.solveOverlayColor(m3colors.m3surfaceContainerLow, m3colors.m3surfaceContainer, 1 - root.contentTransparency)
        property color colSurfaceContainerHigh: ColorUtils.solveOverlayColor(m3colors.m3surfaceContainer, m3colors.m3surfaceContainerHigh, 1 - root.contentTransparency)
        property color colSurfaceContainerHighest: ColorUtils.solveOverlayColor(m3colors.m3surfaceContainerHigh, m3colors.m3surfaceContainerHighest, 1 - root.contentTransparency)
        property color colSurfaceContainerHighestHover: ColorUtils.mix(m3colors.m3surfaceContainerHighest, m3colors.m3onSurface, 0.95)
        property color colSurfaceContainerHighestActive: ColorUtils.mix(m3colors.m3surfaceContainerHighest, m3colors.m3onSurface, 0.85)
        property color colOnSurface: m3colors.m3onSurface
        property color colOnSurfaceVariant: m3colors.m3onSurfaceVariant
        // Misc
        property color colTooltip: m3colors.m3surfaceContainerHigh
        property color colOnTooltip: m3colors.m3onSurface
        property color colScrim: ColorUtils.transparentize(m3colors.m3scrim, 0.5)
        property color colShadow: ColorUtils.transparentize(m3colors.m3shadow, 0.7)
        property color colOutline: m3colors.m3outline
        property color colOutlineVariant: m3colors.m3outlineVariant
        property color colError: m3colors.m3error
        property color colErrorHover: ColorUtils.mix(m3colors.m3error, colLayer1Hover, 0.85)
        property color colErrorActive: ColorUtils.mix(m3colors.m3error, colLayer1Active, 0.7)
        property color colOnError: m3colors.m3onError
        property color colErrorContainer: m3colors.m3errorContainer
        property color colErrorContainerHover: ColorUtils.mix(m3colors.m3errorContainer, m3colors.m3onErrorContainer, 0.90)
        property color colErrorContainerActive: ColorUtils.mix(m3colors.m3errorContainer, m3colors.m3onErrorContainer, 0.70)
        property color colOnErrorContainer: m3colors.m3onErrorContainer
    }

    rounding: QtObject {
        property real scale: {
            let rv = Config.options.appearance.roundingValue;
            if (rv > 0)
                return rv / 24.0;
            if (rv < 0)
                return 1.0; // not yet migrated, default to large
            return 0.0; // roundingValue === 0 → sharp
        }

        property int unsharpen: Math.round(2 * scale)
        property int unsharpenmore: Math.round(6 * scale)
        property int verysmall: Math.round(8 * scale)
        property int small: Math.round(12 * scale)
        property int normal: Math.round(17 * scale)
        property int large: Math.round(24 * scale)
        property int verylarge: Math.round(32 * scale)
        property int full: scale === 0 ? 0 : 9999
        property int screenRounding: {
            if (scale === 0)
                return 0;

            // Harmonious concentric screen rounding (UI/UX concentric radius rule):
            // Outer Screen Radius = Bar Radius + Margins between bar and screen edge
            {
                const barDim = root.sizes?.baseBarHeight ?? Config.options?.bar?.sizes?.height ?? 40;
                const barRadius = Math.round(barDim / 2);
                const barMargin = root.sizes?.hyprlandGapsOut ?? Config.options?.appearance?.gapsOut ?? 5;
                return barRadius + barMargin;
            }

            return large;
        }
        property int windowRounding: root.windowRounding
    }

    property color activeBorderColor: {
        let type = Config.options.appearance.borderColorType;
        if (type === "secondary")
            return colors.colSecondary;
        if (type === "tertiary")
            return colors.colTertiary;
        if (type === "primaryContainer")
            return colors.colPrimaryContainer;
        if (type === "surface")
            return colors.colOutlineVariant;
        return colors.colPrimary;
    }

    property bool borderless: Config.options.appearance.borderless ?? false
    property int borderWidth: Config.options.appearance.borderWidth ?? 2
    property int blurSize: Config.options.appearance.blurSize ?? 8

    font: QtObject {
        property QtObject family: QtObject {
            property string main: Config.options.appearance.fonts.main
            property string numbers: Config.options.appearance.fonts.numbers
            property string title: Config.options.appearance.fonts.title
            property string iconMaterial: "Material Symbols Rounded"
            property string iconNerd: Config.options.appearance.fonts.iconNerd
            property string monospace: Config.options.appearance.fonts.monospace
            property string reading: Config.options.appearance.fonts.reading
            property string expressive: Config.options.appearance.fonts.expressive
        }
        property QtObject variableAxes: QtObject {
            property var main: ({
                    "wght": 450,
                    "wdth": 100,
                    "ROND": Config.options.appearance.fonts.roundnessFull ? 100 : 0
                })
            property var numbers: ({
                    "wght": 450,
                    "ROND": Config.options.appearance.fonts.roundnessFull ? 100 : 0
                })
            property var title: ({ // Slightly bold weight for title
                    "wght": 550 // Weight (Lowered to compensate for increased grade)
                    ,
                    "ROND": Config.options.appearance.fonts.roundnessFull ? 100 : 0
                })
            property var rounded: ({
                    "wght": 450,
                    "wdth": 100,
                    "ROND": 100
                })
            property var titleRounded: ({
                    "wght": 550,
                    "ROND": 100
                })

            // Every distinct axes value makes Qt open a new FreeType face of the font: a
            // fresh 4 MB mmap of the whole file (~1.4 MB resident, never shared in RSS) that
            // the font cache only trims ~5 engines per 10 s. An axis that follows an animated
            // value therefore creates one face per frame, hundreds per session (that was the
            // 1.5 -> 2.2 GB regression). Interpolated axes must go through blend()/snap(),
            // which keep the number of distinct values to steps + 1 per pair of endpoints.
            readonly property int steps: 3
            function snap(t: real): real {
                return Math.round(Math.max(0, Math.min(1, t)) * steps) / steps;
            }
            function blend(from: real, to: real, t: real): real {
                return Math.round(from + (to - from) * snap(t));
            }
            // For an axis that carries meaning along its whole range (a clock whose width
            // tracks the minute): n steps instead of the shell-wide default.
            function blendIn(from: real, to: real, t: real, n: int): real {
                return Math.round(from + (to - from) * Math.round(Math.max(0, Math.min(1, t)) * n) / n);
            }
        }
        property QtObject pixelSize: QtObject {
            property int smallest: 10
            property int smaller: 12
            property int smallie: 13
            property int small: 15
            property int normal: 16
            property int large: 17
            property int larger: 19
            property int huge: 22
            property int hugeass: 23
            property int title: huge
        }
    }

    // Global animation speed multiplier — driven by Config.options.appearance.animationMultiplier
    readonly property real animMultiplier: Config.options?.appearance?.animationMultiplier ?? 1.0
    // Below this the shell skips animations outright rather than running them absurdly fast (the
    // sidebars' own convention); Edit Mode reads it as one flag instead of repeating the test.
    readonly property bool reducedMotion: root.animMultiplier <= 0.25

    animationCurves: QtObject {
        readonly property list<real> expressiveFastSpatial: [0.42, 1.67, 0.21, 0.90, 1, 1] // Default, 350ms
        readonly property list<real> expressiveDefaultSpatial: [0.38, 1.21, 0.22, 1.00, 1, 1] // Default, 500ms
        readonly property list<real> expressiveSlowSpatial: [0.39, 1.29, 0.35, 0.98, 1, 1] // Default, 650ms
        readonly property list<real> expressiveEffects: [0.34, 0.80, 0.34, 1.00, 1, 1] // Default, 200ms
        readonly property list<real> emphasized: [0.05, 0, 2 / 15, 0.06, 1 / 6, 0.4, 5 / 24, 0.82, 0.25, 1, 1, 1]
        readonly property list<real> emphasizedFirstHalf: [0.05, 0, 2 / 15, 0.06, 1 / 6, 0.4, 5 / 24, 0.82]
        readonly property list<real> emphasizedLastHalf: [5 / 24, 0.82, 0.25, 1, 1, 1]
        readonly property list<real> emphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]
        readonly property list<real> emphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
        readonly property list<real> standard: [0.2, 0, 0, 1, 1, 1]
        readonly property list<real> standardAccel: [0.3, 0, 1, 1, 1, 1]
        readonly property list<real> standardDecel: [0, 0, 0, 1, 1, 1]
        readonly property real expressiveFastSpatialDuration: 350
        readonly property real expressiveDefaultSpatialDuration: 500
        readonly property real expressiveSlowSpatialDuration: 650
        readonly property real expressiveEffectsDuration: 200
    }

    animation: QtObject {
        property QtObject elementMove: QtObject {
            property int duration: Math.round(animationCurves.expressiveDefaultSpatialDuration * root.animMultiplier)
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveDefaultSpatial
            property int velocity: 650
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.elementMove.duration
                    easing.type: root.animation.elementMove.type
                    easing.bezierCurve: root.animation.elementMove.bezierCurve
                }
            }
        }

        property QtObject elementMoveSmall: QtObject {
            property int duration: Math.round(animationCurves.expressiveFastSpatialDuration * root.animMultiplier)
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveFastSpatial
            property int velocity: 650
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.elementMoveSmall.duration
                    easing.type: root.animation.elementMoveSmall.type
                    easing.bezierCurve: root.animation.elementMoveSmall.bezierCurve
                }
            }
        }

        property QtObject elementMoveEnter: QtObject {
            property int duration: Math.round(400 * root.animMultiplier)
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.emphasizedDecel
            property int velocity: 650
            property Component numberAnimation: Component {
                NumberAnimation {
                    alwaysRunToEnd: true
                    duration: root.animation.elementMoveEnter.duration
                    easing.type: root.animation.elementMoveEnter.type
                    easing.bezierCurve: root.animation.elementMoveEnter.bezierCurve
                }
            }
        }

        property QtObject elementMoveExit: QtObject {
            property int duration: Math.round(200 * root.animMultiplier)
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.emphasizedAccel
            property int velocity: 650
            property Component numberAnimation: Component {
                NumberAnimation {
                    alwaysRunToEnd: true
                    duration: root.animation.elementMoveExit.duration
                    easing.type: root.animation.elementMoveExit.type
                    easing.bezierCurve: root.animation.elementMoveExit.bezierCurve
                }
            }
        }

        property QtObject popupEnter: QtObject {
            property int duration: Math.round(280 * root.animMultiplier)
        }

        property QtObject popupExit: QtObject {
            property int duration: Math.round(150 * root.animMultiplier)
        }

        property QtObject elementMoveSlow: QtObject {
            property int duration: Math.round(animationCurves.expressiveEffectsDuration * 2.5 * root.animMultiplier)
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveEffects
            property int velocity: 850
            property Component colorAnimation: Component {
                ColorAnimation {
                    duration: root.animation.elementMoveSlow.duration
                    easing.type: root.animation.elementMoveSlow.type
                    easing.bezierCurve: root.animation.elementMoveSlow.bezierCurve
                }
            }
            property Component numberAnimation: Component {
                NumberAnimation {
                    alwaysRunToEnd: true
                    duration: root.animation.elementMoveSlow.duration
                    easing.type: root.animation.elementMoveSlow.type
                    easing.bezierCurve: root.animation.elementMoveSlow.bezierCurve
                }
            }
        }

        property QtObject elementMoveFast: QtObject {
            property int duration: Math.round(animationCurves.expressiveEffectsDuration * root.animMultiplier)
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveEffects
            property int velocity: 850
            property Component colorAnimation: Component {
                ColorAnimation {
                    duration: root.animation.elementMoveFast.duration
                    easing.type: root.animation.elementMoveFast.type
                    easing.bezierCurve: root.animation.elementMoveFast.bezierCurve
                }
            }
            property Component numberAnimation: Component {
                NumberAnimation {
                    alwaysRunToEnd: true
                    duration: root.animation.elementMoveFast.duration
                    easing.type: root.animation.elementMoveFast.type
                    easing.bezierCurve: root.animation.elementMoveFast.bezierCurve
                }
            }
        }

        /**
         * A selection that follows the keyboard (Alt+Tab's highlight). Shorter than
         * elementMoveFast so a held key reads as one motion, and deliberately without
         * `alwaysRunToEnd`: a Behavior retargets from wherever the value is, and running
         * each leg to its end would queue every press behind the last one.
         */
        property QtObject elementMoveSnap: QtObject {
            property int duration: Math.round(150 * root.animMultiplier)
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveFastSpatial
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.elementMoveSnap.duration
                    easing.type: root.animation.elementMoveSnap.type
                    easing.bezierCurve: root.animation.elementMoveSnap.bezierCurve
                }
            }
        }

        property QtObject elementResize: QtObject {
            property int duration: Math.round(300 * root.animMultiplier)
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.emphasized
            property int velocity: 650
            property Component numberAnimation: Component {
                NumberAnimation {
                    alwaysRunToEnd: true
                    duration: root.animation.elementResize.duration
                    easing.type: root.animation.elementResize.type
                    easing.bezierCurve: root.animation.elementResize.bezierCurve
                }
            }
        }

        // Every size change that happens *inside* the bar reads from here: the
        // widgets and the island backgrounds that wrap them have to reach their
        // new size at the same instant, and they only do that if they share one
        // duration and one curve.
        property QtObject barResize: QtObject {
            property int duration: Math.round(280 * root.animMultiplier)
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveFastSpatial
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.barResize.duration
                    easing.type: root.animation.barResize.type
                    easing.bezierCurve: root.animation.barResize.bezierCurve
                }
            }
        }

        // Dashboard indicators use a staged transition: the slot changes size
        // before/after the icon pop. Keep these slower and softer than the
        // global barResize clock without slowing every other responsive widget.
        property QtObject dashboardIndicatorResize: QtObject {
            property int duration: Math.round(420 * root.animMultiplier)
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.standard
        }

        property QtObject dashboardIndicatorPop: QtObject {
            property int enterDuration: Math.round(360 * root.animMultiplier)
            property int exitDuration: Math.round(280 * root.animMultiplier)
            property int cueDelay: Math.round(90 * root.animMultiplier)
            property int exitHoldDuration: Math.round(220 * root.animMultiplier)
            property int enterType: Easing.OutBack
            property real enterOvershoot: 1.18
            property int exitType: Easing.BezierSpline
            property list<real> exitCurve: animationCurves.emphasizedAccel
        }

        // The bar leaving the screen: a fullscreen window taking over, or a
        // placement swap. The exit accelerates away and the entrance decelerates in.
        property QtObject shellEdgeSlide: QtObject {
            property int exitDuration: Math.round(260 * root.animMultiplier)
            property int enterDuration: Math.round(420 * root.animMultiplier)
            property int swapHold: Math.round(90 * root.animMultiplier)
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.shellEdgeSlide.enterDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.animationCurves.emphasized
                }
            }
        }

        // Sidebars sliding in and out. No overshoot anywhere: expressive spatial
        // curves kick off at ~3x linear speed and bounce the wallpaper past its rest.
        property QtObject sidebarSlide: QtObject {
            property int enterDuration: Math.round(500 * root.animMultiplier)
            property int exitDuration: Math.round(500 * root.animMultiplier)
            property list<real> enterCurve: root.animationCurves.emphasized
            property list<real> exitCurve: root.animationCurves.emphasized
            property int parallaxDuration: Math.round(700 * root.animMultiplier)
            property list<real> parallaxCurve: root.animationCurves.emphasized
        }

        property QtObject clickBounce: QtObject {
            property int duration: Math.round(400 * root.animMultiplier)
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveDefaultSpatial
            property int velocity: 850
            property Component numberAnimation: Component {
                NumberAnimation {
                    alwaysRunToEnd: true
                    duration: root.animation.clickBounce.duration
                    easing.type: root.animation.clickBounce.type
                    easing.bezierCurve: root.animation.clickBounce.bezierCurve
                }
            }
        }

        property QtObject scroll: QtObject {
            property int duration: Math.round(200 * root.animMultiplier)
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: root.animationCurves.standardDecel
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.scroll.duration
                    easing.type: root.animation.scroll.type
                    easing.bezierCurve: root.animation.scroll.bezierCurve
                }
            }
        }

        property QtObject menuDecel: QtObject {
            property int duration: Math.round(350 * root.animMultiplier)
            property int type: Easing.OutExpo
        }
    }

    sizes: QtObject {
        property real minimumTouchTarget: 48
        readonly property real familyWidgetGridStep: 10
        property real widgetGridStep: {
            const configured = Config.options?.background?.widgets?.gridStep ?? 0;
            return configured > 0 ? configured : root.sizes.familyWidgetGridStep;
        }
        property real baseBarHeight: Config.options.bar.sizes.height
        property real barHeight: baseBarHeight
        // Bar widgets were drawn against a 40px horizontal bar and a 44px vertical one, and
        // most of them size their outer plate off the bar while leaving the glyph inside at
        // the number it was drawn with.
        readonly property real barReferenceHeight: 40
        readonly property real barReferenceWidth: 44
        readonly property real barContentScale: root.sizes.baseBarHeight / root.sizes.barReferenceHeight
        readonly property real verticalBarContentScale: root.sizes.verticalBarWidth / root.sizes.barReferenceWidth

        property real barCenterSideModuleWidth: Config.options?.bar.verbose ? 360 : 140
        property real barCenterSideModuleWidthShortened: 280
        property real barCenterSideModuleWidthHellaShortened: 190
        property real barShortenScreenWidthThreshold: 1200 // Shorten if screen width is at most this value
        property real barHellaShortenScreenWidthThreshold: 1000 // Shorten even more...
        property real elevationMargin: 10
        property real toolbarHeight: 46
        property real editModeToolbarHeight: 60
        property real editModeMargin: 24
        property real editModeEdgeMargin: 12
        property real editModeDrawerWidth: 380
        property real fabShadowRadius: 5
        property real fabHoveredShadowRadius: 7
        property real hyprlandGapsOut: 5
        property real mediaControlsWidth: 440
        property real mediaControlsHeight: 160
        property real notificationPopupWidth: 410
        property real osdWidth: 200
        property real searchWidthCollapsed: 350
        property real searchWidth: 500
        property real sidebarWidth: 460
        property real sidebarWidthExtended: 750
        property real baseVerticalBarWidth: Config.options.bar.sizes.width
        property real verticalBarWidth: baseVerticalBarWidth
        property real verticalBarWindowWidth: baseVerticalBarWidth
        property real wallpaperSelectorWidth: 1200
        property real wallpaperSelectorHeight: 690
        property real wallpaperSelectorSidebarWidth: 180
        property real wallpaperSelectorSidebarButtonHeight: 48
        property real wallpaperSelectorSidebarHorizontalPadding: 6
        property real wallpaperSelectorSidebarButtonSpacing: 3
        property real wallpaperSelectorSidebarGroupSpacing: 10
        property real wallpaperSelectorSearchWidth: 300
        property real wallpaperSelectorSortDialogWidth: 280
        property real wallpaperSelectorItemMargins: 8
        property real wallpaperSelectorItemPadding: 6
        property int dockButtonSize: Math.round((Config.options?.dock.height ?? 60) * 0.85)
    }

    syntaxHighlightingTheme: root.m3colors.darkmode ? "Monokai" : "ayu Light"

    spacing: QtObject {
        property int space0: 0
        property int space25: 2
        property int space50: 4
        property int space75: 6
        property int space100: 8
        property int space125: 10
        property int space150: 12
        property int space175: 14
        property int space200: 16
        property int space250: 20
        property int space300: 24
        property int space400: 32
        property int space450: 36
        property int space500: 40
        property int space600: 48
        property int space700: 56
    }

    // Standard/emphasis stroke widths for surfaces that need more than the
    // single compositor-level borderWidth.
    property int borderWidthStandard: 1
    property int borderWidthEmphasis: 2
}
