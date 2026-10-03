pragma Singleton

import QtQuick
import Quickshell
import Ryoku.Ui.Singletons

/**
 * Runtime fullscreen state shared by the Ricelin scene.
 *
 * Ryoku's Wm facade owns the live fullscreen state for every compositor.
 */
Singleton {
    id: root

    function outputHasFullscreen(name) {
        return Wm.outputHasFullscreen(name);
    }
}
