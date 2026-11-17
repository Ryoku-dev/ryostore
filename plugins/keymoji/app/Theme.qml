pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "Palette.mjs" as Palette
Singleton {
    id: theme
    property bool detected: false
    property bool follow: true
    property var named: null
    property var wall: ({})
    readonly property bool adaptive: detected && Quickshell.env("KEYMOJI_THEME") !== "fallback"
    readonly property var roles: Palette.resolve(named,wall,follow,adaptive)
    readonly property color surface: roles.surface
    readonly property color raised: roles.surfaceContainer
    readonly property color hover: roles.surfaceContainerHigh
    readonly property color border: roles.outlineVariant
    readonly property color accent: roles.primary
    readonly property color accentInk: roles.onPrimary
    readonly property color ink: roles.onSurface
    readonly property color muted: roles.onSurfaceVariant
    readonly property string configRoot: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME")+"/.config")+"/ryoku"
    FileView {
        path: theme.configRoot+"/theme.json"
        watchChanges: true; printErrors: false
        onFileChanged: reload()
        onLoaded: { try {const data=JSON.parse(text());theme.follow=data.followWallpaper!==false;theme.detected=true;}catch(e){} }
    }
    FileView {
        path: theme.configRoot+"/shell.json"
        watchChanges: true; printErrors: false
        onFileChanged: reload()
        onLoaded: { try {const data=JSON.parse(text());theme.named=data.themePalette||null;theme.detected=true;}catch(e){} }
    }
    FileView {
        path: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME")+"/.cache")+"/ryoku/colors.json"
        watchChanges: true; printErrors: false
        onFileChanged: reload()
        onLoaded: {try {theme.wall=JSON.parse(text());}catch(e){} }
    }
}
