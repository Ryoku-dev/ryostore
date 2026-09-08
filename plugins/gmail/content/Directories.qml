pragma Singleton
import QtQuick
import Quickshell

QtObject {
    id: root
    readonly property string home: Quickshell.env("HOME") || (Quickshell.env("USER") ? "/home/" + Quickshell.env("USER") : ".")
    readonly property string documents: home + "/Documents"
    readonly property string downloads: home + "/Downloads"
    readonly property string pictures: home + "/Pictures"
    readonly property string config: Quickshell.env("XDG_CONFIG_HOME") || (home + "/.config")
    readonly property string state: Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")
    readonly property string cache: Quickshell.env("XDG_CACHE_HOME") || (home + "/.cache")
}
