pragma Singleton

import QtQuick
import Quickshell
import shell.services as HostServices

// Ryoku has no manual dark switch: the palette follows the wallpaper, so dark is
// derived from the surface's luminance (same rule the Tansu barstyle uses). The
// old schedule/wallpaper machinery is gone; a mode toggle rides the host's
// nightlight switch, the one mode control the daemon owns.
Singleton {
    id: root

    function lum(c) {
        return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
    }

    readonly property bool dark: root.lum(HostServices.Theme.surface) < 0.5

    function enableDarkMode() {
        if (!root.dark)
            HostServices.Nightlight.toggle();
    }

    function disableDarkMode() {
        if (root.dark)
            HostServices.Nightlight.toggle();
    }
}
