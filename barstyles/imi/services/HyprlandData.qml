pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Live Hyprland monitor / workspace / window facts, reconstructed on the shell's
// own Quickshell.Hyprland connection. Upstream (Immaterial Impulse) carried a
// service that polled `hyprctl -j`; here the same ipc shapes are read straight
// from the shell's live model, so the bar reads Hyprland without standing up a
// second poller or a second host process.
Singleton {
    id: root

    // One flat monitor ipc record per output (name, id, x, y, width, height,
    // scale, activeWorkspace{id,name}, specialWorkspace{id,name}), exactly the
    // `hyprctl -j monitors` shape the vendored consumers expect.
    readonly property var monitors: {
        const out = [];
        const mons = Hyprland.monitors ? Hyprland.monitors.values : [];
        for (let i = 0; i < mons.length; i++) {
            const o = mons[i] ? mons[i].lastIpcObject : null;
            if (o)
                out.push(o);
        }
        return out;
    }

    // Workspace ipc records keyed by id; each carries `hasfullscreen`, `name`,
    // `monitor`, etc. Used for the bar's fullscreen gate.
    readonly property var workspaceById: {
        const map = ({});
        const wss = Hyprland.workspaces ? Hyprland.workspaces.values : [];
        for (let i = 0; i < wss.length; i++) {
            const o = wss[i] ? wss[i].lastIpcObject : null;
            if (o && o.id !== undefined)
                map[o.id] = o;
        }
        return map;
    }

    // The largest window sitting on a workspace, by pixel area, returned as its
    // raw ipc object (`class`, `title`, `size`, `workspace`). Null when the
    // workspace holds no window.
    function biggestWindowForWorkspace(workspaceId) {
        const tls = Hyprland.toplevels ? Hyprland.toplevels.values : [];
        let best = null;
        let bestArea = -1;
        for (let i = 0; i < tls.length; i++) {
            const o = tls[i] ? tls[i].lastIpcObject : null;
            if (!o || !o.workspace || o.workspace.id !== workspaceId)
                continue;
            const size = o.size || [0, 0];
            const area = (size[0] || 0) * (size[1] || 0);
            if (area > bestArea) {
                bestArea = area;
                best = o;
            }
        }
        return best;
    }
}
