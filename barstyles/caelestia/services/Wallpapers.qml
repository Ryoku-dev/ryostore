pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import shell.services as RyokuServices
import "../config"
import "../port/models"
import "."
import "../utils"

Searcher {
    id: root

    readonly property string fallback: Qt.resolvedUrl("../assets/preview.webp").toString().replace(/^file:\/\//, "")

    property bool showPreview: false
    readonly property string current: showPreview ? previewPath : actualCurrent
    property string previewPath
    readonly property string actualCurrent: RyokuServices.Session.wallpaper || fallback
    property bool previewColourLock
    property bool pendingPreviewClear

    function getCategoryFor(w: var): string {
        let category = w.parentDir.slice(Paths.wallsdir.length + 1);
        if (category.includes("/"))
            category = category.slice(0, category.indexOf("/"));
        return category;
    }

    function setRandom(): void {
        Quickshell.execDetached(["ryogami", "wallpaper", "random"]);
    }

    function setWallpaper(path: string): void {
        Quickshell.execDetached(["ryogami", "wallpaper", "set", path]);
    }

    function preview(path: string): void {
        previewPath = path;
        showPreview = true;

        Colours.showPreview = false;
    }

    function stopPreview(): void {
        showPreview = false;
        if (previewColourLock)
            pendingPreviewClear = true;
        else
            Colours.showPreview = false;
    }

    onPreviewColourLockChanged: {
        if (!previewColourLock && pendingPreviewClear)
            Colours.showPreview = false;
    }

    listValues: wallpapers.entries
    key: "relativePath"
    useFuzzy: GlobalConfig.launcher.useFuzzy.wallpapers
    extraOpts: useFuzzy ? ({}) : ({
            forward: false
        })

    IpcHandler {
        function get(): string {
            return root.actualCurrent;
        }

        function set(path: string): void {
            root.setWallpaper(path);
        }

        function list(): string {
            return root.list.map(w => w.path).join("\n");
        }

        target: "wallpaper"
    }

    onActualCurrentChanged: previewColourLock = false

    FileSystemModel {
        id: wallpapers

        recursive: true
        path: Paths.wallsdir
        filter: FileSystemModel.Images | FileSystemModel.Videos
    }

}
