pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Persistent settings, edited live from the Settings window and stored as
// settings.json in Platform.configDir. Hand edits are picked up instantly.
//
// `base` is the single list of defaults: the adapter below binds to it, Reset
// applies it in place, and each platform may override a few entries
// (Platform.configDefaults) where its desktop already does the job.
Singleton {
    id: root

    readonly property string version: "4.0.0"
    readonly property string dir: Platform.configDir

    property alias s: adapter
    property bool resetting: false

    readonly property var base: ({
        // appearance
        liquidGlass: true,           // liquid glass on buttons, chips and toggles
        glassStrength: 1.0,          // refraction + rim, 0.4..1.6
        glow: true,
        accentSource: "auto",        // auto | desktop | matugen | wal | wallpaper | gtk | album | custom
        customAccent: "#0a84ff",
        matugenPath: "~/.cache/matugen/colors.json",
        wallpaperPath: "",
        albumTint: true,
        font: "auto",
        // island
        overlayBar: true,
        reserveSpace: true,
        topMargin: 6,
        outerGaps: 16,
        motion: "balanced",          // gentle | balanced | bouncy | reduced
        use24h: false,
        showAmPm: false,
        showSeconds: false,
        showBattery: true,
        showPrivacy: true,
        workspaceFlash: true,
        splitActivities: true,
        activityClock: "split",      // split | inline | hidden
        hoverPeek: true,
        hoverDelay: 260,
        // tray
        trayInHeader: 3,             // icons shown next to the tabs before "+N"
        // media
        visualizer: true,
        trackChangePeek: true,
        spinArt: false,
        // notifications
        notifications: true,
        takeover: true,
        notifStyle: "banner",        // banner | island | corner
        bannerTimeout: 5,
        urgentTimeout: 12,           // seconds an urgent banner stays
        urgentSticky: false,         // keep urgent banners until dismissed
        previews: "always",
        notifSound: true,
        soundFile: "/usr/share/sounds/freedesktop/stereo/message.oga",
        groupByApp: true,
        dnd: false,
        dndAllowCritical: true,
        // weather
        weather: true,
        locationMode: "auto",        // auto | ip | manual
        manualLat: 0,
        manualLon: 0,
        manualName: "",
        units: "metric",
        // controls
        ccAccent: true,
        nightLightTemp: 4000,
        osdPopups: true,
        osdTimeout: 1600,
        confirmPower: true
    })
    readonly property var defaults: Object.assign({}, base, Platform.configDefaults || {})

    function reset() {
        resetting = true;
        const d = defaults;
        for (const k in d) {
            try { adapter[k] = d[k]; } catch (e) {}
        }
        resetting = false;
        file.writeAdapter();
    }

    FileView {
        id: file
        path: root.dir + "/settings.json"
        watchChanges: true
        blockLoading: true
        printErrors: false
        onFileChanged: reload()
        onAdapterUpdated: if (!root.resetting) writeAdapter()
        onLoadFailed: err => { if (!root.resetting) writeAdapter(); }   // first run: write defaults

        JsonAdapter {
            id: adapter
            property bool liquidGlass: root.defaults.liquidGlass
            property real glassStrength: root.defaults.glassStrength
            property bool glow: root.defaults.glow
            property string accentSource: root.defaults.accentSource
            property string customAccent: root.defaults.customAccent
            property string matugenPath: root.defaults.matugenPath
            property string wallpaperPath: root.defaults.wallpaperPath
            property bool albumTint: root.defaults.albumTint
            property string font: root.defaults.font

            property bool overlayBar: root.defaults.overlayBar
            property bool reserveSpace: root.defaults.reserveSpace
            property int topMargin: root.defaults.topMargin
            property int outerGaps: root.defaults.outerGaps
            property string motion: root.defaults.motion
            property bool use24h: root.defaults.use24h
            property bool showAmPm: root.defaults.showAmPm
            property bool showSeconds: root.defaults.showSeconds
            property bool showBattery: root.defaults.showBattery
            property bool showPrivacy: root.defaults.showPrivacy
            property bool workspaceFlash: root.defaults.workspaceFlash
            property bool splitActivities: root.defaults.splitActivities
            property string activityClock: root.defaults.activityClock
            property bool hoverPeek: root.defaults.hoverPeek
            property int hoverDelay: root.defaults.hoverDelay

            property int trayInHeader: root.defaults.trayInHeader

            property bool visualizer: root.defaults.visualizer
            property bool trackChangePeek: root.defaults.trackChangePeek
            property bool spinArt: root.defaults.spinArt

            property bool notifications: root.defaults.notifications
            property bool takeover: root.defaults.takeover
            property string notifStyle: root.defaults.notifStyle
            property int bannerTimeout: root.defaults.bannerTimeout
            property int urgentTimeout: root.defaults.urgentTimeout
            property bool urgentSticky: root.defaults.urgentSticky
            property string previews: root.defaults.previews
            property bool notifSound: root.defaults.notifSound
            property string soundFile: root.defaults.soundFile
            property bool groupByApp: root.defaults.groupByApp
            property bool dnd: root.defaults.dnd
            property bool dndAllowCritical: root.defaults.dndAllowCritical

            property bool weather: root.defaults.weather
            property string locationMode: root.defaults.locationMode
            property real manualLat: root.defaults.manualLat
            property real manualLon: root.defaults.manualLon
            property string manualName: root.defaults.manualName
            property string units: root.defaults.units

            property bool ccAccent: root.defaults.ccAccent
            property int nightLightTemp: root.defaults.nightLightTemp
            property bool osdPopups: root.defaults.osdPopups
            property int osdTimeout: root.defaults.osdTimeout
            property bool confirmPower: root.defaults.confirmPower
        }
    }
}
