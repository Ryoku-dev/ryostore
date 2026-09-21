pragma Singleton
import QtQuick
import Quickshell
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
            const id = root.workspaceKey(w);
            const mon = String(w.output || "");
            if (id === null || mon === "")
                continue;
            (map[mon] || (map[mon] = [])).push(id);
        }
        for (const k in map)
            map[k].sort((a, b) => a - b);
        return map;
    }

    /**
     * Resolve a stable, sortable integer identity for a workspace across
     * compositor models. Hyprland names a workspace after its global numeric
     * id ("1", "2", ...), so parsing [[name]] is enough on its own. Niri
     * workspaces are commonly left unnamed -- a user only names the ones
     * they bother to -- and are otherwise identified by their per-output
     * position ([[idx]]) or their global [[id]], so this falls back through
     * those before giving up on the workspace. Returns null when nothing
     * usable is found (e.g. a genuinely unindexed special workspace).
     */
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

    /**
     * Resolve the active workspace's key for one output. The earlier
     * approach parsed [[Wm.outputByName]]'s [[activeWorkspace]] straight as
     * an int, which works when a workspace's identity IS a number
     * (Hyprland), but breaks the moment a workspace is given a name
     * (`workspace "chat"` in niri's .kdl config) -- [[activeWorkspace]] then
     * holds that name string, and parsing it as an int always fails, so the
     * active dot never updates.
     *
     * Instead this first looks for an explicit active/focused flag on the
     * workspace entries themselves (niri's IPC reports `is_active` /
     * `is_focused` per workspace, which a sane facade will carry through
     * under some boolean field), then falls back to matching
     * [[activeWorkspace]]'s raw value against each candidate's name, idx or
     * id as a string -- so a named workspace matches by name instead of
     * requiring it to be numeric.
     */
    function activeKeyFor(screenName) {
        const list = Wm.workspaces || [];
        for (let i = 0; i < list.length; i++) {
            const w = list[i];
            if (!w || w.output !== screenName)
                continue;
            if (w.active === true || w.focused === true || w.isActive === true || w.isFocused === true)
                return root.workspaceKey(w);
        }

        const mon = Wm.outputByName(screenName);
        const aw = mon && mon.activeWorkspace;
        if (aw === undefined || aw === null || aw === "")
            return null;
        if (typeof aw === "object")
            return root.workspaceKey(aw);

        const awStr = String(aw);
        for (let i = 0; i < list.length; i++) {
            const w = list[i];
            if (!w || w.output !== screenName)
                continue;
            if (String(w.name) === awStr || String(w.idx) === awStr || String(w.id) === awStr)
                return root.workspaceKey(w);
        }

        // Nothing matched by identity; last resort for a plain numeric value.
        const n = parseInt(awStr, 10);
        return isNaN(n) ? null : n;
    }
}
