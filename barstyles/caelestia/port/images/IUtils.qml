pragma Singleton

import QtQuick
import Quickshell

// What the panels used from the plugin's IUtils. Images load straight from disk;
// the plugin's thumbnail cache provider is not available in QML.
Singleton {
    function urlForPath(path: string, fillMode: int): url {
        return path ? (path.startsWith("/") ? "file://" + path : path) : "";
    }

    function isGif(path: string): bool {
        return /\.gif$/i.test(path);
    }

    function isVideo(path: string): bool {
        return /\.(mp4|webm|mkv|avi|mov|wmv|flv)$/i.test(path);
    }
}
