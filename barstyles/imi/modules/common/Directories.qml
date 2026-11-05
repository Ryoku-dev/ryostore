pragma Singleton
pragma ComponentBehavior: Bound

import "../../services"
import "functions"
import QtCore
import QtQuick
import Quickshell

Singleton {
    // XDG Dirs, with "file://"
    readonly property string home: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0] || ""
    readonly property string config: StandardPaths.standardLocations(StandardPaths.ConfigLocation)[0] || ""
    readonly property string state: StandardPaths.standardLocations(StandardPaths.StateLocation)[0] || ""
    readonly property string cache: StandardPaths.standardLocations(StandardPaths.CacheLocation)[0] || ""
    readonly property string genericCache: StandardPaths.standardLocations(StandardPaths.GenericCacheLocation)[0] || ""
    readonly property string documents: StandardPaths.standardLocations(StandardPaths.DocumentsLocation)[0] || ""
    readonly property string downloads: StandardPaths.standardLocations(StandardPaths.DownloadLocation)[0] || ""
    readonly property string pictures: StandardPaths.standardLocations(StandardPaths.PicturesLocation)[0] || ""
    readonly property string music: StandardPaths.standardLocations(StandardPaths.MusicLocation)[0] || ""
    readonly property string videos: StandardPaths.standardLocations(StandardPaths.MoviesLocation)[0] || ""
    readonly property string desktop: StandardPaths.standardLocations(StandardPaths.DesktopLocation)[0] || (Directories.home + "/Desktop")
    property string desktopPath: FileUtils.trimFileProtocol(Directories.desktop)
    readonly property string runtime: FileUtils.trimFileProtocol(StandardPaths.standardLocations(StandardPaths.RuntimeLocation)[0] || "/run/user/1000")

    // Resolves a barstyle-relative path (no leading slash) to an absolute file
    // path. Replaces Quickshell.shellPath, which points at the host shell's
    // config root, not at this installed barstyle view.
    function shellPath(name) {
        const base = FileUtils.trimFileProtocol(Qt.resolvedUrl("../.."));
        return FileUtils.trimFileProtocol(base + "/" + name);
    }

    // Config: one folder beside the rest of Ryoku's per-product state.
    property string shellConfig: FileUtils.trimFileProtocol(`${Directories.config}/ryoku/barstyle-imi`)
    property string shellConfigName: "config.json"
    property string shellConfigPath: `${Directories.shellConfig}/${Directories.shellConfigName}`
    // Durable mirror of machine-local settings presets never carry.
    property string localPreferencesName: "local-preferences.json"
    property string localPreferencesPath: `${Directories.shellConfig}/${Directories.localPreferencesName}`

    // Media caches
    property string favicons: FileUtils.trimFileProtocol(`${Directories.cache}/imi/media/favicons`)
    property string coverArt: FileUtils.trimFileProtocol(`${Directories.cache}/imi/media/coverart`)
    property string tempImages: `/tmp/imi-${SystemInfo.username}/media/images`
    property string booruPreviews: FileUtils.trimFileProtocol(`${Directories.cache}/imi/media/boorus`)
    property string booruDownloads: FileUtils.trimFileProtocol(Directories.pictures + "/imi")
    property string cliphistDecode: FileUtils.trimFileProtocol(`/tmp/imi-${SystemInfo.username}/media/cliphist`)
    property string screenshotTemp: `/tmp/imi-${SystemInfo.username}/media/screenshot`

    // Lyrics
    property string lyricsPath: FileUtils.trimFileProtocol(`${Directories.cache}/imi/lyrics/lyrics.json`)
    property string lyricsCacheDir: FileUtils.trimFileProtocol(`${Directories.cache}/imi/lyrics`)
    property string betterlyricsCachePath: FileUtils.trimFileProtocol(`${Directories.cache}/imi/lyrics/betterlyrics.json`)
    property string customLyricsPath: FileUtils.trimFileProtocol(`${Directories.state}/imi/custom-lyrics.json`)

    // User data
    property string todoPath: FileUtils.trimFileProtocol(`${Directories.state}/imi/todo.json`)
    property string todoDoneHistoryPath: FileUtils.trimFileProtocol(`${Directories.state}/imi/todo_done.json`)
    property string notesPath: FileUtils.trimFileProtocol(`${Directories.state}/imi/notes.json`)
    property string commandsPath: FileUtils.trimFileProtocol(`${Directories.state}/imi/commands.json`)
    property string localSendDownloadPath: FileUtils.trimFileProtocol(`${Directories.home}/Downloads/localsend`)
    property string userProfileImagePath: FileUtils.trimFileProtocol(`${Directories.shellConfig}/profile.png`)
    property string userAvatarPathAccountsService: FileUtils.trimFileProtocol(`/var/lib/AccountsService/icons/${SystemInfo.username}`)
    property string userAvatarPathRicersAndWeirdSystems: FileUtils.trimFileProtocol(`${Directories.home}.face`)
    property string userAvatarPathRicersAndWeirdSystems2: FileUtils.trimFileProtocol(`${Directories.home}.face.icon`)

    // Theme palettes: shipped defaults plus user-added overrides.
    property string defaultThemes: Directories.shellPath("assets/themes")
    property string customThemes: `${Directories.shellConfig}/themes`

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", `${shellConfig}`]);
        Quickshell.execDetached(["mkdir", "-p", `${favicons}`]);
        Quickshell.execDetached(["bash", "-c", `rm -rf '${coverArt}'; mkdir -p '${coverArt}'`]);
        Quickshell.execDetached(["bash", "-c", `rm -rf '${booruPreviews}'; mkdir -p '${booruPreviews}'`]);
        Quickshell.execDetached(["bash", "-c", `rm -rf '${cliphistDecode}'; mkdir -p '${cliphistDecode}'`]);
        Quickshell.execDetached(["mkdir", "-p", `${FileUtils.parentDirectory(customLyricsPath)}`]);
        Quickshell.execDetached(["mkdir", "-p", `${FileUtils.parentDirectory(lyricsPath)}`]);
        Quickshell.execDetached(["rm", "-rf", `${tempImages}`]);
        Quickshell.execDetached(["mkdir", "-p", `${screenshotTemp}`]);
    }

    onCliphistDecodeChanged: Quickshell.execDetached(["bash", "-c", `rm -rf '${cliphistDecode}'; mkdir -p '${cliphistDecode}'`])
}
