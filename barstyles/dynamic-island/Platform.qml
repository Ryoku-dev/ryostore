pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import shell.services as Shell
import Ryoku.Ui.Singletons

// Ryoku bar style build: everything the island needs from the desktop,
// through the Ryoku shell's own services and the neutral Wm facade.
//
// No compositor CLI, socket or Quickshell.Hyprland here: the same bar style
// runs on Hyprland and niri. The standalone build ships its own Platform.qml
// with the same members, and every other file is shared between the two.
Singleton {
    id: root

    readonly property string kind: "ryoku"
    readonly property string buildLabel: "Ryoku bar style"
    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/dynamic-island"
    // where the shell already does the job, the island steps back by default
    readonly property var configDefaults: ({
        notifSound: false,   // the shell plays its own cue
        osdPopups: false,    // the shell draws its own volume / brightness OSD
        weather: false,      // contacts Open-Meteo and a geolocation service: opt in
        takeover: false
    })
    // reloading the island here would reload the whole desktop shell
    readonly property bool canReload: false
    function reload() {}

    // ═══════════════════════ OUTPUTS + WORKSPACES ════════════════
    readonly property string focusedOutput: Wm.focusedOutput || ""
    function outputHasFullscreen(name) { return Wm.outputHasFullscreen(name); }
    readonly property var focusedWs: Wm.focusedWorkspace
    readonly property int wsId: focusedWs && typeof focusedWs.index === "number" ? focusedWs.index : 1
    readonly property var occupied: (Wm.workspaces || []).filter(w => !w.special && (w.windows || 0) > 0)
        .map(w => typeof w.index === "number" ? w.index : 0).filter(i => i > 0)
    // gaps are compositor config on both Hyprland and niri, so this is a setting
    readonly property int outerGaps: Config.s.outerGaps

    // ═════════════════════════ ACCENT ════════════════════════════
    // Ryoku's active palette, tried first in Automatic.
    readonly property string accent: {
        const c = Shell.Theme.primary;
        return c && c.a > 0 ? c.toString() : "";
    }
    readonly property string accentLabel: "Ryoku theme"
    readonly property bool accentFirst: true
    readonly property string wallpaperProbe: "ryogami status 2>/dev/null | grep -oE '/[^ ]+\\.(png|jpe?g|webp|gif|bmp)' | head -1"

    // ═══════════════════════ NOTIFICATIONS ═══════════════════════
    // The shell owns org.freedesktop.Notifications. A second server in the
    // same process would fight it for the bus name, so the island watches the
    // shell's tracked list, and while Island notifications are on it lifts
    // each arrival out of the shell's toast queue: one banner surface paints.
    readonly property bool ownsDaemon: false
    readonly property string ownerStatus: "ours"
    readonly property string ownerName: ""
    readonly property int ownerPid: 0
    function takeOver() {}
    function checkOwner() {}

    readonly property var notifList: Shell.Notifs.tracked
    readonly property bool dnd: Shell.Notifs.dnd
    function setDnd(on) { Shell.Notifs.dnd = on; }

    property var seen: ({})
    property bool seeded: false
    onNotifListChanged: {
        const t = notifList;
        if (!seeded) return;
        const next = {};
        for (let i = 0; i < t.length; i++) {
            const n = t[i];
            next[n.id] = true;
            if (seen[n.id]) continue;
            if (Config.s.notifications) Shell.Notifs.removePopup(n);
            Notifs.receive(n);
        }
        seen = next;
    }
    Component.onCompleted: {
        const s = {};
        const t = notifList;
        for (let i = 0; i < t.length; i++) s[t[i].id] = true;
        seen = s;
        // they still need a time, or the Center shows them as "now" forever;
        // the shell knows when each one really arrived
        const arrived = Shell.Notifs.arrivalMs || {};
        Notifs.seed(t, n => arrived[n.id]);
        seeded = true;
    }

    // ═════════════════════ SCREEN RECORDING ══════════════════════
    readonly property bool recording: Shell.Recorder.anyActive
    function stopRecording() { Shell.Recorder.stop(); }

    // ═══════════════════════ QUICK TOGGLES ═══════════════════════
    // Caffeine is the shell's shared keep-awake flag; Night Shift is its
    // Nightlight service, driven by the daemon on every compositor.
    readonly property bool caffeine: Shell.Flags.keepAwake
    function setCaffeine(on) { Shell.Flags.keepAwake = on; }
    readonly property bool nightLight: Shell.Nightlight.on
    function setNightLight(on) { Shell.Nightlight.setEnabled(on, Config.s.nightLightTemp); }
    Connections {
        target: Config.s
        function onNightLightTempChanged() { if (Shell.Nightlight.on) Shell.Nightlight.setTemperature(Config.s.nightLightTemp); }
    }

    // ═══════════════════════ SESSION + TOOLS ═════════════════════
    function session(action) { Shell.SessionActions.run(action); }
    function screenshot() { Shell.Capture.shoot("region"); }
    function colorPick() { Spawn.runApp(["hyprpicker", "-a"], { label: "hyprpicker" }); }

    // ═════════════════════════ LAUNCHING ═════════════════════════
    // AppLaunch opens terminal apps in the terminal the user picked and keeps
    // the desktop's crash handler out of the child's environment.
    function launch(entry) { if (entry) Shell.AppLaunch.run(entry, null); }
    function runCommand(cmd, inTerminal) {
        const argv = ["sh", "-c", cmd];
        Spawn.runApp(inTerminal ? ["ryoku-app", "terminal", "--"].concat(argv) : argv, { label: "island" });
    }
    function copyText(text) { Quickshell.execDetached(["wl-copy", "--", text]); }

    readonly property var extraDeps: [
        { cmd: "wl-copy", pkg: "wl-clipboard", what: "Copy maths results" },
        { cmd: "hyprpicker", pkg: "hyprpicker", what: "Colour picker (wlroots compositors)" }
    ]
    readonly property string bluetoothHint: "Turn the bluetooth service on in your system's service settings."

    // ═══════════════════════ GLOBAL SHORTCUTS ════════════════════
    // Registered through the compositor's global-shortcut protocol when it
    // has one (Wm.caps.globalShortcuts); inert otherwise.
    readonly property var shortcuts: [
        { name: "islandLauncher", what: "App launcher" },
        { name: "islandToggle", what: "Open / close the island" },
        { name: "islandCenter", what: "Notification Center" },
        { name: "islandTray", what: "System tray" },
        { name: "islandSettings", what: "Settings" }
    ]
    readonly property string shortcutHint: "Bind these in Ryoku Hub > Keybinds. Super+Space and the Settings key already open the island's launcher and settings."
    ShellShortcut { name: "islandLauncher"; description: "App launcher in the island"; onPressed: Hub.toggleLauncher() }
    ShellShortcut { name: "islandToggle"; description: "Toggle the dynamic island"; onPressed: Hub.toggle("") }
    ShellShortcut { name: "islandCenter"; description: "Notification Center"; onPressed: Notifs.toggleCenter("") }
    ShellShortcut { name: "islandTray"; description: "System tray in the island"; onPressed: Hub.trayView !== "" ? Hub.collapse() : Hub.openTrayList("") }
    ShellShortcut { name: "islandSettings"; description: "Island settings"; onPressed: Hub.openSettings() }
}
