pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Wallpaper bridge: keeps a warm in-memory snapshot of the wallpaper folder so
 * the wallpaper strip opens instantly without shelling out on demand. A refresh
 * first generates any missing video poster frames (a product-local ffmpeg
 * cache; stills and gifs render straight from source), then re-lists the
 * directory newest-first and finally re-reads Ryogami's current-wallpaper state
 * file, so `current` always names the wallpaper on screen. Posters land before
 * the list so strip delegates never bind to a not-yet-existing file; a refresh
 * arriving while the pipeline runs sets `pending` and replays once the state
 * lands. Applying routes through `ryogami wallpaper set`, the native backend
 * that also serves the random keybind and the full picker, so the strip shares
 * its exact transition, palette and state path.
 *
 * The folder resolves through one chain, first hit wins: an explicit
 * `wallpaperDir` in flags.json, then Ryogami's own `paths.wallpaper` from
 * ~/.config/ryoku/ryogami.json, then ~/Pictures/Wallpapers (Ryogami's default)
 * for a box that never configured one.
 *
 * Entries are plain objects: { path, name, mtime, thumb }. path is the absolute
 * source file, mtime its modification time in epoch seconds; thumb is the
 * source itself for stills and gifs (Qt downscales on load) and the cached
 * poster PNG for videos, which Qt cannot decode as an Image.
 */
Singleton {
    id: root

    property var entries: []
    readonly property int count: entries.length
    property string current: ""
    property bool pending: false

    property string resolvedDir: ""
    readonly property string wpDir: Flags.wallpaperDir.length > 0 ? Flags.wallpaperDir
        : (resolvedDir.length > 0 ? resolvedDir : Quickshell.env("HOME") + "/Pictures/Wallpapers")
    readonly property string thumbDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/ricelin-wp-thumbs/"
    /** Ryogami writes the current default wallpaper's absolute path here on every apply and restore. */
    readonly property string stateFile: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ryoku-wallpaper"
    /** Ryogami's config: paths.wallpaper is the source folder the backend scans. */
    readonly property string configFile: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/ryogami.json"

    onWpDirChanged: refresh()

    FileView {
        id: configView
        path: root.configFile
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: root.resolvedDir = root.readWallpaperPath(configView.text())
        onFileChanged: reload()
        onLoadFailed: root.resolvedDir = ""
    }

    /**
     * Pull paths.wallpaper out of Ryogami's config, expanding a leading ~ the
     * same way the daemon's resolvePath does. Empty when unset or unparseable,
     * which falls the chain through to the default folder.
     */
    function readWallpaperPath(text) {
        try {
            var cfg = JSON.parse(text);
            var p = (cfg && cfg.paths) ? cfg.paths.wallpaper : "";
            if (typeof p !== "string" || p.length === 0)
                return "";
            if (p.indexOf("~/") === 0)
                return Quickshell.env("HOME") + p.substring(1);
            return p;
        } catch (e) {
            return "";
        }
    }

    function refresh() {
        if (thumbProc.running || listProc.running || stateProc.running) {
            pending = true;
            return;
        }
        thumbProc.running = true;
    }

    /**
     * `ryogami wallpaper set` blocks through the whole transition (reveal,
     * matugen, reload), easily 1-2s; a pick landing in that window used to be
     * silently swallowed. The newest request is queued and replayed once the
     * running transition exits, so rapid iteration converges on the last pick.
     */
    property string queuedApply: ""
    property string queuedOutput: ""

    function applyCommand(path, output) {
        return output.length > 0
            ? ["ryogami", "wallpaper", "set", path, "--screen", output]
            : ["ryogami", "wallpaper", "set", path];
    }

    function apply(path, output) {
        var out = output === undefined ? "" : output;
        if (applyProc.running) {
            queuedApply = path;
            queuedOutput = out;
            return;
        }
        applyProc.command = applyCommand(path, out);
        applyProc.running = true;
    }

    function trash(path) {
        trashProc.command = ["gio", "trash", path];
        trashProc.running = true;
        var kept = [];
        for (var i = 0; i < entries.length; i++)
            if (entries[i].path !== path)
                kept.push(entries[i]);
        entries = kept;
    }

    Process {
        id: trashProc
        onExited: function(exitCode) {
            if (exitCode !== 0)
                root.refresh();
        }
    }

    /**
     * Video poster cache. Stills and gifs render straight from source, so only
     * clips need a frame extracted (Qt's Image cannot decode video). ffmpeg
     * grabs a frame ~1s in, scaled to 512 wide, for any clip whose poster is
     * missing or older than the source; posters whose source is gone are pruned.
     */
    Process {
        id: thumbProc
        command: ["sh", "-c",
            "tdir=$1; wp=$2; mkdir -p \"$tdir\"; " +
            "find \"$wp\" -type f \\( -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' \\) -print | while IFS= read -r f; do " +
            "  p=\"$tdir$(basename \"$f\").png\"; " +
            "  if [ ! -s \"$p\" ] || [ \"$f\" -nt \"$p\" ]; then " +
            "    ffmpeg -nostdin -y -loglevel error -ss 1 -i \"$f\" -frames:v 1 -vf scale=512:-2 \"$p\" </dev/null >/dev/null 2>&1 || " +
            "    ffmpeg -nostdin -y -loglevel error -i \"$f\" -frames:v 1 -vf scale=512:-2 \"$p\" </dev/null >/dev/null 2>&1 || true; " +
            "  fi; " +
            "done; " +
            "for p in \"$tdir\"*.png; do [ -e \"$p\" ] || continue; " +
            "  b=$(basename \"$p\" .png); " +
            "  [ -n \"$(find \"$wp\" -type f -name \"$b\" -print -quit 2>/dev/null)\" ] || rm -f \"$p\"; " +
            "done",
            "_", root.thumbDir, root.wpDir]
        onExited: listProc.running = true
    }

    Process {
        id: listProc
        command: ["sh", "-c", "find \"$1\" -type f \\( -iname '*.jpg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.webp' -o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' \\) -printf '%T@\\t%p\\n' | sort -rn", "_", root.wpDir]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                var out = [];
                for (var i = 0; i < lines.length; i++) {
                    var tab = lines[i].indexOf("\t");
                    if (tab < 1)
                        continue;
                    var path = lines[i].substring(tab + 1);
                    var name = path.substring(path.lastIndexOf("/") + 1);
                    var isVideo = /\.(mp4|webm|mkv|mov)$/i.test(path);
                    out.push({
                        path: path,
                        name: name,
                        mtime: parseFloat(lines[i].substring(0, tab)),
                        thumb: isVideo ? (root.thumbDir + name + ".png") : path
                    });
                }
                root.entries = out;
                stateProc.running = true;
            }
        }
    }

    Process {
        id: stateProc
        command: ["sh", "-c", "cat \"$1\" 2>/dev/null || true", "_", root.stateFile]
        stdout: StdioCollector {
            onStreamFinished: {
                root.current = this.text.trim();
                if (root.pending) {
                    root.pending = false;
                    Qt.callLater(root.refresh);
                }
            }
        }
    }

    Process {
        id: applyProc
        onExited: {
            if (root.queuedApply.length) {
                var next = root.queuedApply;
                var nextOut = root.queuedOutput;
                root.queuedApply = "";
                root.queuedOutput = "";
                applyProc.command = root.applyCommand(next, nextOut);
                applyProc.running = true;
                return;
            }
            stateProc.running = true;
        }
    }

    Component.onCompleted: refresh()
}
