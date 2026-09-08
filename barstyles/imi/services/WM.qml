pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    function switchWorkspace(id) {
        if (id !== undefined && id !== null) {
            const cmd = "hl.dsp.focus({ workspace = " + id + " })";
            try {
                Hyprland.dispatch(cmd);
            } catch (e) {
                Quickshell.execDetached(["hyprctl", "dispatch", cmd]);
            }
        }
    }

    function switchWorkspaceRelative(direction) {
        const offset = (direction === "next" ? "+1" : "-1");
        const cmd = "hl.dsp.focus({ workspace = \"r" + offset + "\" })";
        try {
            Hyprland.dispatch(cmd);
        } catch (e) {
            Quickshell.execDetached(["hyprctl", "dispatch", cmd]);
        }
    }

    function focusWindow(address) {
        if (address) {
            const cmd = "hl.dsp.focus({ window = \"address:" + address + "\" })";
            try {
                Hyprland.dispatch(cmd);
            } catch (e) {
                Quickshell.execDetached(["hyprctl", "dispatch", cmd]);
            }
        }
    }

    function closeWindow(address) {
        if (address) {
            const cmd = "hl.dsp.window.close({ window = \"address:" + address + "\" })";
            try {
                Hyprland.dispatch(cmd);
            } catch (e) {
                Quickshell.execDetached(["hyprctl", "dispatch", cmd]);
            }
        }
    }

    function monitorFor(screen) {
        return Hyprland.monitorFor(screen);
    }
}
