pragma Singleton
import QtQuick
import Ryoku.Ui.Singletons

/**
 * Which workspaces a monitor holds, read from the shell's window-manager facade
 * rather than from one compositor's rule readback. The dots use it so a
 * workspace that lives on a screen but is not the focused one still reads as
 * part of that screen's strip.
 *
 * A compositor that only reports a workspace once it exists (the fixed numbered
 * model) contributes nothing for an unvisited declared slot, so the strip falls
 * back to the live set there; a scrolling model reports the whole live set from
 * the start. Either way the split is what the compositor says it is, never a
 * hardcoded monitor name.
 */
Singleton {
    id: root

    readonly property var byMonitor: {
        const map = {};
        const list = Wm.workspaces || [];
        for (let i = 0; i < list.length; i++) {
            const w = list[i];
            if (!w || w.special === true)
                continue;
            const id = parseInt(String(w.name), 10);
            const mon = String(w.output || "");
            if (isNaN(id) || mon === "")
                continue;
            (map[mon] || (map[mon] = [])).push(id);
        }
        for (const k in map)
            map[k].sort((a, b) => a - b);
        return map;
    }
}
