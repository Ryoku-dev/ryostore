pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "."

// The tile's live config, in the shape the ported illogical-impulse widget
// expects (Config.options.background.widgets.<name>.*). The widget entry is a
// JsonAdapter section: every change the widget makes (style taps, dropped
// images, edited text) persists to the plugin's own state dir and survives
// restarts, and hydrate() layers the Ryoku Settings form on top at load, so
// the form wins when the user fills it. Everything else is static defaults.
Singleton {
    id: root

    property bool ready: true
    property bool dirReady: false

    property QtObject options: QtObject {
        property QtObject background: QtObject {
            property string wallpaperPath: Backdrop.wallpaperPath
            property string thumbnailPath: Backdrop.wallpaperPoster
            property string lockWall: ""
            property bool widgetsLocked: false
            property QtObject widgets: QtObject {
                property bool blurWidgets: false
                property real blurRadius: 32
                property bool shadow: true
                property var calendar: entryAdapter.entry
            }
        }
        property QtObject appearance: QtObject {
            property QtObject transparency: QtObject {
                property bool enable: false
                property bool automatic: false
                property real backgroundTransparency: 0
                property real contentTransparency: 0.9
            }
            property QtObject fonts: QtObject {
                property string main: "Inter"
                property string numbers: "Inter"
                property string title: "Inter"
                property string reading: "Inter"
                property string expressive: "Inter"
                property string monospace: "monospace"
                property string iconNerd: "JetBrainsMono Nerd Font"
            }
        }
        property QtObject interactions: QtObject {
            property QtObject scrolling: QtObject {
                property real touchpadScrollFactor: 100
                property real mouseScrollFactor: 50
                property real mouseScrollDeltaThreshold: 120
                property bool fasterTouchpadScroll: false
            }
        }
        property QtObject time: QtObject {
            property bool secondPrecision: true
            property string format: "hh:mm"
            property string shortDateFormat: "dd/MM"
            property string dateWithYearFormat: "dd/MM/yyyy"
            property string dateFormat: "dddd, dd/MM"
            property QtObject pomodoro: QtObject {
                property int focus: 1500
                property int breakTime: 300
                property int longBreak: 900
                property int cyclesBeforeLongBreak: 4
            }
        }
        property QtObject resources: QtObject {
            property int updateInterval: 3000
        }
        property QtObject sounds: QtObject {
            property string theme: "default"
            property bool pomodoro: true
            property QtObject battery: QtObject {
                property bool low: true
                property bool full: false
                property bool critical: true
            }
        }
        property QtObject battery: QtObject {
            property int low: 20
            property int critical: 5
            property int full: 100
            property bool automaticSuspend: true
            property bool suspend: false
        }
        property QtObject bar: QtObject {
            property QtObject weather: QtObject {
                property string city: ""
                property bool useUSCS: false
                property int fetchInterval: 10
                property bool enableGPS: false
            }
            property QtObject media: QtObject {
                property string preferredPlayer: ""
            }
        }
        property QtObject media: QtObject {
            property bool filterDuplicatePlayers: true
        }
        property QtObject lock: QtObject {
            property bool showWidgets: true
            property bool centerClock: false
            property bool showLockedText: false
            property QtObject blur: QtObject {
                property bool enable: false
            }
        }
        property QtObject profile: QtObject {
            property string displayName: ""
            property string avatarPath: ""
            property bool avatarPicture: false
        }
        property QtObject sidebar: QtObject {
            property string bannerImage: ""
        }
    }

    // Per-widget knobs written by Ryoku Settings (pluginSettings) on top of
    // the persisted entry. The host re-reads placement for every tile whenever
    // any tile is moved, resized or recoloured, so an unchanged payload returns
    // early: one widget being dragged must not push writes and repaints through
    // every other tile on the desktop.
    property string _appliedSettings: ""
    function hydrate(settings) {
        const entry = options.background.widgets.calendar;
        if (!settings || !entry) {
            root._appliedSettings = "";
            return;
        }
        const stamp = JSON.stringify(settings);
        if (stamp === root._appliedSettings)
            return;
        root._appliedSettings = stamp;
        for (const k in settings) {
            const v = settings[k];
            if (v === undefined || v === null)
                continue;
            const dot = k.indexOf(".");
            if (dot > 0) {
                const sub = entry[k.slice(0, dot)];
                const tail = k.slice(dot + 1);
                if (sub !== undefined && sub[tail] !== undefined)
                    sub[tail] = v;
                continue;
            }
            if (entry[k] === undefined)
                continue;
            entry[k] = v;
        }
    }

    Process {
        id: mkdir
        command: ["mkdir", "-p", Directories.pluginState]
        running: true
        onExited: (code) => {
            root.dirReady = (code === 0);
            if (root.dirReady && !entryFile.exists)
                entryFile.writeAdapter();
        }
    }

    FileView {
        id: entryFile
        path: Directories.pluginState + "/entry.json"
        blockLoading: true
        printErrors: false
        onAdapterUpdated: entryFile.writeAdapter()
        onLoaded: root.ready = true
        onLoadFailed: error => {
            root.ready = true;
            if (error == FileViewError.FileNotFound && root.dirReady)
                entryFile.writeAdapter();
        }

        adapter: JsonAdapter {
            id: entryAdapter
            property JsonObject entry: JsonObject {
                property string sizeMode: "2x2"
            }
        }
    }
}
