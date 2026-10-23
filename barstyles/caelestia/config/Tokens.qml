pragma Singleton

import QtQuick
import Quickshell
import "FontBuilder.js" as FB

// What the plugin's attached Tokens gave: the scaled appearance values, the size tokens,
// the fonts and the animation curves.
// shortcut: one global layer, like GlobalConfig; Tokens.screen is gone with the per-screen layers.
Singleton {
    id: root

    readonly property QtObject rounding: GlobalConfig.appearance.rounding
    readonly property QtObject spacing: GlobalConfig.appearance.spacing
    readonly property QtObject padding: GlobalConfig.appearance.padding
    readonly property QtObject transparency: GlobalConfig.appearance.transparency
    readonly property QtObject sizes: TokenConfig.sizes

    readonly property QtObject font: QtObject {
        readonly property real scale: GlobalConfig.appearance.font.scale

        readonly property FontStyle headline: FontStyle { cfg: GlobalConfig.appearance.font.headline; scale: root.font.scale }
        readonly property FontStyle title: FontStyle { cfg: GlobalConfig.appearance.font.title; scale: root.font.scale }
        readonly property FontStyle body: FontStyle { cfg: GlobalConfig.appearance.font.body; scale: root.font.scale }
        readonly property FontStyle label: FontStyle { cfg: GlobalConfig.appearance.font.label; scale: root.font.scale }
        readonly property FontStyle mono: FontStyle { cfg: GlobalConfig.appearance.font.mono; scale: root.font.scale }
        readonly property FontStyle icon: FontStyle { cfg: GlobalConfig.appearance.font.icon; scale: root.font.scale }
        readonly property var clock: FB.make({ family: GlobalConfig.appearance.font.clock, variableAxes: {} })
        readonly property string workspaces: GlobalConfig.appearance.font.workspaces
    }

    readonly property QtObject anim: QtObject {
        readonly property QtObject durations: GlobalConfig.appearance.anim.durations

        readonly property var emphasized: root.curve(TokenConfig.appearance.curves.emphasized)
        readonly property var emphasizedAccel: root.curve(TokenConfig.appearance.curves.emphasizedAccel)
        readonly property var emphasizedDecel: root.curve(TokenConfig.appearance.curves.emphasizedDecel)
        readonly property var standard: root.curve(TokenConfig.appearance.curves.standard)
        readonly property var standardAccel: root.curve(TokenConfig.appearance.curves.standardAccel)
        readonly property var standardDecel: root.curve(TokenConfig.appearance.curves.standardDecel)
        readonly property var expressiveFastSpatial: root.curve(TokenConfig.appearance.curves.expressiveFastSpatial)
        readonly property var expressiveDefaultSpatial: root.curve(TokenConfig.appearance.curves.expressiveDefaultSpatial)
        readonly property var expressiveSlowSpatial: root.curve(TokenConfig.appearance.curves.expressiveSlowSpatial)
        readonly property var expressiveFastEffects: root.curve(TokenConfig.appearance.curves.expressiveFastEffects)
        readonly property var expressiveDefaultEffects: root.curve(TokenConfig.appearance.curves.expressiveDefaultEffects)
        readonly property var expressiveSlowEffects: root.curve(TokenConfig.appearance.curves.expressiveSlowEffects)
    }

    // AnimTokens::buildCurve: whole cubic segments of six points each
    function curve(points: var): var {
        return {
            type: Easing.BezierSpline,
            bezierCurve: points.slice(0, points.length - points.length % 6)
        };
    }

    function forScreen(screen: string): QtObject {
        return TokenConfig;
    }
}
