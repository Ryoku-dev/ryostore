pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

// Live desktop wallpaper for the MJW kit, read from the Ryoku wallpaper
// engine's own state (ryogami writes ~/.cache/ryogami/last-wallpaper.json on
// every set, and outputs.json per monitor). A video wallpaper reports its
// poster frame, matching the upstream rule that widgets blur the still, not
// the clip. This is what FastBlurred samples so a tile's frosted glass shows
// the actual desktop behind it.
Singleton {
    id: root

    readonly property string stateDir: (Quickshell.env("XDG_CACHE_HOME")
        || (Quickshell.env("HOME") + "/.cache")) + "/ryogami"
    readonly property string lastPath: stateDir + "/last-wallpaper.json"
    readonly property string outputsPath: stateDir + "/outputs.json"

    property string rawPath: ""
    property string wallpaperPath: ""
    property string wallpaperPoster: ""

    readonly property bool wallpaperIsVideo: /\.(mp4|webm|mkv|avi|mov)$/i.test(wallpaperPath)

    function refine() {
        let p = "";
        try {
            const o = JSON.parse(last.text());
            p = o.path || "";
        } catch (e) {
            // fall through to outputs.json
        }
        if (!p) {
            try {
                const o = JSON.parse(outputs.text());
                p = (o["*"] && o["*"].path) || Object.values(o)[0]?.path || "";
            } catch (e) {
                p = "";
            }
        }
        root.rawPath = p;
        const video = /\.(mp4|webm|mkv|avi|mov)$/i.test(p);
        root.wallpaperPath = p;
        // For a clip, ryogami keeps the poster beside it with "-still" suffix;
        // the tile reads the same poster ryogami generated.
        root.wallpaperPoster = video ? p.replace(/\.[a-zA-Z0-9]+$/, "-still.jpg") : p;
    }

    FileView {
        id: last
        path: root.lastPath
        watchChanges: true
        blockLoading: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.refine()
    }

    FileView {
        id: outputs
        path: root.outputsPath
        watchChanges: true
        blockLoading: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.refine()
    }

    Component.onCompleted: refine()
}
