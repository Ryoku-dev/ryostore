pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Ricelin palette bridge for Ryoku.
 *
 * This intentionally follows the same resolution chain as QSBar:
 *   named themePalette -> live ~/.cache/ryoku/colors.json (when
 *   theme.json says followWallpaper=true) -> built-in fallback.
 *
 * The live palette is watched, so a Matugen/wallpaper change retints the pill
 * without restarting Quickshell. Ricelin no longer consumes its old
 * ~/.cache/ricelin/colors.json palette.
 */
Singleton {
    id: root

    readonly property string colorsPath: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/ryoku/colors.json"
    readonly property string shellConfigPath: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/shell.json"
    readonly property string themeJsonPath: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/theme.json"

    property var wall: ({})
    property var named: null
    property bool followWallpaper: true

    function lowerKeys(obj) {
        var out = {};
        if (obj && typeof obj === "object") {
            for (var k in obj)
                out[String(k).toLowerCase()] = obj[k];
        }
        return out;
    }

    function parseObject(text) {
        try {
            var value = JSON.parse(text || "");
            return (value && typeof value === "object") ? lowerKeys(value) : {};
        } catch (e) {
            return {};
        }
    }

    function parseNamed(text) {
        var obj = parseObject(text);
        return (obj && obj.themepalette && typeof obj.themepalette === "object")
            ? lowerKeys(obj.themepalette) : null;
    }

    function parseFollow(text) {
        try {
            var obj = JSON.parse(text || "");
            return (obj && typeof obj.followWallpaper === "boolean") ? obj.followWallpaper : true;
        } catch (e) {
            return true;
        }
    }

    function valid(value) {
        return typeof value === "string" && /^#([0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$/.test(value);
    }

    // Accept both Matugen/Ryoku snake_case names and camelCase names.
    function pick(source, keys, fallback) {
        if (source) {
            for (var i = 0; i < keys.length; ++i) {
                var key = String(keys[i]).toLowerCase();
                var value = source[key];
                if (valid(value))
                    return value;
            }
        }
        return fallback;
    }

    function resolve(keys, fallback) {
        var value = pick(named, keys, null);
        if (!value && followWallpaper)
            value = pick(wall, keys, null);
        return value || fallback;
    }

    // Material roles used by the original Ricelin pill.
    readonly property string surface: resolve(["surface"], "#181616")
    readonly property string surfaceContainer: resolve(["surface_container", "surfacecontainer"], "#211b13")
    readonly property string surfaceContainerLow: resolve(["surface_container_low", "surfacecontainerlow"], "#211b13")
    readonly property string surfaceContainerHigh: resolve(["surface_container_high", "surfacecontainerhigh"], "#302921")
    readonly property string surfaceContainerHighest: resolve(["surface_container_highest", "surfacecontainerhighest"], "#3b342b")
    readonly property string primary: resolve(["primary", "color1", "red"], "#c4746e")
    readonly property string primaryContainer: resolve(["primary_container", "primarycontainer"], "#633f00")
    readonly property string onPrimaryContainer: resolve(["on_primary_container", "onprimarycontainer"], "#ffddb3")
    readonly property string outline: resolve(["outline"], "#9c8f80")
    readonly property string outlineVariant: resolve(["outline_variant", "outlinevariant"], "#4f4539")

    // Text/secondary families. Prefer the Material roles exactly as the Hub does,
    // then the terminal palette equivalents for compatibility with older files.
    readonly property string cream: resolve(["on_surface", "onsurface", "foreground", "fg", "color7"], "#c5c9c5")
    readonly property string bright: resolve(["on_surface", "onsurface", "foreground", "fg", "color15", "color7"], "#fff6f0")
    readonly property string subtle: resolve(["on_surface_variant", "onsurfacevariant", "color7", "bright_fg", "light_fg"], "#b9a99e")
    readonly property string dim: resolve(["outline", "color8", "muted", "dark_fg"], "#8a7d74")
    readonly property string faint: resolve(["outline_variant", "outlinevariant", "color8", "muted", "dark_fg"], "#6f635b")
    readonly property string iconDim: resolve(["on_surface_variant", "onsurfacevariant", "color7"], "#cdbfb4")
    readonly property string tickRest: resolve(["on_surface_variant", "onsurfacevariant", "color7"], "#cbb6a3")

    FileView {
        id: paletteFile
        path: root.colorsPath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.wall = root.parseObject(paletteFile.text())
    }

    FileView {
        id: shellFile
        path: root.shellConfigPath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.named = root.parseNamed(shellFile.text())
    }

    FileView {
        id: themeFile
        path: root.themeJsonPath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.followWallpaper = root.parseFollow(themeFile.text())
    }
}
