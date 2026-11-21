pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Colours, type and motion.
//
// The island is a black object, the way the hardware is, so its palette is
// always the dark one. The accent follows your desktop: the platform's own
// palette, Matugen, Pywal/Wallust, the wallpaper, GTK, album art or a colour
// you pick.
Singleton {
    id: root

    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
    function lum(c) { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b; }
    function home(p) { return (p || "").replace(/^~/, Quickshell.env("HOME")); }
    function mix(a, b, t) { return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t); }

    // ═══════════════════════════ FONTS ═══════════════════════════
    readonly property string font: {
        const f = Config.s.font;
        if (f && f !== "auto") return f;
        const fams = Qt.fontFamilies();
        const want = ["SF Pro Display", "SF Pro Text", "SF Pro", "Inter Display", "Inter", "Inter Variable"];
        for (let i = 0; i < want.length; i++) if (fams.indexOf(want[i]) >= 0) return want[i];
        return "sans-serif";
    }
    readonly property string iconFont: "Material Symbols Rounded"

    // ═════════════════════ DESKTOP THEME SOURCES ═════════════════
    // GTK accent (GNOME 47+ accent-color). One read at start, then a monitor
    // that dies with the island.
    property string gtkAccent: ""
    function parseGtk(line) {
        const m = line.match(/^\s*accent-color:\s*'?([^']*)'?\s*$/);
        if (m) gtkAccent = m[1];
    }
    Process {
        running: true
        command: ["sh", "-c", "echo \"accent-color: $(gsettings get org.gnome.desktop.interface accent-color 2>/dev/null)\""]
        stdout: SplitParser { onRead: l => root.parseGtk(l) }
    }
    Process {
        running: true
        command: ["sh", "-c", "command -v gsettings >/dev/null || exit 0; " +
                  "if command -v setpriv >/dev/null; then exec setpriv --pdeathsig TERM -- gsettings monitor org.gnome.desktop.interface accent-color; " +
                  "else exec gsettings monitor org.gnome.desktop.interface accent-color; fi"]
        stdout: SplitParser { onRead: l => root.parseGtk(l) }
    }
    readonly property var gtkAccents: ({
        blue: "#3584e4", teal: "#2190a4", green: "#3a944a", yellow: "#c88800", orange: "#ed5b00",
        red: "#e62d42", pink: "#d56199", purple: "#9141ac", slate: "#6f8396"
    })

    // Pywal / Wallust
    property string walAccent: ""
    FileView {
        path: root.home("~/.cache/wal/colors.json")
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoadFailed: root.walAccent = ""
        onLoaded: root.walAccent = root.vivid(text())
    }
    function vivid(t) {
        try {
            const j = JSON.parse(t);
            let best = "", score = -1;
            for (let i = 1; i <= 6; i++) {
                const hex = j.colors && j.colors["color" + i];
                if (!hex) continue;
                const c = Qt.color(hex);
                const s = c.hslSaturation * (1 - Math.abs(c.hslLightness - 0.55));
                if (s > score) { score = s; best = hex; }
            }
            return best;
        } catch (e) { return ""; }
    }

    // Matugen (or any JSON with a "primary" colour). The island is dark, so
    // the dark scheme is read.
    property string matAccent: ""
    FileView {
        path: root.home(Config.s.matugenPath)
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoadFailed: root.matAccent = ""
        onLoaded: root.matAccent = root.parseMat(text())
    }
    function parseMat(t) {
        try {
            const j = JSON.parse(t);
            const pick = o => !o ? "" : typeof o === "string" ? o : (o.dark || o.default || o.color || "");
            const c = (j.colors && j.colors.dark && j.colors.dark.primary)
                   || (j.dark && j.dark.primary)
                   || (j.colors && pick(j.colors.primary))
                   || pick(j.primary) || pick(j.accent) || "";
            return typeof c === "string" ? c : "";
        } catch (e) { return ""; }
    }

    // Wallpaper: find the current image and pull its most vivid colour. The
    // probe is a shell process, so it only runs while something reads it.
    property string wallpaper: ""
    readonly property bool wallpaperWanted: Config.s.accentSource === "wallpaper" || Hub.settingsOpen
        || (Config.s.accentSource === "auto" && Platform.accent === "" && matAccent === "" && walAccent === "")
    Process {
        id: wallProc
        command: ["sh", "-c",
            "p=\"$1\"; " +
            "for t in swww awww; do [ -n \"$p\" ] && break; command -v $t >/dev/null || continue; " +
            "  p=$($t query 2>/dev/null | grep -o 'image: .*' | head -1 | cut -d' ' -f2-); done; " +
            "[ -z \"$p\" ] && p=$(" + Platform.wallpaperProbe + "); " +
            "[ -z \"$p\" ] && p=$(ps -o args= -C swaybg 2>/dev/null | grep -oE '(-i|--image) +[^ ]+' | head -1 | awk '{print $2}'); " +
            "[ -z \"$p\" ] && [ -f \"$HOME/.config/waypaper/config.ini\" ] && p=$(grep -E '^wallpaper *=' \"$HOME/.config/waypaper/config.ini\" | head -1 | sed -E 's/^[^=]*= *//'); " +
            "[ -z \"$p\" ] && [ -f \"$HOME/.cache/wal/wal\" ] && p=$(cat \"$HOME/.cache/wal/wal\"); " +
            "for f in \"$HOME/.cache/current_wallpaper\" \"$HOME/.current_wallpaper\" \"$HOME/.cache/wallpaper\"; do " +
            "  [ -z \"$p\" ] && [ -e \"$f\" ] && p=$(readlink -f \"$f\"); done; " +
            "case \"$p\" in \"~/\"*) p=\"$HOME/${p#\\~/}\";; esac; echo \"$p\"",
            "sh", root.home(Config.s.wallpaperPath)]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim();
                if (p !== "" && p !== root.wallpaper) root.wallpaper = p;
            }
        }
    }
    Timer {
        interval: 30000; repeat: true; triggeredOnStart: true
        running: root.wallpaperWanted
        onTriggered: wallProc.running = true
    }
    Connections { target: Config.s; function onWallpaperPathChanged() { if (root.wallpaperWanted) wallProc.running = true; } }
    ColorQuantizer {
        id: wallQuant
        source: root.wallpaperWanted && root.wallpaper !== "" && /\.(png|jpe?g|webp|bmp|gif|tiff?)$/i.test(root.wallpaper)
            ? "file://" + root.wallpaper : ""
        depth: 4
        rescaleSize: 96
    }
    readonly property string wallAccent: {
        const cs = wallQuant.colors;
        if (!cs || cs.length === 0) return "";
        let best = null, score = -1;
        for (let i = 0; i < cs.length; i++) {
            const c = cs[i];
            const s = c.hslSaturation * (1 - Math.abs(c.hslLightness - 0.5) * 1.4);
            if (s > score) { score = s; best = c; }
        }
        return best && best.hslSaturation > 0.12 ? best.toString() : "";
    }

    // ═══════════════════════════ ACCENT ══════════════════════════
    readonly property bool dark: true
    readonly property string origin: {
        const src = Config.s.accentSource === "hyprland" || Config.s.accentSource === "ryoku" ? "desktop" : Config.s.accentSource;
        if (src !== "auto") return src;
        if (Platform.accentFirst && Platform.accent !== "") return "desktop";
        if (matAccent !== "") return "matugen";
        if (walAccent !== "") return "wal";
        if (wallAccent !== "") return "wallpaper";
        if (gtkAccent !== "" && gtkAccent !== "blue") return "gtk";
        if (Platform.accent !== "") return "desktop";
        return "default";
    }
    readonly property string originLabel: ({
        desktop: Platform.accentLabel, matugen: "Matugen", wal: "Pywal / Wallust", wallpaper: "Wallpaper",
        gtk: "GTK accent", album: "Album art", custom: "Custom", default: "System blue"
    })[origin] || origin

    readonly property color rawAccent: {
        let c = "";
        switch (origin) {
        case "desktop": c = Platform.accent; break;
        case "matugen": c = matAccent; break;
        case "wal": c = walAccent; break;
        case "wallpaper": c = wallAccent; break;
        case "gtk": c = gtkAccents[gtkAccent] || ""; break;
        case "album": c = Hub.albumColorValid ? Hub.albumColor : ""; break;
        case "custom": c = Config.s.customAccent; break;
        }
        return c !== "" ? Qt.color(c) : "#0a84ff";
    }
    // keep it readable on black
    function tune(c) {
        if (c.hslSaturation < 0.08) return c;
        return Qt.hsla(c.hslHue, Math.max(0.5, c.hslSaturation), Math.min(0.72, Math.max(0.56, c.hslLightness)), 1);
    }
    readonly property color accentTarget: tune(rawAccent)
    readonly property color liveTarget: Config.s.albumTint && Hub.playing && Hub.albumColorValid ? tune(Hub.albumColor) : accentTarget

    property color accent: "#0a84ff"
    property color live: "#0a84ff"     // album-aware accent for media UI and glow
    onAccentTargetChanged: { a1.stop(); a1.from = accent; a1.to = accentTarget; a1.start(); }
    onLiveTargetChanged: { a2.stop(); a2.from = live; a2.to = liveTarget; a2.start(); }
    ColorAnimation { id: a1; target: root; property: "accent"; duration: 700; easing.type: Easing.InOutQuad }
    ColorAnimation { id: a2; target: root; property: "live"; duration: 900; easing.type: Easing.InOutQuad }
    Component.onCompleted: { accent = accentTarget; live = liveTarget; }

    readonly property color accentText: lum(accent) > 0.6 ? "#000000" : "#ffffff"

    // ═══════════════════════ SYSTEM COLOURS ══════════════════════
    readonly property color red:    "#ff453a"
    readonly property color orange: "#ff9f0a"
    readonly property color yellow: "#ffd60a"
    readonly property color green:  "#30d158"
    readonly property color teal:   "#40c8e0"
    readonly property color blue:   "#0a84ff"
    readonly property color indigo: "#5e5ce6"
    readonly property color purple: "#bf5af2"
    readonly property color pink:   "#ff375f"
    readonly property color gray:   "#8e8e93"
    // Control Center toggles: your accent, or the stock system colour
    function ccTint(stock) { return Config.s.ccAccent ? accent : stock; }

    readonly property color fg:      "#ffffff"
    readonly property color fg2:     Qt.rgba(235/255, 235/255, 245/255, 0.62)
    readonly property color fg3:     Qt.rgba(235/255, 235/255, 245/255, 0.32)
    readonly property color fill:    Qt.rgba(1, 1, 1, 0.08)
    readonly property color fill2:   Qt.rgba(1, 1, 1, 0.14)
    readonly property color fill3:   Qt.rgba(1, 1, 1, 0.22)
    readonly property color sep:     Qt.rgba(1, 1, 1, 0.10)
    readonly property color hairline: Qt.rgba(1, 1, 1, 0.07)
    readonly property color shadow:  Qt.rgba(0, 0, 0, 0.5)

    // Surfaces. The island is pure black; banners and Notification Center
    // cards are a step up so they separate from it and from dark wallpapers.
    readonly property color surface: "#000000"
    readonly property color card:    Qt.rgba(0.075, 0.075, 0.085, 0.97)
    readonly property color window:  Qt.rgba(0.06, 0.06, 0.07, 0.98)
    readonly property color group:   Qt.rgba(0.13, 0.13, 0.15, 1)

    // Liquid glass on controls (Settings -> Appearance)
    readonly property bool glass: Config.s.liquidGlass
    readonly property real glassStrength: Config.s.glassStrength

    // ═══════════════════════════ MOTION ══════════════════════════
    readonly property bool reduced: Config.s.motion === "reduced"
    readonly property real spring: ({ gentle: 3.0, balanced: 3.6, bouncy: 4.2, reduced: 7 })[Config.s.motion] || 3.6
    readonly property real damping: ({ gentle: 0.42, balanced: 0.30, bouncy: 0.21, reduced: 1.0 })[Config.s.motion] || 0.3
    readonly property int fast: reduced ? 1 : 180
    readonly property int med: reduced ? 1 : 300
}
