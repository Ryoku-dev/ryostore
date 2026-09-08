pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Ryoku.PluginKit
import Ryoku.Ui.Singletons

QtObject {
    id: root

    // ── Matugen Live Integration ──────────────────────────────────────────
    property var matugen: ({})

    function reloadMatugen() {
        try {
            var txt = colorsFile.text();
            if (txt && txt.trim().length > 0) {
                matugen = JSON.parse(txt) || {};
            }
        } catch(e) {
            matugen = {};
        }
    }

    readonly property color accentColor: (matugen && matugen.primary)
        ? matugen.primary
        : ((typeof Tokens !== "undefined" && Tokens && Tokens.sun) ? Tokens.sun : "#6E6A58")

    readonly property color brightColor: (matugen && matugen.onSurface)
        ? matugen.onSurface
        : ((typeof Tokens !== "undefined" && Tokens && Tokens.ink) ? Tokens.ink : "#ebdbb2")

    readonly property color dimColor: (matugen && matugen.onSurfaceVariant)
        ? matugen.onSurfaceVariant
        : ((typeof Tokens !== "undefined" && Tokens && Tokens.inkDim) ? Tokens.inkDim : "#F6F1DD")

    readonly property color cardTopColor: (matugen && matugen.surfaceContainerLow)
        ? matugen.surfaceContainerLow
        : ((typeof Tokens !== "undefined" && Tokens && Tokens.paperLift) ? Tokens.paperLift : "#141514")

    readonly property color cardBotColor: (matugen && matugen.surface)
        ? matugen.surface
        : ((typeof Tokens !== "undefined" && Tokens && Tokens.paper) ? Tokens.paper : "#0D0D0D")

    readonly property color tileBgColor: (matugen && matugen.surfaceContainer)
        ? matugen.surfaceContainer
        : ((matugen && matugen.primaryContainer) ? matugen.primaryContainer : "#1b1d1b")

    readonly property color hairColor: (matugen && matugen.outlineVariant)
        ? matugen.outlineVariant
        : ((typeof Tokens !== "undefined" && Tokens && Tokens.lineSoft) ? Tokens.lineSoft : Qt.rgba(brightColor.r, brightColor.g, brightColor.b, 0.15))

    readonly property string fontMain: "Space Grotesk"
    readonly property string fontMono: "JetBrainsMono Nerd Font"

    property QtObject colors: QtObject {
        property color colPrimary: root.accentColor
        property color colPrimaryHover: Qt.lighter(root.accentColor, 1.15)
        property color colPrimaryActive: Qt.darker(root.accentColor, 1.2)
        property color colPrimaryContainer: (root.matugen && root.matugen.primaryContainer)
            ? root.matugen.primaryContainer
            : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.18)
        property color colPrimaryContainerHover: Qt.lighter(colPrimaryContainer, 1.15)
        property color colPrimaryContainerActive: Qt.darker(colPrimaryContainer, 1.15)
        property color colOnPrimary: (root.matugen && root.matugen.onPrimary) ? root.matugen.onPrimary : "#0D0D0D"
        property color colOnPrimaryContainer: root.accentColor

        property color colSecondary: (root.matugen && root.matugen.secondary) ? root.matugen.secondary : root.dimColor
        property color colOnSecondary: (root.matugen && root.matugen.onSecondary) ? root.matugen.onSecondary : "#0D0D0D"
        property color colSecondaryContainer: root.tileBgColor
        property color colSecondaryContainerHover: Qt.lighter(root.tileBgColor, 1.15)
        property color colOnSecondaryContainer: root.brightColor

        property color colOnTertiary: (root.matugen && root.matugen.onTertiary) ? root.matugen.onTertiary : "#0D0D0D"
        property color colTertiary: (root.matugen && root.matugen.color12) ? root.matugen.color12 : "#a3850e"
        property color colTertiaryContainer: (root.matugen && root.matugen.surfaceContainerHigh) ? root.matugen.surfaceContainerHigh : Qt.rgba(0.85, 0.64, 0.25, 0.18)
        property color colTertiaryContainerHover: Qt.lighter(colTertiaryContainer, 1.15)
        property color colOnTertiaryContainer: root.brightColor

        property color colOnSurface: root.brightColor
        property color colOnSurfaceVariant: root.dimColor
        property color colSubtext: Qt.rgba(root.dimColor.r, root.dimColor.g, root.dimColor.b, 0.75)
        property color colOutline: (root.matugen && root.matugen.outline) ? root.matugen.outline : root.hairColor
        property color colOutlineVariant: root.hairColor

        property color colSurfaceContainer: root.tileBgColor
        property color colSurfaceContainerLow: root.cardTopColor
        property color colSurfaceContainerHigh: (root.matugen && root.matugen.surfaceContainerHigh) ? root.matugen.surfaceContainerHigh : root.tileBgColor
        property color colSurfaceContainerHighest: (root.matugen && root.matugen.surfaceContainerHighest) ? root.matugen.surfaceContainerHighest : root.cardBotColor
        property color colSurfaceContainerHighestHover: Qt.lighter(colSurfaceContainerHighest, 1.15)
        property color colSurfaceContainerHighestActive: Qt.darker(colSurfaceContainerHighest, 1.1)

        property color colLayer0: root.cardBotColor
        property color colLayer0Base: root.cardBotColor
        property color colLayer1: root.cardTopColor
        property color colLayer1Base: root.cardTopColor
        property color colLayer1Hover: Qt.lighter(root.cardTopColor, 1.15)
        property color colLayer1Active: Qt.darker(root.cardTopColor, 1.15)
        property color colLayer2: root.tileBgColor
        property color colLayer2Base: root.tileBgColor
        property color colLayer2Hover: Qt.lighter(root.tileBgColor, 1.12)
        property color colLayer2Active: Qt.darker(root.tileBgColor, 1.18)
        property color colLayer3: root.cardTopColor
        property color colLayer3Base: root.cardTopColor
        property color colLayer3Hover: Qt.lighter(root.cardTopColor, 1.1)
        property color colLayer3Active: Qt.darker(root.cardTopColor, 1.1)
        property color colLayer4: root.cardBotColor
        property color colLayer4Base: root.cardBotColor
        property color colLayer4Hover: Qt.lighter(root.cardBotColor, 1.15)
        property color colLayer4Active: Qt.darker(root.cardBotColor, 1.1)

        property color colError: (root.matugen && root.matugen.error) ? root.matugen.error : "#D35F5F"
        property color colErrorHover: Qt.lighter(colError, 1.15)
        property color colErrorContainer: (root.matugen && root.matugen.errorContainer) ? root.matugen.errorContainer : "#1b1d1b"
        property color colErrorContainerHover: Qt.lighter(colErrorContainer, 1.15)
        property color colOnError: (root.matugen && root.matugen.onError) ? root.matugen.onError : "#0D0D0D"
        property color colOnErrorContainer: colError
    }

    property QtObject animationCurves: QtObject {
        property var standard: [0.2, 0.0, 0, 1.0]
        property var expressiveDefaultSpatial: [0.34, 0.80, 0.34, 1.00]
    }

    property QtObject m3colors: QtObject {
        property bool darkmode: true
        property color m3background: root.cardBotColor
        property color m3onBackground: root.brightColor
        property color m3surface: root.cardTopColor
        property color m3surfaceContainerLow: root.cardTopColor
        property color m3surfaceContainer: root.tileBgColor
        property color m3surfaceContainerHigh: root.tileBgColor
        property color m3onSurface: root.brightColor
        property color m3onSurfaceVariant: root.dimColor
        property color m3primary: root.accentColor
        property color m3primaryContainer: root.colors.colPrimaryContainer
        property color m3onPrimary: root.colors.colOnPrimary
        property color m3outline: root.hairColor
        property color m3outlineVariant: root.hairColor
    }

    property QtObject font: QtObject {
        property QtObject family: QtObject {
            property string main: root.fontMain
            property string mono: root.fontMono
            property string icon: "Material Symbols Outlined"
        }
        property QtObject pixelSize: QtObject {
            property int tiny: 9
            property int smallest: 10
            property int smaller: 11
            property int small: 12
            property int normal: 13
            property int large: 14
            property int larger: 16
            property int huge: 18
            property int monster: 22
        }
    }

    property QtObject rounding: QtObject {
        property real none: 0
        property real verysmall: 3
        property real small: 4
        property real normal: 6
        property real large: 8
        property real extraLarge: 10
        property real full: 999
        property real windowRounding: 10
    }

    property QtObject animation: QtObject {
        property QtObject elementMoveEnter: QtObject {
            property Component numberAnimation: Component {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
        }
        property QtObject elementMoveFast: QtObject {
            property Component numberAnimation: Component {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
            property Component colorAnimation: Component {
                ColorAnimation { duration: 120 }
            }
        }
        property QtObject clickBounce: QtObject {
            property Component numberAnimation: Component {
                NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
            }
        }
    }

    // ── File Watcher for Matugen colors.json ────────────────────────────────
    Component.onCompleted: {
        root.reloadMatugen();
    }

    // Direct binding helper: FileView with live watch on ~/.cache/ryoku/colors.json
    readonly property var colorsFile: FileView {
        path: (typeof Quickshell !== "undefined" && Quickshell.env && Quickshell.env("HOME") ? Quickshell.env("HOME") : Directories.home) + "/.cache/ryoku/colors.json"
        watchChanges: true
        onFileChanged: root.reloadMatugen()
        onLoaded: root.reloadMatugen()
    }
}
