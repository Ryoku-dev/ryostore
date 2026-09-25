pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Ryoku.PluginKit.Singletons as Kit
import "."

// Material 3 appearance for the MJW widget set. The structure mirrors the
// illogical-impulse Appearance.qml (m3colors -> colors tonal ramp -> rounding
// -> font -> sizes -> curves -> animation -> transparency) so the ported
// widgets read the exact role names they were authored against, with the m3
// tokens resolved from Ryoku's live daemon palette (Kit.Scheme: named scheme,
// then wallpaper colors.json, then compiled defaults) instead of end4's fixed
// scheme: every tile retints when the theme or wallpaper changes. The host
// accent handoff overrides the accent roles while the flag is on.
Singleton {
    id: root

    // Host accent override: transparent = off, roles keep the daemon palette.
    property color accentOverride: "transparent"
    readonly property bool hasAccent: accentOverride.a > 0

    function setAccent(c) {
        root.accentOverride = c
    }

    function accentFor(key, base) {
        if (key === "primary") return root.accentOverride;
        if (key === "onPrimary")
            return root.accentOverride.hslLightness > 0.55 ? "#131313" : "#F2EFF3";
        if (key === "primaryContainer")
            return ColorUtils.mix(base, root.accentOverride, 0.6);
        if (key === "onPrimaryContainer")
            return Qt.hsla(root.accentOverride.hslHue, 0.55, 0.82, 1);
        if (key === "inversePrimary") return Qt.darker(root.accentOverride, 1.4);
        if (key === "surfaceTint") return root.accentOverride;
        return base;
    }

    property QtObject m3colors
    property QtObject colors
    property QtObject rounding
    property QtObject font
    property QtObject sizes
    property QtObject animationCurves
    property QtObject animation

    // wallpaper vibrancy: how colourful the current wallpaper is, driving the
    // automatic transparency the upstream rule derives from it.
    ColorQuantizer {
        id: wallColorQuant
        source: Backdrop.wallpaperPath.length > 0
            ? "file://" + (Backdrop.wallpaperIsVideo ? Backdrop.wallpaperPoster : Backdrop.wallpaperPath)
            : ""
        depth: 0
        rescaleSize: 10
    }

    m3colors: QtObject {
        property bool darkmode: true
        property bool transparent: false
        readonly property color m3background: Kit.Scheme.role("background", "#141313")
        readonly property color m3onBackground: Kit.Scheme.role("onBackground", "#e6e1e1")
        readonly property color m3surface: Kit.Scheme.role("surface", "#141313")
        readonly property color m3surfaceDim: Kit.Scheme.role("surfaceDim", "#141313")
        readonly property color m3surfaceBright: Kit.Scheme.role("surfaceBright", "#3a3939")
        readonly property color m3surfaceContainerLowest: Kit.Scheme.role("surfaceContainerLowest", "#0f0e0e")
        readonly property color m3surfaceContainerLow: Kit.Scheme.role("surfaceContainerLow", "#1c1b1c")
        readonly property color m3surfaceContainer: Kit.Scheme.role("surfaceContainer", "#201f20")
        readonly property color m3surfaceContainerHigh: Kit.Scheme.role("surfaceContainerHigh", "#2b2a2a")
        readonly property color m3surfaceContainerHighest: Kit.Scheme.role("surfaceContainerHighest", "#363435")
        readonly property color m3onSurface: Kit.Scheme.role("onSurface", "#e6e1e1")
        readonly property color m3surfaceVariant: Kit.Scheme.role("surfaceVariant", "#49464a")
        readonly property color m3onSurfaceVariant: Kit.Scheme.role("onSurfaceVariant", "#cbc5ca")
        readonly property color m3inverseSurface: Kit.Scheme.role("inverseSurface", "#e6e1e1")
        readonly property color m3inverseOnSurface: Kit.Scheme.role("inverseOnSurface", "#313030")
        readonly property color m3outline: Kit.Scheme.role("outline", "#948f94")
        readonly property color m3outlineVariant: Kit.Scheme.role("outlineVariant", "#49464a")
        readonly property color m3shadow: Kit.Scheme.role("shadow", "#000000")
        readonly property color m3scrim: Kit.Scheme.role("scrim", "#000000")
        readonly property color m3surfaceTint: (root.hasAccent ? root.accentFor("surfaceTint", "#cbc4cb") : Kit.Scheme.role("surfaceTint", "#cbc4cb"))
        readonly property color m3primary: (root.hasAccent ? root.accentFor("primary", "#cbc4cb") : Kit.Scheme.role("primary", "#cbc4cb"))
        readonly property color m3onPrimary: (root.hasAccent ? root.accentFor("onPrimary", "#322f34") : Kit.Scheme.role("onPrimary", "#322f34"))
        readonly property color m3primaryContainer: (root.hasAccent ? root.accentFor("primaryContainer", "#2d2a2f") : Kit.Scheme.role("primaryContainer", "#2d2a2f"))
        readonly property color m3onPrimaryContainer: (root.hasAccent ? root.accentFor("onPrimaryContainer", "#bcb6bc") : Kit.Scheme.role("onPrimaryContainer", "#bcb6bc"))
        readonly property color m3inversePrimary: (root.hasAccent ? root.accentFor("inversePrimary", "#615d63") : Kit.Scheme.role("inversePrimary", "#615d63"))
        readonly property color m3secondary: Kit.Scheme.role("secondary", "#cac5c8")
        readonly property color m3onSecondary: Kit.Scheme.role("onSecondary", "#323032")
        readonly property color m3secondaryContainer: Kit.Scheme.role("secondaryContainer", "#4d4b4d")
        readonly property color m3onSecondaryContainer: Kit.Scheme.role("onSecondaryContainer", "#ece6e9")
        readonly property color m3tertiary: Kit.Scheme.role("tertiary", "#d1c3c6")
        readonly property color m3onTertiary: Kit.Scheme.role("onTertiary", "#372e30")
        readonly property color m3tertiaryContainer: Kit.Scheme.role("tertiaryContainer", "#31292b")
        readonly property color m3onTertiaryContainer: Kit.Scheme.role("onTertiaryContainer", "#c1b4b7")
        readonly property color m3error: Kit.Scheme.role("error", "#ffb4ab")
        readonly property color m3onError: Kit.Scheme.role("onError", "#690005")
        readonly property color m3errorContainer: Kit.Scheme.role("errorContainer", "#93000a")
        readonly property color m3onErrorContainer: Kit.Scheme.role("onErrorContainer", "#ffdad6")
        readonly property color m3primaryFixed: Kit.Scheme.role("primaryFixed", "#e7e0e7")
        readonly property color m3primaryFixedDim: Kit.Scheme.role("primaryFixedDim", "#cbc4cb")
        readonly property color m3onPrimaryFixed: Kit.Scheme.role("onPrimaryFixed", "#1d1b1f")
        readonly property color m3onPrimaryFixedVariant: Kit.Scheme.role("onPrimaryFixedVariant", "#49454b")
        readonly property color m3secondaryFixed: Kit.Scheme.role("secondaryFixed", "#e6e1e4")
        readonly property color m3secondaryFixedDim: Kit.Scheme.role("secondaryFixedDim", "#cac5c8")
        readonly property color m3onSecondaryFixed: Kit.Scheme.role("onSecondaryFixed", "#1d1b1d")
        readonly property color m3onSecondaryFixedVariant: Kit.Scheme.role("onSecondaryFixedVariant", "#484648")
        readonly property color m3tertiaryFixed: Kit.Scheme.role("tertiaryFixed", "#eddfe1")
        readonly property color m3tertiaryFixedDim: Kit.Scheme.role("tertiaryFixedDim", "#d1c3c6")
        readonly property color m3onTertiaryFixed: Kit.Scheme.role("onTertiaryFixed", "#211a1c")
        readonly property color m3onTertiaryFixedVariant: Kit.Scheme.role("onTertiaryFixedVariant", "#4e4447")
        readonly property color m3success: Kit.Scheme.role("success", "#B5CCBA")
        readonly property color m3onSuccess: Kit.Scheme.role("onSuccess", "#213528")
        readonly property color m3successContainer: Kit.Scheme.role("successContainer", "#374B3E")
        readonly property color m3onSuccessContainer: Kit.Scheme.role("onSuccessContainer", "#D1E9D6")
        readonly property color term0: Kit.Scheme.role("term0", "#EDE4E4")
        readonly property color term1: Kit.Scheme.role("term1", "#B52755")
        readonly property color term2: Kit.Scheme.role("term2", "#A97363")
        readonly property color term3: Kit.Scheme.role("term3", "#AF535D")
        readonly property color term4: Kit.Scheme.role("term4", "#A67F7C")
        readonly property color term5: Kit.Scheme.role("term5", "#B2416B")
        readonly property color term6: Kit.Scheme.role("term6", "#8D76AD")
        readonly property color term7: Kit.Scheme.role("term7", "#272022")
        readonly property color term8: Kit.Scheme.role("term8", "#0E0D0D")
        readonly property color term9: Kit.Scheme.role("term9", "#B52755")
        readonly property color term10: Kit.Scheme.role("term10", "#A97363")
        readonly property color term11: Kit.Scheme.role("term11", "#AF535D")
        readonly property color term12: Kit.Scheme.role("term12", "#A67F7C")
        readonly property color term13: Kit.Scheme.role("term13", "#B2416B")
        readonly property color term14: Kit.Scheme.role("term14", "#8D76AD")
        readonly property color term15: Kit.Scheme.role("term15", "#221A1A")
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
        property color colLayer1: ColorUtils.solveOverlayColor(colLayer0Base, colLayer1Base, 1 - root.contentTransparency);
        property color colOnLayer1: m3colors.m3onSurfaceVariant;
        property color colOnLayer1Inactive: ColorUtils.mix(colOnLayer1, colLayer1, 0.45);
        property color colLayer1Hover: ColorUtils.transparentize(ColorUtils.mix(colLayer1, colOnLayer1, 0.92), root.contentTransparency)
        property color colLayer1Active: ColorUtils.transparentize(ColorUtils.mix(colLayer1, colOnLayer1, 0.85), root.contentTransparency);
        // Layer 2
        property color colLayer2Base: m3colors.m3surfaceContainer
        property color colLayer2: ColorUtils.solveOverlayColor(colLayer1Base, colLayer2Base, 1 - root.contentTransparency)
        property color colLayer2Hover: ColorUtils.solveOverlayColor(colLayer1Base, ColorUtils.mix(colLayer2Base, colOnLayer2, 0.90), 1 - root.contentTransparency)
        property color colLayer2Active: ColorUtils.solveOverlayColor(colLayer1Base, ColorUtils.mix(colLayer2Base, colOnLayer2, 0.80), 1 - root.contentTransparency);
        property color colLayer2Disabled: ColorUtils.solveOverlayColor(colLayer1Base, ColorUtils.mix(colLayer2Base, m3colors.m3background, 0.8), 1 - root.contentTransparency);
        property color colOnLayer2: m3colors.m3onSurface;
        property color colOnLayer2Disabled: ColorUtils.mix(colOnLayer2, m3colors.m3background, 0.4);
        // Layer 3
        property color colLayer3Base: m3colors.m3surfaceContainerHigh
        property color colLayer3: ColorUtils.solveOverlayColor(colLayer2Base, colLayer3Base, 1 - root.contentTransparency)
        property color colLayer3Hover: ColorUtils.solveOverlayColor(colLayer2Base, ColorUtils.mix(colLayer3Base, colOnLayer3, 0.90), 1 - root.contentTransparency)
        property color colLayer3Active: ColorUtils.solveOverlayColor(colLayer2Base, ColorUtils.mix(colLayer3Base, colOnLayer3, 0.80), 1 - root.contentTransparency);
        property color colOnLayer3: m3colors.m3onSurface;
        // Layer 4
        property color colLayer4Base: m3colors.m3surfaceContainerHighest
        property color colLayer4: ColorUtils.solveOverlayColor(colLayer3Base, colLayer4Base, 1 - root.contentTransparency)
        property color colLayer4Hover: ColorUtils.solveOverlayColor(colLayer3Base, ColorUtils.mix(colLayer4Base, colOnLayer4, 0.90), 1 - root.contentTransparency)
        property color colLayer4Active: ColorUtils.solveOverlayColor(colLayer3Base, ColorUtils.mix(colLayer4Base, colOnLayer4, 0.80), 1 - root.contentTransparency);
        property color colOnLayer4: m3colors.m3onSurface;
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
        property color colSurfaceContainerLow: ColorUtils.solveOverlayColor(m3colors.m3background, m3colors.m3surfaceContainerLow, 1 - root.contentTransparency)
        property color colSurfaceContainer: ColorUtils.solveOverlayColor(m3colors.m3surfaceContainerLow, m3colors.m3surfaceContainer, 1 - root.contentTransparency)
        property color colSurfaceContainerHigh: ColorUtils.solveOverlayColor(m3colors.m3surfaceContainer, m3colors.m3surfaceContainerHigh, 1 - root.contentTransparency)
        property color colSurfaceContainerHighest: ColorUtils.solveOverlayColor(m3colors.m3surfaceContainerHigh, m3colors.m3surfaceContainerHighest, 1 - root.contentTransparency)
        property color colSurfaceContainerHighestHover: ColorUtils.mix(m3colors.m3surfaceContainerHighest, m3colors.m3onSurface, 0.95)
        property color colSurfaceContainerHighestActive: ColorUtils.mix(m3colors.m3surfaceContainerHighest, m3colors.m3onSurface, 0.85)
        property color colOnSurface: m3colors.m3onSurface
        property color colOnSurfaceVariant: m3colors.m3onSurfaceVariant
        // Misc
        property color colTooltip: m3colors.m3inverseSurface
        property color colOnTooltip: m3colors.m3inverseOnSurface
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
        property int unsharpen: 2
        property int unsharpenmore: 6
        property int verysmall: 8
        property int small: 12
        property int normal: 17
        property int large: 23
        property int verylarge: 30
        property int full: 9999
        property int screenRounding: large
        property int windowRounding: 18
    }

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
            })
            property var numbers: ({
                "wght": 450,
            })
            property var title: ({ // Slightly bold weight for title
                "wght": 550, // Weight (Lowered to compensate for increased grade)
            })
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

    sizes: QtObject {
        property real baseBarHeight: 40
        property real barHeight: Config.options.bar.cornerStyle === 1 ? 
            (baseBarHeight + root.sizes.hyprlandGapsOut * 2) : Config.options.bar.cornerStyle === 4 ? baseBarHeight + 4 : baseBarHeight
        property real barCenterSideModuleWidth: Config.options?.bar.verbose ? 360 : 140
        property real barCenterSideModuleWidthShortened: 280
        property real barCenterSideModuleWidthHellaShortened: 190
        property real barShortenScreenWidthThreshold: 1200 // Shorten if screen width is at most this value
        property real barHellaShortenScreenWidthThreshold: 1000 // Shorten even more...
        property real elevationMargin: 10
        property real fabShadowRadius: 5
        property real fabHoveredShadowRadius: 7
        property real hyprlandGapsOut: 5
        property real mediaControlsWidth: 440
        property real mediaControlsHeight: 160
        property real notificationPopupWidth: 410
        property real osdWidth: 180
        property real searchWidthCollapsed: 210
        property real searchWidth: 360
        property real sidebarWidth: 460
        property real sidebarWidthExtended: 750
        property real baseVerticalBarWidth: 46
        property real verticalBarWidth: Config.options.bar.cornerStyle === 1 ? 
            (baseVerticalBarWidth + root.sizes.hyprlandGapsOut * 2) : baseVerticalBarWidth
        property real wallpaperSelectorWidth: 1200
        property real wallpaperSelectorHeight: 690
        property real wallpaperSelectorItemMargins: 8
        property real wallpaperSelectorItemPadding: 6
    }

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
            property int duration: animationCurves.expressiveDefaultSpatialDuration
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
            property int duration: animationCurves.expressiveFastSpatialDuration
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
            property int duration: 400
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
            property int duration: 200
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

        property QtObject elementMoveFast: QtObject {
            property int duration: animationCurves.expressiveEffectsDuration
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveEffects
            property int velocity: 850
            property Component colorAnimation: Component { ColorAnimation {
                duration: root.animation.elementMoveFast.duration
                easing.type: root.animation.elementMoveFast.type
                easing.bezierCurve: root.animation.elementMoveFast.bezierCurve
            }}
            property Component numberAnimation: Component { NumberAnimation {
                alwaysRunToEnd: true
                duration: root.animation.elementMoveFast.duration
                easing.type: root.animation.elementMoveFast.type
                easing.bezierCurve: root.animation.elementMoveFast.bezierCurve
            }}
        }

        property QtObject elementResize: QtObject {
            property int duration: 300
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

        property QtObject clickBounce: QtObject {
            property int duration: 400
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveDefaultSpatial
            property int velocity: 850
            property Component numberAnimation: Component { NumberAnimation {
                alwaysRunToEnd: true
                duration: root.animation.clickBounce.duration
                easing.type: root.animation.clickBounce.type
                easing.bezierCurve: root.animation.clickBounce.bezierCurve
            }}
        }
        
        property QtObject scroll: QtObject {
            property int duration: 200
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: root.animationCurves.standardDecel
        }

        property QtObject menuDecel: QtObject {
            property int duration: 350
            property int type: Easing.OutExpo
        }

        property QtObject sidebarSlideEnter: QtObject {
            property int duration: 300
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.standardDecel
            property int velocity: 650
            property Component numberAnimation: Component {
                NumberAnimation {
                    alwaysRunToEnd: true
                    duration: root.animation.sidebarSlideEnter.duration
                    easing.type: root.animation.sidebarSlideEnter.type
                    easing.bezierCurve: root.animation.sidebarSlideEnter.bezierCurve
                }
            }
        }

        property QtObject sidebarSlideExit: QtObject {
            property int duration: 250
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.standardAccel
            property int velocity: 650
            property Component numberAnimation: Component {
                NumberAnimation {
                    alwaysRunToEnd: true
                    duration: root.animation.sidebarSlideExit.duration
                    easing.type: root.animation.sidebarSlideExit.type
                    easing.bezierCurve: root.animation.sidebarSlideExit.bezierCurve
                }
            }
        }
    }

    // Transparency. The quadratic functions were derived from analysis of
    // hand-picked transparency values upstream.
    readonly property real wallpaperVibrancy: wallColorQuant.colors[0]?.hslSaturation ?? 0.5
    readonly property real autoBackgroundTransparency: {
        let x = wallpaperVibrancy
        let y = 0.5768 * (x * x) - 0.759 * (x) + 0.2896
        return Math.max(0, Math.min(0.22, y)) - 0.12 * (m3colors.darkmode ? 0 : 1)
    }
    property real autoContentTransparency: 0.9
    property real backgroundTransparency: Config.options.appearance.transparency.enable
        ? (Config.options.appearance.transparency.automatic
            ? autoBackgroundTransparency
            : Config.options.appearance.transparency.backgroundTransparency)
        : 0
    property real contentTransparency: Config.options.appearance.transparency.automatic
        ? autoContentTransparency
        : Config.options.appearance.transparency.contentTransparency

    function getColorFromName(name) {
        switch (name) {
        case "primary":            return colors.colPrimary
        case "secondary":          return colors.colSecondary
        case "tertiary":           return colors.colTertiary
        case "primaryContainer":   return colors.colPrimaryContainer
        case "secondaryContainer": return colors.colSecondaryContainer
        case "tertiaryContainer":  return colors.colTertiaryContainer
        case "error":              return colors.colError
        case "layer0":             return colors.colLayer0
        case "layer1":             return colors.colLayer1
        case "layer0Border":       return colors.colLayer0Border
        case "black":              return "black"
        case "white":              return "white"
        default:                   return colors.colPrimaryContainer
        }
    }
}
