pragma Singleton

import QtQuick
import Quickshell
import shell.services as HostServices

// The host theme daemon already applies the matugen palette to shell.services
// Theme, so there is nothing to load here. What remains of the old loader is a
// mode toggle and a change serial the preset transition waits on.
Singleton {
    id: root

    // The palette serial moves whenever the surface colour does: a wallpaper
    // change regenerates the palette, so this is what "the colours settled"
    // looks like to PresetTransition.
    readonly property real paletteSerial: {
        const c = HostServices.Theme.surface;
        return Math.round((c.r * 255 + c.g * 255 * 256 + c.b * 255 * 65536) * 100) / 100;
    }

    // Ryoku has no manual dark switch; the host's nightlight toggle is what a
    // "toggle light/dark" gesture means here.
    function toggleLightDark() {
        HostServices.Nightlight.toggle();
    }
}
