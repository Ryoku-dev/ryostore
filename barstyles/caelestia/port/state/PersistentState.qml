pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool wallpaperPlaying: raw.wallpaperPlaying ?? true
    property bool doNotDisturb: raw.doNotDisturb ?? false
    property bool loading: false
    property var raw: parse(file.text())

    function parse(text): var {
        try {
            return JSON.parse(text || "{}");
        } catch (error) {
            return {};
        }
    }

    function save(): void {
        if (!loading)
            file.setText(JSON.stringify({ wallpaperPlaying, doNotDisturb }, null, 2) + "\n");
    }

    onWallpaperPlayingChanged: save()
    onDoNotDisturbChanged: save()

    FileView {
        id: file
        path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/ryoku/caelestia-state.json`
        blockLoading: true
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root.loading = true;
            root.raw = root.parse(text());
            root.wallpaperPlaying = root.raw.wallpaperPlaying ?? true;
            root.doNotDisturb = root.raw.doNotDisturb ?? false;
            root.loading = false;
        }
    }
}
