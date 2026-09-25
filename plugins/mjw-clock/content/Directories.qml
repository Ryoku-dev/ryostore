pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

// XDG paths for the MJW kit. Plugin state lives under the plugin's own state
// dir ($XDG_STATE_HOME/ryoku/plugins/<id>), never in a shared or shipped
// config path, so one widget's data can't collide with another's.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") || "/home/" + (Quickshell.env("USER") || "user")
    readonly property string config: (Quickshell.env("XDG_CONFIG_HOME") || (home + "/.config"))
    readonly property string state: (Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state"))
    readonly property string cache: (Quickshell.env("XDG_CACHE_HOME") || (home + "/.cache"))

    readonly property string documents: {
        const d = Quickshell.env("XDG_DOCUMENTS_DIR");
        return (d && d.length > 0) ? d : (home + "/Documents");
    }
    readonly property string pictures: {
        const d = Quickshell.env("XDG_PICTURES_DIR");
        return (d && d.length > 0) ? d : (home + "/Pictures");
    }
    readonly property string downloads: {
        const d = Quickshell.env("XDG_DOWNLOAD_DIR");
        return (d && d.length > 0) ? d : (home + "/Downloads");
    }

    readonly property string pluginState: state + "/ryoku/plugins/mjw-clock"
    readonly property string pluginCache: cache + "/ryoku/plugins/mjw-clock"

    // Installed plugin folder, pushed by the adapter from pluginApi.pluginDir;
    // the shipped bin/ scripts resolve against it.
    property string pluginDir: ""
    readonly property string pluginBin: pluginDir.length > 0 ? pluginDir + "/bin" : ""

    property string coverArt: pluginCache + "/coverart"
    property string todoPath: pluginState + "/todo.json"
    property string desktopNotesPath: pluginState + "/notes.json"

    Process {
        command: ["mkdir", "-p", root.pluginState, root.pluginCache, root.coverArt]
        running: true
    }
}
