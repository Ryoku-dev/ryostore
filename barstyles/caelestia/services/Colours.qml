pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import shell.services as ShellServices
import "../config"
import "."
Singleton {
    id: root

    property bool showPreview
    property string scheme: ShellServices.Theme.namedScheme ? "ryoku" : (ShellServices.Theme.matchWallpaper ? "dynamic" : "default")
    property string flavour: "default"
    property string variant: "default"
    property real intensity: 1.0
    readonly property real maxIntensity: 2.0
    readonly property real intensityFraction: intensity / maxIntensity
    property string previewScheme: ""
    property string previewFlavour: ""
    property string previewVariant: ""
    readonly property bool light: showPreview ? previewLight : currentLight
    property bool currentLight: getLuminance(ShellServices.Theme.surface) >= 0.5
    property bool previewLight
    readonly property M3Palette palette: showPreview ? preview : current
    readonly property M3TPalette tPalette: M3TPalette {}
    readonly property M3Palette current: M3Palette {
        m3primary_paletteKeyColor: root.extraRole("primary_paletteKeyColor", ShellServices.Theme.primary)
        m3secondary_paletteKeyColor: root.extraRole("secondary_paletteKeyColor", ShellServices.Theme.secondary)
        m3tertiary_paletteKeyColor: root.extraRole("tertiary_paletteKeyColor", ShellServices.Theme.tertiary)
        m3neutral_paletteKeyColor: root.extraRole("neutral_paletteKeyColor", ShellServices.Theme.outline)
        m3neutral_variant_paletteKeyColor: root.extraRole("neutral_variant_paletteKeyColor", ShellServices.Theme.outlineVariant)
        m3background: root.extraRole("background", ShellServices.Theme.surface)
        m3onBackground: root.extraRole("onBackground", ShellServices.Theme.onSurface)
        m3surface: ShellServices.Theme.surface
        m3surfaceDim: root.extraRole("surfaceDim", ShellServices.Theme.surfaceContainerLowest)
        m3surfaceBright: root.extraRole("surfaceBright", ShellServices.Theme.surfaceContainerHighest)
        m3surfaceContainerLowest: ShellServices.Theme.surfaceContainerLowest
        m3surfaceContainerLow: ShellServices.Theme.surfaceContainerLow
        m3surfaceContainer: ShellServices.Theme.surfaceContainer
        m3surfaceContainerHigh: ShellServices.Theme.surfaceContainerHigh
        m3surfaceContainerHighest: ShellServices.Theme.surfaceContainerHighest
        m3onSurface: ShellServices.Theme.onSurface
        m3surfaceVariant: ShellServices.Theme.surfaceVariant
        m3onSurfaceVariant: ShellServices.Theme.onSurfaceVariant
        m3inverseSurface: ShellServices.Theme.inverseSurface
        m3inverseOnSurface: ShellServices.Theme.inverseOnSurface
        m3outline: ShellServices.Theme.outline
        m3outlineVariant: ShellServices.Theme.outlineVariant
        m3shadow: ShellServices.Theme.shadow
        m3scrim: ShellServices.Theme.scrim
        m3surfaceTint: ShellServices.Theme.surfaceTint
        m3primary: ShellServices.Theme.primary
        m3onPrimary: ShellServices.Theme.onPrimary
        m3primaryContainer: ShellServices.Theme.primaryContainer
        m3onPrimaryContainer: ShellServices.Theme.onPrimaryContainer
        m3inversePrimary: root.extraRole("inversePrimary", ShellServices.Theme.primaryContainer)
        m3secondary: ShellServices.Theme.secondary
        m3onSecondary: ShellServices.Theme.onSecondary
        m3secondaryContainer: ShellServices.Theme.secondaryContainer
        m3onSecondaryContainer: ShellServices.Theme.onSecondaryContainer
        m3tertiary: ShellServices.Theme.tertiary
        m3onTertiary: ShellServices.Theme.onTertiary
        m3tertiaryContainer: ShellServices.Theme.tertiaryContainer
        m3onTertiaryContainer: ShellServices.Theme.onTertiaryContainer
        m3error: ShellServices.Theme.error
        m3onError: ShellServices.Theme.onError
        m3errorContainer: ShellServices.Theme.errorContainer
        m3onErrorContainer: ShellServices.Theme.onErrorContainer
        m3success: root.extraRole("success", root.currentLight ? "#386a20" : "#b5ccba")
        m3onSuccess: root.extraRole("onSuccess", root.currentLight ? "#ffffff" : "#213528")
        m3successContainer: root.extraRole("successContainer", root.currentLight ? "#b8f397" : "#374b3e")
        m3onSuccessContainer: root.extraRole("onSuccessContainer", root.currentLight ? "#042100" : "#d1e9d6")
        m3primaryFixed: root.extraRole("primaryFixed", ShellServices.Theme.primaryContainer)
        m3primaryFixedDim: root.extraRole("primaryFixedDim", ShellServices.Theme.primary)
        m3onPrimaryFixed: root.extraRole("onPrimaryFixed", ShellServices.Theme.onPrimaryContainer)
        m3onPrimaryFixedVariant: root.extraRole("onPrimaryFixedVariant", ShellServices.Theme.onPrimaryContainer)
        m3secondaryFixed: root.extraRole("secondaryFixed", ShellServices.Theme.secondaryContainer)
        m3secondaryFixedDim: root.extraRole("secondaryFixedDim", ShellServices.Theme.secondary)
        m3onSecondaryFixed: root.extraRole("onSecondaryFixed", ShellServices.Theme.onSecondaryContainer)
        m3onSecondaryFixedVariant: root.extraRole("onSecondaryFixedVariant", ShellServices.Theme.onSecondaryContainer)
        m3tertiaryFixed: root.extraRole("tertiaryFixed", ShellServices.Theme.tertiaryContainer)
        m3tertiaryFixedDim: root.extraRole("tertiaryFixedDim", ShellServices.Theme.tertiary)
        m3onTertiaryFixed: root.extraRole("onTertiaryFixed", ShellServices.Theme.onTertiaryContainer)
        m3onTertiaryFixedVariant: root.extraRole("onTertiaryFixedVariant", ShellServices.Theme.onTertiaryContainer)
        term0: root.extraRole("color0", ShellServices.Theme.surfaceContainerLow)
        term1: root.extraRole("color1", ShellServices.Theme.error)
        term2: root.extraRole("color2", ShellServices.Theme.primary)
        term3: root.extraRole("color3", ShellServices.Theme.tertiary)
        term4: root.extraRole("color4", ShellServices.Theme.secondary)
        term5: root.extraRole("color5", ShellServices.Theme.primary)
        term6: root.extraRole("color6", ShellServices.Theme.secondary)
        term7: root.extraRole("color7", ShellServices.Theme.onSurface)
        term8: root.extraRole("color8", ShellServices.Theme.outline)
        term9: root.extraRole("color9", ShellServices.Theme.error)
        term10: root.extraRole("color10", ShellServices.Theme.primary)
        term11: root.extraRole("color11", ShellServices.Theme.tertiary)
        term12: root.extraRole("color12", ShellServices.Theme.secondary)
        term13: root.extraRole("color13", ShellServices.Theme.primary)
        term14: root.extraRole("color14", ShellServices.Theme.secondary)
        term15: root.extraRole("color15", ShellServices.Theme.onSurface)
    }
    readonly property M3Palette preview: M3Palette {}
    readonly property Transparency transparency: Transparency {}
    // Derived from the active scheme's light/dark mode instead of pixel-scanning the wallpaper.
    readonly property real wallLuminance: light ? 0.85 : 0.15
    property bool cooldownPending
    property real lastBaseTransparency
    property bool schemeLoaded: true

    // Resolves roles beyond Theme's 30 top-level properties from the same active Ryoku layer.
    function extraRole(key: string, fallback: color): color {
        const named = ShellServices.Theme.namedScheme;
        if (named) {
            const v = named[key];
            return (v !== undefined && String(v).length > 0) ? v : fallback;
        }
        if (ShellServices.Theme.matchWallpaper) {
            const r = ShellServices.Scheme.roles;
            const v = r ? r[key] : undefined;
            if (v !== undefined && String(v).length > 0)
                return v;
        }
        return fallback;
    }

    function getLuminance(c: color): real {
        if (c.r == 0 && c.g == 0 && c.b == 0)
            return 0;
        return Math.sqrt(0.299 * (c.r ** 2) + 0.587 * (c.g ** 2) + 0.114 * (c.b ** 2));
    }

    function alterColour(c: color, a: real, layer: int): color {
        const luminance = getLuminance(c);
        if (luminance <= 0)
            return Qt.alpha(c, a);

        const offset = (!light || layer == 1 ? 1 : -layer / 2) * (light ? 0.2 : 0.3) * (1 - transparency.base) * (1 + wallLuminance * (light ? (layer == 1 ? 3 : 1) : 2.5));
        const scale = (luminance + offset) / luminance;
        const r = Math.max(0, Math.min(1, c.r * scale));
        const g = Math.max(0, Math.min(1, c.g * scale));
        const b = Math.max(0, Math.min(1, c.b * scale));

        return Qt.rgba(r, g, b, a);
    }

    function layer(c: color, layer: var): color {
        if (!transparency.enabled)
            return c;

        return layer === 0 ? Qt.alpha(c, transparency.base) : alterColour(c, transparency.layers, layer ?? 1);
    }

    function on(c: color): color {
        if (c.hslLightness < 0.5)
            return Qt.hsla(c.hslHue, c.hslSaturation, 0.9, 1);
        return Qt.hsla(c.hslHue, c.hslSaturation, 0.1, 1);
    }

    function harmonizeWith(designColor: color, sourceColor: color): color {
        let fromHue = designColor.hslHue;
        let toHue = sourceColor.hslHue;

        let diff = toHue - fromHue;
        if (diff > 0.5) diff -= 1.0;
        else if (diff < -0.5) diff += 1.0;

        const cap = 15.0 / 360.0;
        let rotation = diff * 0.5;
        if (rotation > cap) rotation = cap;
        else if (rotation < -cap) rotation = -cap;

        let outputHue = fromHue + rotation;
        if (outputHue < 0) outputHue += 1.0;
        if (outputHue > 1) outputHue -= 1.0;

        return Qt.hsla(outputHue, designColor.hslSaturation, designColor.hslLightness, designColor.a);
    }

    function harmonize(designColor: color): color {
        return harmonizeWith(designColor, root.palette.m3primary);
    }

    function load(data: string, isPreview: bool): void {
        const raw = (data || "").trim();
        if (raw === "")
            return;

        const colours = isPreview ? preview : current;
        let scheme = null;
        try {
            scheme = JSON.parse(raw);
        } catch (e) {
            return;
        }

        if (!scheme || !scheme.colours)
            return;

        if (!isPreview) {
            root.scheme = (scheme.name || "").trim();
            root.flavour = (scheme.flavour || "").trim();
            root.variant = (scheme.variant || "").trim();
            root.currentLight = scheme.mode === "light";
            root.showPreview = false;

            const intensity = Number(scheme.intensity ?? NaN);
            root.intensity = Number.isFinite(intensity) ? Math.min(root.maxIntensity, Math.max(0, intensity)) : 1.0;
        } else {
            root.previewScheme = (scheme.name || "").trim();
            root.previewFlavour = (scheme.flavour || "").trim();
            root.previewVariant = (scheme.variant || "").trim();
            root.previewLight = scheme.mode === "light";
        }

        applyColours(colours, scheme.colours);

        if (!isPreview)
            root.schemeLoaded = true;
    }

    function loadRyoku(data: string): void {
        let palette = null;
        try {
            palette = JSON.parse((data || "").trim());
        } catch (e) {
            return;
        }
        if (!palette || !palette.surface)
            return;

        const colours = {};
        for (const [role, hex] of Object.entries(palette)) {
            const term = /^color(\d+)$/.exec(role);
            colours[term ? `term${term[1]}` : role] = String(hex).replace(/^#/, "");
        }
        const dark = getLuminance(Qt.color(palette.surface)) < 0.5;
        load(JSON.stringify({ name: "ryoku", flavour: "default", variant: "default", mode: dark ? "dark" : "light", colours: colours }), false);
    }

    /// Fold a scheme's `colours` into a palette. A file leaves the leading `#` off and names a
    /// terminal role plainly, so the role a palette holds is not the key the file uses.
    function applyColours(palette: M3Palette, colours: var): void {
        for (const [role, colour] of Object.entries(colours)) {
            const propName = role.startsWith("term") ? role : `m3${role}`;
            if (palette.hasOwnProperty(propName))
                palette[propName] = colour.startsWith("#") ? colour : `#${colour}`;
        }
    }

    function previewNamed(name: string, flavour: string, colours: var, light: bool): void {
        if (!colours)
            return;
        root.previewScheme = name;
        root.previewFlavour = flavour;
        root.previewVariant = root.variant;
        root.previewLight = light;
        applyColours(root.preview, colours);
        root.showPreview = true;
    }

    function clearPreview(): void {
        root.showPreview = false;
    }

    // Light and dark are the Hub's curated presets: the Hub writes the palette the
    // shell watches, so Theme and Scheme follow the change automatically.
    function setMode(mode: string): void {
        if (mode === "light" || mode === "dark")
            Quickshell.execDetached(["ryoku-hub", "desktop", "scheme", mode]);
    }

    // shortcut: the Ryoku palette has no intensity knob and reseeding is the theme
    // daemon's job, so these do nothing; wire them if the daemon grows the controls.
    function setIntensity(fraction: real): void {}

    function reseedScheme(): void {}

    function reloadHyprRules(): void {
        // Layer rules are Hyprland-only; KWin handles blur via effects.
        return;
    }

    function requestReloadHyprRules(): void {
        if (cooldownTimer.running) {
            root.cooldownPending = true;
        } else {
            root.reloadHyprRules();
            cooldownTimer.restart();
        }
    }

    Component.onCompleted: root.requestReloadHyprRules()

    Connections {
        function onConfigReloaded(): void {
            root.reloadHyprRules();
        }

        target: Kwin
    }

    Timer {
        id: cooldownTimer

        interval: 30
        onTriggered: {
            if (root.cooldownPending) {
                root.cooldownPending = false;
                root.reloadHyprRules();
                restart();
            }
        }
    }

    Timer {
        id: cAnimCompleteTimer

        interval: Tokens.anim.durations.expressiveSlowEffects
        onTriggered: root.requestReloadHyprRules()
    }

    component Transparency: QtObject {
        readonly property bool enabled: Tokens.transparency.enabled && !(GameMode.enabled && GlobalConfig.utilities.gameMode.disableShellTransparency)
        readonly property real base: Math.max(0, Math.min(1, Tokens.transparency.base - (root.light ? 0.1 : 0)))
        readonly property real layers: Math.max(0, Math.min(1, Tokens.transparency.layers))

        onEnabledChanged: {
            if (enabled)
                root.requestReloadHyprRules();
            else
                cAnimCompleteTimer.start();
        }
        onBaseChanged: {
            if (root.lastBaseTransparency > base)
                root.requestReloadHyprRules();
            else
                cAnimCompleteTimer.start();
            root.lastBaseTransparency = base;
        }
    }

    component M3TPalette: QtObject {
        readonly property color m3primary_paletteKeyColor: root.layer(root.palette.m3primary_paletteKeyColor, 1)
        readonly property color m3secondary_paletteKeyColor: root.layer(root.palette.m3secondary_paletteKeyColor, 1)
        readonly property color m3tertiary_paletteKeyColor: root.layer(root.palette.m3tertiary_paletteKeyColor, 1)
        readonly property color m3neutral_paletteKeyColor: root.layer(root.palette.m3neutral_paletteKeyColor, 1)
        readonly property color m3neutral_variant_paletteKeyColor: root.layer(root.palette.m3neutral_variant_paletteKeyColor, 1)
        readonly property color m3background: root.layer(root.palette.m3background, 0)
        readonly property color m3onBackground: root.layer(root.palette.m3onBackground, 1)
        readonly property color m3surface: root.layer(root.palette.m3surface, 0)
        readonly property color m3surfaceDim: root.layer(root.palette.m3surfaceDim, 0)
        readonly property color m3surfaceBright: root.layer(root.palette.m3surfaceBright, 0)
        readonly property color m3surfaceContainerLowest: root.layer(root.palette.m3surfaceContainerLowest, 1)
        readonly property color m3surfaceContainerLow: root.layer(root.palette.m3surfaceContainerLow, 1)
        readonly property color m3surfaceContainer: root.layer(root.palette.m3surfaceContainer, 1)
        readonly property color m3surfaceContainerHigh: root.layer(root.palette.m3surfaceContainerHigh, 1)
        readonly property color m3surfaceContainerHighest: root.layer(root.palette.m3surfaceContainerHighest, 1)
        readonly property color m3onSurface: root.layer(root.palette.m3onSurface, 1)
        readonly property color m3surfaceVariant: root.layer(root.palette.m3surfaceVariant, 0)
        readonly property color m3onSurfaceVariant: root.layer(root.palette.m3onSurfaceVariant, 1)
        readonly property color m3inverseSurface: root.layer(root.palette.m3inverseSurface, 0)
        readonly property color m3inverseOnSurface: root.layer(root.palette.m3inverseOnSurface, 1)
        readonly property color m3outline: root.layer(root.palette.m3outline, 1)
        readonly property color m3outlineVariant: root.layer(root.palette.m3outlineVariant, 1)
        readonly property color m3shadow: root.layer(root.palette.m3shadow, 1)
        readonly property color m3scrim: root.layer(root.palette.m3scrim, 1)
        readonly property color m3surfaceTint: root.layer(root.palette.m3surfaceTint, 1)
        readonly property color m3primary: root.layer(root.palette.m3primary, 1)
        readonly property color m3onPrimary: root.layer(root.palette.m3onPrimary, 1)
        readonly property color m3primaryContainer: root.layer(root.palette.m3primaryContainer, 1)
        readonly property color m3onPrimaryContainer: root.layer(root.palette.m3onPrimaryContainer, 1)
        readonly property color m3inversePrimary: root.layer(root.palette.m3inversePrimary, 1)
        readonly property color m3secondary: root.layer(root.palette.m3secondary, 1)
        readonly property color m3onSecondary: root.layer(root.palette.m3onSecondary, 1)
        readonly property color m3secondaryContainer: root.layer(root.palette.m3secondaryContainer, 1)
        readonly property color m3onSecondaryContainer: root.layer(root.palette.m3onSecondaryContainer, 1)
        readonly property color m3tertiary: root.layer(root.palette.m3tertiary, 1)
        readonly property color m3onTertiary: root.layer(root.palette.m3onTertiary, 1)
        readonly property color m3tertiaryContainer: root.layer(root.palette.m3tertiaryContainer, 1)
        readonly property color m3onTertiaryContainer: root.layer(root.palette.m3onTertiaryContainer, 1)
        readonly property color m3error: root.layer(root.palette.m3error, 1)
        readonly property color m3onError: root.layer(root.palette.m3onError, 1)
        readonly property color m3errorContainer: root.layer(root.palette.m3errorContainer, 1)
        readonly property color m3onErrorContainer: root.layer(root.palette.m3onErrorContainer, 1)
        readonly property color m3success: root.layer(root.palette.m3success, 1)
        readonly property color m3onSuccess: root.layer(root.palette.m3onSuccess, 1)
        readonly property color m3successContainer: root.layer(root.palette.m3successContainer, 1)
        readonly property color m3onSuccessContainer: root.layer(root.palette.m3onSuccessContainer, 1)
        readonly property color m3primaryFixed: root.layer(root.palette.m3primaryFixed, 1)
        readonly property color m3primaryFixedDim: root.layer(root.palette.m3primaryFixedDim, 1)
        readonly property color m3onPrimaryFixed: root.layer(root.palette.m3onPrimaryFixed, 1)
        readonly property color m3onPrimaryFixedVariant: root.layer(root.palette.m3onPrimaryFixedVariant, 1)
        readonly property color m3secondaryFixed: root.layer(root.palette.m3secondaryFixed, 1)
        readonly property color m3secondaryFixedDim: root.layer(root.palette.m3secondaryFixedDim, 1)
        readonly property color m3onSecondaryFixed: root.layer(root.palette.m3onSecondaryFixed, 1)
        readonly property color m3onSecondaryFixedVariant: root.layer(root.palette.m3onSecondaryFixedVariant, 1)
        readonly property color m3tertiaryFixed: root.layer(root.palette.m3tertiaryFixed, 1)
        readonly property color m3tertiaryFixedDim: root.layer(root.palette.m3tertiaryFixedDim, 1)
        readonly property color m3onTertiaryFixed: root.layer(root.palette.m3onTertiaryFixed, 1)
        readonly property color m3onTertiaryFixedVariant: root.layer(root.palette.m3onTertiaryFixedVariant, 1)
    }

    component M3Palette: QtObject {
        property color m3primary_paletteKeyColor: "#a8627b"
        property color m3secondary_paletteKeyColor: "#8e6f78"
        property color m3tertiary_paletteKeyColor: "#986e4c"
        property color m3neutral_paletteKeyColor: "#807477"
        property color m3neutral_variant_paletteKeyColor: "#837377"
        property color m3background: "#191114"
        property color m3onBackground: "#efdfe2"
        property color m3surface: "#191114"
        property color m3surfaceDim: "#191114"
        property color m3surfaceBright: "#403739"
        property color m3surfaceContainerLowest: "#130c0e"
        property color m3surfaceContainerLow: "#22191c"
        property color m3surfaceContainer: "#261d20"
        property color m3surfaceContainerHigh: "#31282a"
        property color m3surfaceContainerHighest: "#3c3235"
        property color m3onSurface: "#efdfe2"
        property color m3surfaceVariant: "#514347"
        property color m3onSurfaceVariant: "#d5c2c6"
        property color m3inverseSurface: "#efdfe2"
        property color m3inverseOnSurface: "#372e30"
        property color m3outline: "#9e8c91"
        property color m3outlineVariant: "#514347"
        property color m3shadow: "#000000"
        property color m3scrim: "#000000"
        property color m3surfaceTint: "#ffb0ca"
        property color m3primary: "#ffb0ca"
        property color m3onPrimary: "#541d34"
        property color m3primaryContainer: "#6f334a"
        property color m3onPrimaryContainer: "#ffd9e3"
        property color m3inversePrimary: "#8b4a62"
        property color m3secondary: "#e2bdc7"
        property color m3onSecondary: "#422932"
        property color m3secondaryContainer: "#5a3f48"
        property color m3onSecondaryContainer: "#ffd9e3"
        property color m3tertiary: "#f0bc95"
        property color m3onTertiary: "#48290c"
        property color m3tertiaryContainer: "#b58763"
        property color m3onTertiaryContainer: "#000000"
        property color m3error: "#ffb4ab"
        property color m3onError: "#690005"
        property color m3errorContainer: "#93000a"
        property color m3onErrorContainer: "#ffdad6"
        property color m3success: "#B5CCBA"
        property color m3onSuccess: "#213528"
        property color m3successContainer: "#374B3E"
        property color m3onSuccessContainer: "#D1E9D6"
        property color m3primaryFixed: "#ffd9e3"
        property color m3primaryFixedDim: "#ffb0ca"
        property color m3onPrimaryFixed: "#39071f"
        property color m3onPrimaryFixedVariant: "#6f334a"
        property color m3secondaryFixed: "#ffd9e3"
        property color m3secondaryFixedDim: "#e2bdc7"
        property color m3onSecondaryFixed: "#2b151d"
        property color m3onSecondaryFixedVariant: "#5a3f48"
        property color m3tertiaryFixed: "#ffdcc3"
        property color m3tertiaryFixedDim: "#f0bc95"
        property color m3onTertiaryFixed: "#2f1500"
        property color m3onTertiaryFixedVariant: "#623f21"
        property color term0: "#353434"
        property color term1: "#ff4c8a"
        property color term2: "#ffbbb7"
        property color term3: "#ffdedf"
        property color term4: "#b3a2d5"
        property color term5: "#e98fb0"
        property color term6: "#ffba93"
        property color term7: "#eed1d2"
        property color term8: "#b39e9e"
        property color term9: "#ff80a3"
        property color term10: "#ffd3d0"
        property color term11: "#fff1f0"
        property color term12: "#dcbc93"
        property color term13: "#f9a8c2"
        property color term14: "#ffd1c0"
        property color term15: "#ffffff"
    }
}
