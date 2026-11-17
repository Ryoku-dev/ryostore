pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Persistent settings. Edited live from the Island's own settings window
// (SUPER+, or the gear), stored under ~/.config/ryoku/dynamic-island/settings.json.
// You can also hand-edit the JSON; changes are picked up instantly.
Singleton {
    id: root

    readonly property string dir: (Quickshell.env("XDG_CONFIG_HOME")
        || (Quickshell.env("HOME") + "/.config")) + "/ryoku/dynamic-island"
    readonly property string iconFont: "Material Symbols Rounded"

    property alias s: adapter
    property bool resetting: false

    // Upstream reset deleted the file and reloaded the whole Quickshell
    // instance; here that would reload the entire Ryoku shell. Instead every
    // default is mirrored below and applied in place.
    function reset() {
        resetting = true;
        const d = defaults;
        for (const k in d) {
            try { adapter[k] = d[k]; } catch (e) {}
        }
        resetting = false;
        file.writeAdapter();
    }

    // Mirrors every JsonAdapter default above; keep the two lists in sync.
    readonly property var defaults: ({
        style: "glass", appearance: "auto", glassOpacity: 0.55, glassRim: true,
        glassAccentTint: true, glow: true, accentSource: "auto",
        customAccent: "#0a84ff", matugenPath: "~/.cache/matugen/colors.json",
        wallpaperPath: "", albumTint: true, font: "auto",
        overlayBar: true, reserveSpace: true, topMargin: 6, outerGaps: 16,
        motion: "balanced", use24h: false, showAmPm: false, showSeconds: false,
        showBattery: true, showPrivacy: true, workspaceFlash: true,
        splitActivities: true, activityClock: "split", hoverPeek: true, hoverDelay: 260,
        visualizer: true, trackChangePeek: true, spinArt: true,
        notifications: true, notifStyle: "banner", bannerTimeout: 5,
        previews: "always", notifSound: false, soundFile: "/usr/share/sounds/freedesktop/stereo/message.oga",
        groupByApp: true, dndAllowCritical: true,
        weather: true, locationMode: "auto", manualLat: 0, manualLon: 0,
        manualName: "", units: "metric",
        ccAccent: true, nightLightTemp: 4000, osdPopups: false, osdTimeout: 1600, confirmPower: true
    })

    FileView {
        id: file
        path: root.dir + "/settings.json"
        watchChanges: true
        blockLoading: true
        printErrors: false
        onFileChanged: reload()
        onAdapterUpdated: if (!root.resetting) writeAdapter()
        onLoadFailed: err => {
            // first run → write defaults
            if (!root.resetting) writeAdapter();
        }

        JsonAdapter {
            id: adapter

            // ── Appearance ──
            property string style: "glass"          // glass | black
            property string appearance: "auto"      // auto | dark | light
            property real glassOpacity: 0.55        // tint strength behind the blur
            property bool glassRim: true            // liquid-glass specular edge
            property bool glassAccentTint: true     // mix a hint of the accent into the glass
            property bool glow: true
            property string accentSource: "auto"    // auto | wallpaper | wal | matugen | ryoku | gtk | album | custom
            property string customAccent: "#0a84ff"
            property string matugenPath: "~/.cache/matugen/colors.json"
            property string wallpaperPath: ""       // empty = detect (swww, hyprpaper, swaybg, waypaper…)
            property bool albumTint: true           // tint island with album colour while music plays
            property string font: "auto"            // auto = SF Pro if installed, else Inter

            // ── Island ──
            property bool overlayBar: true
            property bool reserveSpace: true        // push maximized/tiled windows below the island (bar-like)
            property int topMargin: 6
            property int outerGaps: 16              // the compositor's outer gaps; trims the reserved strip
            property string motion: "balanced"      // gentle | balanced | bouncy | reduced
            property bool use24h: false
            property bool showAmPm: false
            property bool showSeconds: false
            property bool showBattery: true
            property bool showPrivacy: true
            property bool workspaceFlash: true
            property bool splitActivities: true     // iOS-style second bubble
            property string activityClock: "split"  // split | inline | hidden — the time while music/timers run
            property bool hoverPeek: true
            property int hoverDelay: 260

            // ── Media ──
            property bool visualizer: true
            property bool trackChangePeek: true
            property bool spinArt: true

            // ── Notifications ──
            // The Ryoku shell owns the freedesktop notification daemon, so the
            // island wraps the shell's server instead of running its own.
            property bool notifications: true       // island takes the banner display over from the shell
            property string notifStyle: "banner"    // banner | island | corner
            property int bannerTimeout: 5
            property string previews: "always"      // always | never
            property bool notifSound: false         // the shell already plays its own cue
            property string soundFile: "/usr/share/sounds/freedesktop/stereo/message.oga"
            property bool groupByApp: true
            property bool dndAllowCritical: true    // critical banners pass through the shell's own Focus

            // ── Weather + location ──
            property bool weather: true
            property string locationMode: "auto"    // auto (GeoClue → IP) | ip | manual
            property real manualLat: 0
            property real manualLon: 0
            property string manualName: ""
            property string units: "metric"         // metric | imperial

            // ── Controls ──
            property bool ccAccent: true            // Control Center toggles use your theme accent
            property int nightLightTemp: 4000       // Night Shift temperature (K), applied to the shell's Nightlight
            property bool osdPopups: false          // island volume/mic/brightness pills (the shell draws its own OSD)
            property int osdTimeout: 1600
            property bool confirmPower: true
        }
    }
}
