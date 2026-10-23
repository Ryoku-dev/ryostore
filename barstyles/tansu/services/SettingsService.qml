pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../modules/common/functions/QuickTiles.js" as QT

// Barstyle-local settings, edited by the phone's Settings screen
// (modules/tansu/settings). Only what this barstyle owns lives here: the bar's
// modules and behaviour, the Quick Panel phone, the utilities. Everything Ryoku
// owns (displays, the compositor, keybinds, network, the system theme, the
// wallpaper daemon, updates) is not a setting here.
//
// The values are written to a small JSON file so they survive a shell reload or
// a store update. It is the barstyle's own file, never Ryoku's shell.json.
Singleton {
    id: root

    readonly property string configPath: (Quickshell.env("XDG_CONFIG_HOME")
        || (Quickshell.env("HOME") + "/.config")) + "/ryoku/barstyle-tansu.json"

    property bool loaded: false

    readonly property var defaults: ({
        "bar.visible": true,
        "bar.autohide": false,
        "bar.workspaces": true,
        "bar.activeWindow": true,
        "bar.media": true,
        "bar.tray": true,
        "bar.status": true,
        "bar.weather": true,
        "bar.clock": true,
        "bar.date": true,
        "bar.utilButtons": true,
        "bar.resources": true,
        "bar.battery": true,
        "bar.privacy": true,
        "bar.updates": true,
        "bar.keyboardLayout": true,
        "bar.notifications": true,
        "bar.discord": false,
        "bar.compactWindow": false,
        "bar.perMonitor": false,
        "bar.style": "transparent",
        "bar.roundness": 100,
        "bar.scale": 1,
        "bar.position": "top",
        "bar.layout": ({
            left: ["activeWindow", "media", "tray"],
            center: ["status", "weather", "workspaces", "clock", "date"],
            right: ["utilButtons", "resources", "battery", "keyboardLayout", "privacy", "updates", "notifications"]
        }),
        "bar.screens": ({}),
        "shell.scales": ({}),
        "bar.scrollHints": true,
        "bar.workspaceCount": 6,
        "notify.on": true,
        "notify.buzz": true,
        "time.use24h": true,
        "tray.scroll": true,
        "panel.hotEdge": true,
        "panel.hotCornerTopLeft": false,
        "panel.hotCornerTopRight": false,
        "panel.hotCornerBottomLeft": false,
        "panel.hotCornerBottomRight": false,
        "panel.hotCornerFollow": true,
        "panel.clickOutside": true,
        "panel.typeToSearch": true,
        "panel.peek": 72,
        "panel.hotDwell": 260,
        "quick.phoneShadow": true,
        "quick.flat": false,
        "quick.media": true,
        "quick.pinScale": 58,
        "quick.pinOpacity": 100,
        "quick.tiles": QT.defaultTiles,
        "quick.tileColumns": QT.defaultColumns,
        "util.darkMode": true,
        "util.mic": true,
        "util.profile": true,
        "util.record": false,
        "util.screenshot": true,
        "util.wallpapers": true,
        "util.colorPicker": false,
        "util.keyboard": false,
        "wallpaper.thumbs": true,
        "wallpaper.video": false,
        "wallpaper.separateLock": false,
        "wallpaper.perMonitor": false,
        "wallpaper.folder": "",
        "wallpaper.duration": 30,
        "wallpaper.randomMinutes": 0,
        "wallpaper.transition": "fade",
        "updates.showZero": false,
        "updates.shellNotify": false,
        "updates.intervalMin": 60,
        "updates.terminal": "kitty",
        "weather.view": "card",
        "weather.location": "",
        "weather.fahrenheit": false,
        "media.leftClick": "playpause",
        "appearance.iconTheme": "",
        "appearance.iconStyle": "outline",
        "appearance.cursorTheme": "",
        "appearance.cursorSize": 24,
        "systemTheme.sync": false,
        "systemTheme.gtk": false,
        "systemTheme.qt": false,
        "systemTheme.kde": false,
        "systemTheme.live": false,
        "systemTheme.bounceDark": false,
        "focus.enabled": false,
        "focus.suspend": false,
        "focus.unload": false,
        "focus.reduceEffects": false,
        "focus.hideTiled": false,
        "focus.hideFloating": false,
        "focus.visualizerBackground": false,
        "lock.style": "clockwork-tape",
        "lock.sleepDesktop": false,
        "perf.lowEnd": false,
        "region.own": false,
        "region.preview": true,
        "region.audio": true,
        "calendar.marks": "",
        "timer.pomWork": 25,
        "timer.pomShort": 5,
        "timer.pomLong": 15,
        "timer.pomRounds": 4,
        "updates.aur": false,
        "updates.shellHours": 0,
        "updates.nudgeAt": 0,
        "overview.gap": 16,
        "overview.layout": "board",
        "overview.position": "center",
        "overview.scale": 1,
        "overview.style": "board",
        "overview.workspaces": 0,
        "dock.pinOnStartup": false,
        "dock.filesMode": "grid",
        "dock.files.folder": "",
        "dock.files.sort": "name",
        "dock.files.reverse": false,
        "dock.files.hidden": false,
        "dock.files.foldersFirst": true,
        "dock.files.view": "grid",
        "dock.files.modified": "",
        "files.chooser": "",
        "launcher.clipboard": false,
        "launcher.webSuggestions": false,
        "appTheme.ready": false,
        "settings.page": ""
    })

    property var values: root.defaults

    readonly property var barModules: {
        const out = []
        for (const key of Object.keys(root.values))
            if (key.indexOf("bar.") === 0 && root.values[key] === true
                    && key !== "bar.visible" && key !== "bar.compactWindow"
                    && key !== "bar.perMonitor" && key !== "bar.autohide")
                out.push(key.slice(4))
        return out
    }

    function get(path, fallback) {
        const value = root.values[path]
        return value === undefined ? fallback : value
    }

    function flag(path) {
        return root.get(path, false) === true
    }

    function set(path, value) {
        if (root.defaults[path] === undefined)
            return
        const next = Object.assign({}, root.values)
        next[path] = value
        root.values = next
        root.persist()
    }

    function toggle(path) {
        root.set(path, !root.flag(path))
    }

    function applyPreset(preset, keeps) {
        if (!preset)
            return
        const next = Object.assign({}, root.values)
        for (const key of Object.keys(preset)) {
            if (root.defaults[key] === undefined)
                continue
            if (keeps && keeps.indexOf(key) >= 0)
                continue
            next[key] = preset[key]
        }
        root.values = next
        root.persist()
    }

    readonly property int changedCount: {
        let n = 0
        for (const key of Object.keys(root.defaults))
            if (JSON.stringify(root.values[key]) !== JSON.stringify(root.defaults[key]))
                n++
        return n
    }

    function reset() {
        root.values = root.defaults
        root.persist()
    }

    // Only the known keys, and only when the saved value is the same shape as
    // its default, so a hand-edited or older file cannot inject a setting.
    function adopt(raw) {
        let saved = null
        try {
            saved = JSON.parse(raw || "{}")
        } catch (e) {
            saved = null
        }
        if (saved && typeof saved === "object") {
            const next = Object.assign({}, root.defaults)
            for (const key of Object.keys(root.defaults)) {
                const value = saved[key]
                if (value !== undefined && typeof value === typeof root.defaults[key])
                    next[key] = value
            }
            root.values = next
        }
        root.loaded = true
    }

    function persist() {
        if (root.loaded)
            writeTimer.restart()
    }

    Timer {
        id: writeTimer
        interval: 250
        onTriggered: store.setText(JSON.stringify(root.values, null, 2))
    }

    FileView {
        id: store
        path: root.configPath
        blockLoading: true
        printErrors: false
        onLoaded: root.adopt(text())
        onLoadFailed: root.loaded = true
    }
}
