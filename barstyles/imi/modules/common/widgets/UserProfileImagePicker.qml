pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import ".."
import "../../../services"

Process {
    id: root

    /** Ignore repeated clicks while a selection is already in progress. */
    function pick(): void {
        root.running = true;
    }

    property string lastPath: ""

    command: ["sh", Directories.shellPath("scripts/images/pick-image.sh"), "pick", "avatar"]

    stdout: StdioCollector {
        onStreamFinished: {
            const targetPath = text.trim();
            if (targetPath === "")
                return;
            root.lastPath = targetPath;
            // Clear first to reload even when the filename has not changed.
            Config.options.userProfile.imagePath = "";
            Config.options.userProfile.imagePath = targetPath;
        }
    }
}
