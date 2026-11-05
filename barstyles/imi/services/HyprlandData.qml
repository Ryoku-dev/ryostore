pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Ryoku.Ui.Singletons as RyokuUi

// Compositor data in the shape the ported UI expects, built from the host's
// Wm facade. No direct compositor access: what Wm does not provide reads as
// absent, and consumers already handle that.
Singleton {
    id: root

    readonly property var monitors: RyokuUi.Wm.outputs.map((output, index) => {
        const activeKey = String(output.activeWorkspace ?? "");
        const activeWs = RyokuUi.Wm.workspaceById(activeKey) || RyokuUi.Wm.workspaceByName(activeKey);
        const numericActive = activeWs ? root.numericFor(activeWs) : root.numericForInternalKey(activeKey);
        const specialWs = (RyokuUi.Wm.workspaces ?? []).find(ws => ws.special === true
            && String(ws.output ?? "") === String(output.name ?? ""));
        return {
            id: index,
            name: String(output.name ?? ""),
            activeWorkspace: {
                id: numericActive,
                name: String(activeWs?.name ?? (Number.isFinite(Number(activeKey)) ? activeKey : ""))
            },
            specialWorkspace: specialWs
                ? { id: -99, name: String(specialWs.name ?? "") }
                : { id: 0, name: "" },
            reserved: [0, 0, 0, 0],
            scale: RyokuUi.Wm.outputScale(String(output.name ?? ""))
        };
    })

    // niri reports a stable internal id (random-looking) and keeps the
    // user-facing number in the NAME. Hyprland names carry the number too.
    // The displayed/workspace id is therefore derived from the name, with the
    // internal id mapped alongside for windows (whose workspace field is the
    // internal id).
    readonly property var _rawWorkspaces: RyokuUi.Wm.workspaces ?? []
    function numericFor(raw) {
        const name = String(raw?.name ?? "");
        const fromName = Number(name);
        if (name !== "" && Number.isFinite(fromName))
            return fromName;
        const list = root._rawWorkspaces;
        for (let i = 0; i < list.length; i++)
            if (String(list[i].name ?? "") === name)
                return i + 1;
        return 0;
    }
    // internal (daemon) workspace id -> displayed number; assigned as a whole
    // so the reassignment notifies dependents.
    readonly property var _internalMap: {
        const map = ({});
        const list = root._rawWorkspaces;
        for (let i = 0; i < list.length; i++)
            map[String(list[i].id ?? "")] = root.numericFor(list[i]);
        return map;
    }
    function numericForInternalKey(key) {
        const mapped = root._internalMap[String(key ?? "")];
        if (mapped !== undefined)
            return mapped;
        const fromKey = Number(key);
        return (key !== "" && Number.isFinite(fromKey)) ? fromKey : 0;
    }
    readonly property var workspaces: _rawWorkspaces.map((ws, index) => ({
        id: root.numericFor(ws),
        name: String(ws.name ?? ""),
        monitor: String(ws.output ?? ""),
        active: ws.active === true,
        occupied: ws.occupied === true,
        special: ws.special === true,
        urgent: ws.urgent === true
    }))

    readonly property var workspaceIds: workspaces.map(ws => ws.id)
    readonly property var workspaceById: {
        const map = ({});
        for (const ws of workspaces)
            map[String(ws.id)] = ws;
        return map;
    }

    readonly property var windowList: (RyokuUi.Wm.windows ?? []).map((win) => {
        const monitorIndex = Math.max(0, monitors.findIndex(mon => mon.name === String(win.output ?? "")));
        const wsKey = String(win.workspace ?? "");
        const numericWs = root.numericForInternalKey(wsKey);
        return {
            address: "0x" + String(win.id ?? ""),
            pid: 0,
            class: String(win.appId ?? ""),
            title: String(win.title ?? ""),
            workspace: {
                id: numericWs,
                name: wsKey
            },
            monitor: monitorIndex,
            floating: win.floating === true,
            pinned: false,
            fullscreen: win.toplevel?.fullscreen === true,
            at: [win.x ?? 0, win.y ?? 0],
            size: [win.width ?? 0, win.height ?? 0],
            toplevel: win.toplevel ?? null
        };
    })
    readonly property bool windowListLoaded: RyokuUi.Wm.ready
    readonly property var addresses: windowList.map(win => win.address)
    readonly property var windowByAddress: {
        const map = ({});
        for (const win of windowList)
            map[win.address] = win;
        return map;
    }

    readonly property var activeWorkspace: {
        const focused = root.focusedMonitor;
        return focused ? focused.activeWorkspace : null;
    }
    readonly property var focusedMonitor: monitors.find(mon => mon.name === String(RyokuUi.Wm.focusedOutput ?? "")) ?? null
    readonly property var layers: ({})

    // Raw compositor events, for code that used to watch Hyprland's event
    // stream. The host pushes state through Wm; nothing is emitted here yet.
    signal rawEvent(var event)

    readonly property var focusedWorkspace: {
        const fw = RyokuUi.Wm.focusedWorkspace;
        if (!fw)
            return null;
        return {
            id: root.numericFor(fw),
            name: String(fw.name ?? ""),
            monitor: String(fw.output ?? RyokuUi.Wm.focusedOutput ?? "")
        };
    }

    // Best-effort mapping of the dispatch strings ported code still sends.
    // Known compositor actions map onto Wm; everything else is ignored.
    function dispatch(command) {
        const cmd = String(command ?? "");
        if (cmd.indexOf("window.close") !== -1) {
            const w = RyokuUi.Wm.focusedWindow;
            if (w)
                RyokuUi.Wm.closeWindow(w.id);
        } else if (cmd.indexOf("toggle_special") !== -1) {
            const named = cmd.match(/toggle_special\(['"]([^'"]+)['"]/);
            RyokuUi.Wm.toggleSpecialWorkspace(named ? named[1] : "special");
        } else if (cmd.indexOf("window.float") !== -1) {
            const w = RyokuUi.Wm.focusedWindow;
            if (w && RyokuUi.Wm.caps.windowFloat === true)
                RyokuUi.Wm.floatWindow(w.id);
        } else if (cmd.indexOf("dsp.focus") !== -1) {
            const ws = cmd.match(/workspace\s*=\s*['"]([^'"]+)['"]/);
            if (ws) {
                RyokuUi.Wm.focusWorkspace(ws[1]);
                return;
            }
            const win = cmd.match(/address\s*=\s*['"]([^'"]+)['"]/);
            if (win) {
                const target = root.windowList.find(candidate => candidate.address === win[1])
                    || root.windowByAddress[win[1]];
                if (target)
                    RyokuUi.Wm.focusWindow(target.id);
            }
        }
    }

    function monitorFor(screen) {
        const name = typeof screen === "string" ? screen : String(screen?.name ?? "");
        return root.monitors.find(mon => mon.name === name) ?? null;
    }

    function toplevelsForWorkspace(workspace) {
        const wsId = Number(typeof workspace === "object" ? workspace?.id : workspace);
        return windowList.filter(win => Number(win.workspace?.id) === wsId);
    }

    function hyprlandClientsForWorkspace(workspace) {
        return toplevelsForWorkspace(workspace);
    }

    function clientForToplevel(toplevel) {
        if (!toplevel)
            return null;
        return windowList.find(win => win.toplevel === toplevel
            || (win.class === String(toplevel.appId ?? "") && win.title === String(toplevel.title ?? ""))) ?? null;
    }

    readonly property var visibleWorkspaceIds: {
        const ids = [];
        const activeId = Number(root.activeWorkspace?.id ?? NaN);
        if (isFinite(activeId))
            ids.push(activeId);
        const focused = root.focusedMonitor;
        const specialId = Number(focused?.specialWorkspace?.id ?? 0);
        if (isFinite(specialId) && specialId !== 0)
            ids.push(specialId);
        return ids;
    }

    function toplevelOnScreen(toplevel) {
        const client = root.clientForToplevel(toplevel);
        const ids = root.visibleWorkspaceIds;
        if (!client || ids.length === 0)
            return true;
        const workspaceId = Number(client.workspace?.id ?? NaN);
        return ids.some(id => id === workspaceId);
    }

    function workspaceMapIndex(monitorName) {
        return Math.max(0, root.monitors.findIndex(mon => mon.name === monitorName));
    }

    function monitorHasFullscreenWindow(monitorName) {
        if (!monitorName)
            return false;
        return RyokuUi.Wm.outputHasFullscreen(monitorName);
    }

    function updateWindowList() {
    }
    function updateLayers() {
    }
    function updateMonitors() {
    }
    function updateWorkspaces() {
    }
    function updateAll() {
    }
    function syncAfterEventStream() {
    }
    function syncWorkspaceMap() {
    }
    function syncWorkspaceGroupSize(shown) {
    }

    function specialWindowsShown(monitorName) {
        const monitor = root.monitors.find(candidate => candidate?.name === monitorName);
        if (!monitor)
            return false;
        return Number(monitor.specialWorkspace?.id ?? 0) !== 0
            && windowList.some(win => String(win.workspace?.name ?? "").startsWith("special"));
    }

    function sameWorkspace(a, b) {
        if (!a || !b)
            return false;
        return Number(a.id ?? NaN) === Number(b.id ?? NaN) || String(a.name ?? "") === String(b.name ?? "");
    }

    function biggestWindowForWorkspace(workspaceId) {
        const wins = windowList.filter(win => Number(win.workspace?.id) === Number(workspaceId));
        let best = null;
        for (const win of wins) {
            const area = (win.size?.[0] ?? 0) * (win.size?.[1] ?? 0);
            const bestArea = best ? (best.size?.[0] ?? 0) * (best.size?.[1] ?? 0) : -1;
            if (area > bestArea)
                best = win;
        }
        return best;
    }
}
