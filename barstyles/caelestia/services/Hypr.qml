pragma Singleton

import QtQuick
import Quickshell
import Ryoku.Ui.Singletons
import "../port/i18n"

Singleton {
    id: root

    readonly property bool usingLua: false
    readonly property var model: {
        const outputs = Wm.outputs || [];
        const sourceWorkspaces = Wm.workspaces || [];
        const sourceWindows = Wm.windows || [];
        const monitors = [];
        const monitorByName = {};
        const screens = Quickshell.screens || [];

        for (let i = 0; i < Math.max(outputs.length, screens.length); i++) {
            const output = outputs[i] || {};
            const screen = screens.find(candidate => candidate.name === output.name) || screens[i] || null;
            const name = output.name || screen?.name || "";
            const monitor = {
                id: i,
                name,
                focused: name === Wm.focusedOutput,
                screen,
                activeWorkspace: null,
                lastIpcObject: {
                    specialWorkspace: { id: 0, name: "" }
                }
            };
            monitors.push(monitor);
            monitorByName[name] = monitor;
        }

        const workspaces = sourceWorkspaces.map((workspace, index) => {
            const numericId = Number(workspace.id);
            const id = Number.isFinite(numericId) ? numericId : Number(workspace.index ?? index + 1);
            return {
                id,
                name: String(workspace.name ?? workspace.id ?? id),
                monitor: monitorByName[workspace.output] || monitors[0] || null,
                active: workspace.active === true,
                special: workspace.special === true,
                lastIpcObject: {
                    windows: Number(workspace.windows || 0),
                    fullscreen: workspace.fullscreen === true
                },
                toplevels: { values: [] }
            };
        });

        const toplevels = sourceWindows.map(window => {
            const workspace = workspaces.find(candidate => String(candidate.id) === String(window.workspace)
                || candidate.name === String(window.workspace)) || null;
            const ipc = {
                address: window.id,
                class: window.appId || "",
                floating: window.floating === true,
                fullscreen: window.toplevel?.fullscreen === true ? 2 : 0,
                mapped: true,
                pid: 0,
                pinned: false,
                tags: [],
                title: window.title || ""
            };
            const toplevel = {
                address: window.id,
                title: window.title || "",
                workspace,
                wayland: window.toplevel || null,
                lastIpcObject: ipc,
                activate: () => Wm.focusWindow(window.id),
                close: () => Wm.closeWindow(window.id)
            };
            if (workspace)
                workspace.toplevels.values.push(toplevel);
            return toplevel;
        });

        for (const monitor of monitors) {
            const output = outputs.find(candidate => candidate.name === monitor.name) || {};
            monitor.activeWorkspace = workspaces.find(workspace => workspace.monitor === monitor
                && (workspace.active || String(workspace.id) === String(output.activeWorkspace)
                    || workspace.name === String(output.activeWorkspace)))
                || workspaces.find(workspace => workspace.monitor === monitor) || null;
            const special = workspaces.find(workspace => workspace.monitor === monitor && workspace.special && workspace.active);
            if (special)
                monitor.lastIpcObject.specialWorkspace = { id: special.id, name: special.name };
        }

        return { monitors, workspaces, toplevels };
    }

    readonly property var monitors: ({ values: model.monitors })
    readonly property var workspaces: ({ values: model.workspaces })
    readonly property var toplevels: ({ values: model.toplevels })
    readonly property var focusedMonitor: model.monitors.find(monitor => monitor.focused) || model.monitors[0] || null
    readonly property var focusedWorkspace: focusedMonitor?.activeWorkspace ?? null
    readonly property var activeToplevel: {
        const focused = Wm.focusedWindow;
        return focused ? model.toplevels.find(toplevel => String(toplevel.address) === String(focused.id)) || null : null;
    }
    readonly property var activeWsId: focusedWorkspace?.id ?? 1
    readonly property bool capsLock: false
    readonly property bool numLock: false
    readonly property string defaultKbLayout: Wm.keyboardLayouts?.[0] ?? "??"
    readonly property string kbLayoutFull: Wm.keyboardLayout || Tr.trCtx("Unknown", "keyboard layout")
    readonly property string kbLayout: kbLayoutFull.slice(0, 3).toLowerCase()
    readonly property var kbMap: new Map()
    property string lastSpecialWorkspace: ""

    readonly property QtObject extras: QtObject {
        readonly property var options: ({})
        readonly property QtObject devices: QtObject {
            readonly property var keyboards: []
        }
        function batchMessage(requests): void {}
        function refreshDevices(): void {}
    }
    readonly property var options: extras.options
    readonly property var devices: extras.devices

    signal configReloaded

    function dispatch(request: string): void {
        const cycle = request.match(/^workspace\s+r([+-])1$/);
        if (cycle) {
            Wm.cycleWorkspace(cycle[1] === "+" ? 1 : -1);
            return;
        }
        const focus = request.match(/^workspace\s+(.+)$/);
        if (focus) {
            Wm.focusWorkspace(focus[1]);
            return;
        }
        const special = request.match(/^togglespecialworkspace\s*(.*)$/);
        if (special)
            Wm.toggleSpecialWorkspace(special[1]);
    }

    function focusWorkspace(workspace): void {
        Wm.focusWorkspace(workspace);
    }

    function toggleSpecial(name: string): void {
        Wm.toggleSpecialWorkspace(name);
    }

    function cycleSpecialWorkspace(direction: string): void {
        const open = model.workspaces.filter(workspace => workspace.special && workspace.lastIpcObject.windows > 0);
        if (!open.length)
            return;
        const active = open.findIndex(workspace => workspace.active);
        const delta = direction === "next" ? 1 : -1;
        const index = active < 0 ? 0 : (active + delta + open.length) % open.length;
        Wm.toggleSpecialWorkspace(trimWsName(open[index].name));
    }

    function monitorNames(): list<string> {
        return model.monitors.map(monitor => monitor.name);
    }

    function monitorFor(screen: ShellScreen): var {
        return model.monitors.find(monitor => monitor.name === screen?.name) || model.monitors[0] || null;
    }

    function trimWsName(name: string): string {
        return name.startsWith("special:") ? name.slice("special:".length) : name;
    }

    function toplevelsForWs(workspace, ignoredTags = []): var {
        return model.toplevels.filter(toplevel => toplevel.workspace
            && String(toplevel.workspace.id) === String(workspace)
            && !isToplevelIgnored(toplevel, ignoredTags));
    }

    function isToplevelIgnored(toplevel, ignoredTags = []): bool {
        const ipc = toplevel?.lastIpcObject;
        return !ipc?.class || !ipc.mapped || (ipc.tags?.some(tag => ignoredTags.includes(tag.replace(/\*$/, ""))) ?? false);
    }

    function reloadDynamicConfs(): void {
        Wm.reloadConfig("");
    }
}
