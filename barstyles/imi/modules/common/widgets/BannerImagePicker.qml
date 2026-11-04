pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import ".."
import "../functions"
import "../../../services"

Process {
    id: root

    property string title: Translation.tr("Select banner image")
    property var nameFilters: ["Image files (*.png *.jpg *.jpeg *.webp *.bmp *.gif)"]

    /** Ignore repeated clicks while a selection is already in progress. */
    function pick(): void {
        root.running = true;
    }

    command: ["sh", Directories.shellPath("scripts/images/pick-image.sh"), "pick", "banner"]

    stdout: StdioCollector {
        onStreamFinished: {
            const targetPath = text.trim();
            if (targetPath === "")
                return;
            // Clear first to reload even when the filename has not changed.
            Config.options.sidebar.bannerImage = "";
            Config.options.sidebar.bannerImage = targetPath;
            Config.options.sidebar.useCustomBanner = true;
        }
    }
}
