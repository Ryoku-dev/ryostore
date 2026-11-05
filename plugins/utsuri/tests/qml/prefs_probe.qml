import QtQuick
import Quickshell
import Quickshell.Io
import "service" as S

// Driven by tests/test_prefs_qml.py: runs the real Prefs.qml against Ryoku's real
// Scheme, with XDG_CACHE_HOME / XDG_CONFIG_HOME pointing at a test folder. Each
// step prints one "PROBE <json>" line; the test checks them.
ShellRoot {
    id: root
    readonly property string dir: Quickshell.env("PROBE_DIR")
    readonly property string cache: Quickshell.env("XDG_CACHE_HOME")
    property int step: 0
    property int prefsWrites: 0

    S.Prefs { id: prefs; dir: root.dir }

    FileView { id: colors; path: root.cache + "/ryoku/colors.json"; printErrors: false }
    FileView {   // counts every change to prefs.json, to catch a write loop
        path: root.dir + "/prefs.json"
        watchChanges: true
        printErrors: false
        onFileChanged: { root.prefsWrites++; reload(); }
    }

    function report(name) {
        const l = prefs.look;
        console.log("PROBE " + JSON.stringify({ step: name, theme: prefs.themeId, hidden: prefs.hidden,
            themed: l.themed, tint: String(l.tint), accent: String(l.accent), ink: String(l.ink),
            writes: root.prefsWrites }));
    }

    Timer {
        interval: 600
        repeat: true
        running: true
        onTriggered: {
            root.step++;
            switch (root.step) {
            case 1:
                root.report("start");
                colors.setText(JSON.stringify({ surface: "#fdf8ff", primary: "#6750a4", onSurface: "#1d1b20",
                                                surfaceContainer: "#f3edf7", surfaceContainerLowest: "#ffffff",
                                                onSurfaceVariant: "#49454f", outlineVariant: "#cac4d0" }));
                break;
            case 2:
                root.report("wallpaper-changed");
                colors.setText("{\"surface\": \"#12");   // half-written by the daemon
                break;
            case 3:
                root.report("colors-half-written");
                // quick toggles in one tick, as fast clicking would do
                prefs.setTheme("ocean");
                prefs.setHidden("image|convert:WEBP", true);
                prefs.setHidden("*|tool:zip", true);
                prefs.setHidden("image|convert:WEBP", false);
                prefs.setHidden("pdf|tool:gray", true);
                break;
            case 4:
                root.report("after-setters");
                root.prefsWrites = 0;
                break;
            case 7:   // idle ticks later: nothing may have written the file again
                root.report("idle");
                console.log("PROBE " + JSON.stringify({ step: "file" }));
                Qt.quit();
                break;
            }
        }
    }
}
