pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Ryoku.Ui.Singletons as Ryoku

Singleton {
    id: root

    readonly property var monitors: {
        const out = [];
        const mons = Hyprland.monitors ? Hyprland.monitors.values : [];
        for (let i = 0; i < mons.length; i++) {
            const o = mons[i] ? mons[i].lastIpcObject : null;
            if (o)
                out.push(o);
        }
        if (out.length > 0)
            return out;
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            const s = screens[i];
            if (!s)
                continue;
            out.push({
                "name": s.name,
                "id": i,
                "x": 0,
                "y": 0,
                "width": s.width,
                "height": s.height,
                "scale": 1,
                "activeWorkspace": Ryoku.Wm.outputByName(s.name)?.activeWorkspace ?? null,
                "specialWorkspace": { "id": 0, "name": "" }
            });
        }
        return out;
    }

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
        if (best)
            return best;
        const wins = Ryoku.Wm.windows || [];
        for (let i = 0; i < wins.length; i++) {
            const w = wins[i];
            if (!w)
                continue;
            const key = parseInt(String(w.workspace), 10);
            if (key !== workspaceId && String(w.workspace) !== String(workspaceId))
                continue;
            return {
                "class": w.appId ?? w.class ?? "",
                "title": w.title ?? ""
            };
        }
        return null;
    }
}
