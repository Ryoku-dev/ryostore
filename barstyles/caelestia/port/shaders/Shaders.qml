pragma Singleton

import QtQuick
import Quickshell
import "../../config"

Singleton {
    readonly property var crossfade: transition("crossfade")
    readonly property var chromaticBloom: crossfade
    readonly property var colourDistance: crossfade
    readonly property var crosshatch: crossfade
    readonly property var crosswarp: crossfade
    readonly property var directional: crossfade
    readonly property var directionalWipe: crossfade
    readonly property var fadeColour: crossfade
    readonly property var glitch: crossfade
    readonly property var glitchDisplace: crossfade
    readonly property var heatMelt: crossfade
    readonly property var inkSplash: crossfade
    readonly property var inkwellDrop: crossfade
    readonly property var iris: crossfade
    readonly property var morph: crossfade
    readonly property var parametricGlitch: crossfade
    readonly property var perlin: crossfade
    readonly property var pixelate: crossfade
    readonly property var pixelfadeWave: crossfade
    readonly property var plasmaFlow: crossfade
    readonly property var polkaDotsCurtain: crossfade
    readonly property var puzzleRight: crossfade
    readonly property var randomSquares: crossfade
    readonly property var smoke: crossfade
    readonly property var softWarpFade: crossfade
    readonly property var voronoiShatter: crossfade
    readonly property var zoomBlurPull: crossfade

    function transition(name: string): var {
        return {
            url: Qt.resolvedUrl("crossfade.frag.qsb"),
            duration: Tokens.anim.durations.large,
            easing: Tokens.anim.expressiveSlowEffects
        };
    }
}
