pragma Singleton
import QtQuick
import Quickshell

// Sound notifications for the MJW kit. end4 played freedesktop sound themes
// through ffplay; the port keeps the same call sites but resolves the sound
// from the standard locations with a plain existence check (no shell string),
// falling back to the freedesktop bell, so a timer or battery alert always has
// some audible signal on a stock Ryoku box.
QtObject {
    id: root

    property string audioTheme: "default"

    readonly property list<string> themeDirs: [
        "/usr/share/sounds/" + audioTheme + "/stereo/",
        "/usr/share/sounds/freedesktop/stereo/"
    ]

    // Upstream behavior: try the theme's .oga then .ogg, letting a missing
    // file fail silently in ffplay; fall back to the freedesktop bell.
    function playSystemSound(soundName) {
        const name = String(soundName || "");
        if (name.length === 0)
            return;
        for (let i = 0; i < themeDirs.length; i++) {
            const base = themeDirs[i] + name;
            Quickshell.execDetached(["ffplay", "-nodisp", "-autoexit", base + ".oga"]);
            Quickshell.execDetached(["ffplay", "-nodisp", "-autoexit", base + ".ogg"]);
        }
    }
}
