pragma Singleton
pragma ComponentBehavior: Bound

import "functions"
import QtCore
import QtQuick
import Quickshell

// Trimmed from the barstyle Directories to the paths the launcher needs.
Singleton {
    id: root

    // XDG dirs, with "file://"
    readonly property string home: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0] || ""
    readonly property string config: StandardPaths.standardLocations(StandardPaths.ConfigLocation)[0] || ""
    readonly property string state: StandardPaths.standardLocations(StandardPaths.StateLocation)[0] || ""
    readonly property string cache: StandardPaths.standardLocations(StandardPaths.CacheLocation)[0] || ""
    readonly property string documents: StandardPaths.standardLocations(StandardPaths.DocumentsLocation)[0] || ""
    readonly property string downloads: StandardPaths.standardLocations(StandardPaths.DownloadLocation)[0] || ""
    readonly property string pictures: StandardPaths.standardLocations(StandardPaths.PicturesLocation)[0] || ""
    readonly property string videos: StandardPaths.standardLocations(StandardPaths.MoviesLocation)[0] || ""

    // Resolves a launcher-relative path (no leading slash) to an absolute file
    // path. Points at this installed product view, not the host shell.
    function shellPath(name) {
        const base = FileUtils.trimFileProtocol(Qt.resolvedUrl("../.."));
        return FileUtils.trimFileProtocol(base + "/" + name);
    }

    // The launcher's own config file (never the host's launcher.json).
    property string shellConfigName: "launcher-imi.json"
    property string shellConfigPath: FileUtils.trimFileProtocol(`${Directories.config}/ryoku/${Directories.shellConfigName}`)

    // Python helpers shipped beside the QML.
    property string scriptPath: Directories.shellPath("scripts")

    // Shared user-data paths, matching the barstyle's state directory.
    property string commandsPath: FileUtils.trimFileProtocol(`${Directories.state}/imi/commands.json`)
    property string cliphistDecode: FileUtils.trimFileProtocol(`/tmp/imi-${Quickshell.env("USER")}/media/cliphist`)

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", FileUtils.parentDirectory(root.shellConfigPath)]);
        Quickshell.execDetached(["mkdir", "-p", FileUtils.parentDirectory(root.commandsPath)]);
        Quickshell.execDetached(["bash", "-c", `rm -rf '${cliphistDecode}'; mkdir -p '${cliphistDecode}'`]);
    }
}
