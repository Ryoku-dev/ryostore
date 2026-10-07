pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Ryoku.Ui.Singletons as Ryoku

Singleton {
    id: root

    readonly property bool isHyprland: (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "") !== ""

    readonly property var focusedMonitor: ({ "name": Ryoku.Wm.focusedOutput ?? "" })

    function workspaceKey(w) {
        if (!w)
            return null;
        const name = parseInt(String(w.name), 10);
        if (!isNaN(name) && name >= 1)
            return name;
        const idx = parseInt(String(w.idx), 10);
        if (!isNaN(idx) && idx >= 1)
            return idx;
        const id = parseInt(String(w.id), 10);
        if (!isNaN(id) && id >= 1)
            return id;
        return null;
    }

    function onOtherScreen(w, screenName) {
        if (screenName === undefined || screenName === null || String(screenName) === "")
            return false;
        const out = (w && w.output !== undefined && w.output !== null) ? String(w.output) : "";
        return out !== "" && out !== String(screenName);
    }

    function activeWorkspaceNumber(screenName) {
        const list = Ryoku.Wm.workspaces || [];
        for (let i = 0; i < list.length; i++) {
            const w = list[i];
            if (!w)
                continue;
            if (root.onOtherScreen(w, screenName))
                continue;
            if (w.active === true || w.focused === true || w.isActive === true || w.isFocused === true) {
                const key = root.workspaceKey(w);
                if (key !== null)
                    return key;
            }
        }
        const focused = Ryoku.Wm.focusedWorkspace;
        if (focused && !root.onOtherScreen(focused, screenName)) {
            const key = root.workspaceKey(focused);
            if (key !== null)
                return key;
        }
        return 1;
    }

    function switchWorkspace(id) {
        if (id === undefined || id === null || id === "")
            return;
        if (!root.isHyprland) {
            Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(id)]);
            return;
        }
        Ryoku.Wm.focusWorkspace(String(id));
    }

    function switchWorkspaceRelative(direction) {
        if (!root.isHyprland) {
            const step = direction === "next" ? 1 : -1;
            const target = Math.max(1, root.activeWorkspaceNumber("") + step);
            Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(target)]);
            return;
        }
        Ryoku.Wm.cycleWorkspace(direction === "next" ? 1 : -1);
    }

    function focusWindow(address) {
        if (address && root.isHyprland) {
            const cmd = "hl.dsp.focus({ window = \"address:" + address + "\" })";
            try {
                Hyprland.dispatch(cmd);
            } catch (e) {
                Quickshell.execDetached(["hyprctl", "dispatch", cmd]);
            }
        }
    }

    function closeWindow(address) {
        if (address && root.isHyprland) {
            const cmd = "hl.dsp.window.close({ window = \"address:" + address + "\" })";
            try {
                Hyprland.dispatch(cmd);
            } catch (e) {
                Quickshell.execDetached(["hyprctl", "dispatch", cmd]);
            }
        }
    }

    function moveWindowToWorkspace(windowId, workspace) {
        if (windowId === undefined || windowId === null || workspace === undefined || workspace === null)
            return;
        const addr = String(windowId).replace(/^0x/, "");
        const isAddress = /^[0-9a-fA-F]+$/.test(addr);
        if (root.isHyprland && isAddress) {
            const cmd = "hl.dsp.window.move({ workspace = " + workspace + ", follow = false, window = \"address:0x" + addr + "\" })";
            try {
                Hyprland.dispatch(cmd);
            } catch (e) {
                Quickshell.execDetached(["hyprctl", "dispatch", cmd]);
            }
            return;
        }
        try {
            Ryoku.Wm.moveWindowToWorkspace(String(windowId), String(workspace));
        } catch (e) {
        }
    }

    function monitorFor(screen) {
        if (root.isHyprland) {
            const mon = Hyprland.monitorFor(screen);
            if (mon)
                return mon;
        }
        const name = screen?.name ?? "";
        return name ? { "name": name } : null;
    }
}
