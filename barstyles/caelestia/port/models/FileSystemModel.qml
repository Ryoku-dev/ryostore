pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.folderlistmodel

// A folder's entries as plain objects (path, name, baseName, parentDir, suffix, size,
// isDir, isImage, relativePath), dirs first, optionally with every subfolder's files.
// The plugin's FileSystemModel in QML; it watches the folders itself.
Item {
    id: root

    enum Filter {
        NoFilter,
        Images,
        Videos,
        Files,
        Dirs
    }

    property string path
    property bool recursive: false
    property bool showHidden: false
    property bool sortReverse: false
    property int filter: FileSystemModel.NoFilter
    property list<string> nameFilters
    // the folder the relative paths start from; children of a recursive model share the parent's
    property string rootPath: path

    readonly property list<string> imageSuffixes: ["jpg", "jpeg", "png", "webp", "tif", "tiff", "svg", "gif", "bmp"]
    readonly property list<string> videoSuffixes: ["mp4", "webm", "mkv", "avi", "mov", "wmv", "flv"]

    readonly property var listing: {
        const out = [];
        if (!path)
            return out;
        for (let i = 0; i < folder.count; i++)
            out.push(entryAt(i));
        return out;
    }

    readonly property list<string> subdirs: recursive ? listing.filter(e => e.isDir).map(e => e.path) : []

    readonly property var entries: {
        const own = listing.filter(accepts);
        own.sort((a, b) => {
            if (a.isDir !== b.isDir)
                return (a.isDir ? -1 : 1) * (sortReverse ? -1 : 1);
            const cmp = a.name.localeCompare(b.name);
            return sortReverse ? -cmp : cmp;
        });
        let all = own;
        for (let i = 0; i < subfolders.count; i++)
            all = all.concat(subfolders.objectAt(i)?.entries ?? []);
        return all;
    }

    function entryAt(i: int): var {
        const path = folder.get(i, "filePath");
        const suffix = (folder.get(i, "fileSuffix") || "").toLowerCase();
        const isDir = folder.get(i, "fileIsDir");
        const parentDir = path.slice(0, path.lastIndexOf("/"));
        return {
            path: path,
            name: folder.get(i, "fileName"),
            baseName: folder.get(i, "fileBaseName"),
            parentDir: parentDir,
            suffix: suffix,
            size: folder.get(i, "fileSize"),
            isDir: isDir,
            isImage: !isDir && imageSuffixes.includes(suffix),
            relativePath: path.slice(rootPath.replace(/\/$/, "").length + 1)
        };
    }

    function accepts(e: var): bool {
        if (filter === FileSystemModel.Dirs)
            return e.isDir;
        if (e.isDir)
            return filter === FileSystemModel.NoFilter && !recursive;
        if (filter === FileSystemModel.Images)
            return e.isImage;
        if (filter === FileSystemModel.Videos)
            return videoSuffixes.includes(e.suffix);
        return true;
    }

    FolderListModel {
        id: folder

        folder: root.path ? "file://" + root.path : ""
        showDirs: true
        showDirsFirst: true
        showDotAndDotDot: false
        showHidden: root.showHidden
        nameFilters: root.nameFilters
        sortField: FolderListModel.Name
    }

    Instantiator {
        id: subfolders

        model: root.subdirs
        delegate: Qt.createComponent("FileSystemModel.qml")
        onObjectAdded: (index, object) => {
            object.path = root.subdirs[index];
            object.rootPath = Qt.binding(() => root.rootPath);
            object.recursive = true;
            object.showHidden = Qt.binding(() => root.showHidden);
            object.filter = Qt.binding(() => root.filter);
            object.nameFilters = Qt.binding(() => root.nameFilters);
        }
    }
}
