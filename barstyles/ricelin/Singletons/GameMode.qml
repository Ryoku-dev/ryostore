pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Game mode: one flag that strips Hyprland's eye-candy and quiets the desktop for
 * gaming or deep focus. Entering snapshots the focus flags, forces do-not-disturb
 * and keep-awake on, pauses the visualizer, and runs the visual strip; leaving
 * restores each to what it was before. The strip itself lives in gamemode.sh so
 * the original decoration values survive a pill restart. `Flags.gameMode` is the
 * single source of truth, flipped by the mixer chip, the keybind, or IPC.
 */
Singleton {
    id: root

    readonly property bool active: Flags.gameMode
    readonly property string script: Quickshell.env("HOME") + "/.config/hypr/scripts/gamemode.sh"
    property string pending: ""

    onActiveChanged: active ? root.enter() : root.leave()

    function enter() {
        Flags.gamePrevDnd = Flags.dnd;
        Flags.gamePrevViz = Flags.musicViz;
        Flags.gamePrevAwake = Flags.keepAwake;
        Flags.dnd = true;
        Flags.musicViz = false;
        Flags.keepAwake = true;
        root.run("on");
    }

    function leave() {
        root.run("off");
        Flags.dnd = Flags.gamePrevDnd;
        Flags.musicViz = Flags.gamePrevViz;
        Flags.keepAwake = Flags.gamePrevAwake;
    }

    function run(arg) {
        if (proc.running) {
            root.pending = arg;
            return;
        }
        proc.command = ["bash", root.script, arg];
        proc.running = true;
    }

    Process {
        id: proc
        onExited: {
            if (root.pending.length === 0)
                return;
            var a = root.pending;
            root.pending = "";
            proc.command = ["bash", root.script, a];
            proc.running = true;
        }
    }
}
