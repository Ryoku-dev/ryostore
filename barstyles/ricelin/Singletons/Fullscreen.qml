pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Ryoku.Ui.Singletons

/**
 * Runtime fullscreen state shared by the Ricelin scene.
 *
 * Hyprland: use Ryoku's native Wm fullscreen state.
 * Niri 26.04: its public IPC does not expose an explicit fullscreen field, so
 * consume the low-cost event stream and identify a focused non-floating window
 * whose Wayland window size matches the output's logical size. This detects real
 * fullscreen without mistaking niri's windowed-fullscreen for real fullscreen.
 */
Singleton {
    id: root

    readonly property bool isNiri: (Quickshell.env("NIRI_SOCKET") || "").length > 0
    property var niriWindows: ({})

    function screenByName(name) {
        const screens = Quickshell.screens || [];
        for (let i = 0; i < screens.length; i++) {
            const screen = screens[i];
            if (screen && screen.name === name)
                return screen;
        }
        return null;
    }

    function workspaceOutput(workspaceId) {
        if (workspaceId === undefined || workspaceId === null)
            return "";

        const workspaces = Wm.workspaces || [];
        for (let i = 0; i < workspaces.length; i++) {
            const ws = workspaces[i];
            if (!ws)
                continue;

            const id = ws.id !== undefined ? ws.id
                : (ws.workspaceId !== undefined ? ws.workspaceId : undefined);
            if (id !== undefined && String(id) === String(workspaceId))
                return String(ws.output || "");
        }

        // A focused fullscreen window should be on the focused output. This is
        // only a fallback for the short interval before Wm has refreshed.
        return Wm.focusedOutput || "";
    }

    function nearlyEqual(a, b) {
        return Math.abs(Number(a) - Number(b)) <= 2;
    }

    function niriFullscreen(name) {
        const screen = root.screenByName(name);
        if (!screen)
            return false;

        for (const key in root.niriWindows) {
            const win = root.niriWindows[key];
            if (!win || win.is_focused !== true || win.is_floating === true)
                continue;

            if (root.workspaceOutput(win.workspace_id) !== name)
                continue;

            const size = win.layout && win.layout.window_size;
            if (!size || size.length < 2)
                continue;

            // Niri fullscreen uses the complete output size. Maximized-to-edges
            // still respects the bar's exclusive zone, so its height differs.
            if (root.nearlyEqual(size[0], screen.width)
                && root.nearlyEqual(size[1], screen.height)) {
                return true;
            }
        }

        return false;
    }

    function outputHasFullscreen(name) {
        if (root.isNiri)
            return root.niriFullscreen(name);
        return Wm.outputHasFullscreen(name);
    }

    function replaceWindow(win) {
        if (!win || win.id === undefined)
            return;
        const next = Object.assign({}, root.niriWindows);
        next[String(win.id)] = win;
        root.niriWindows = next;
    }

    function removeWindow(id) {
        const next = Object.assign({}, root.niriWindows);
        delete next[String(id)];
        root.niriWindows = next;
    }

    function setFocused(id) {
        const next = Object.assign({}, root.niriWindows);
        for (const key in next) {
            if (next[key])
                next[key] = Object.assign({}, next[key], {
                    is_focused: String(next[key].id) === String(id)
                });
        }
        root.niriWindows = next;
    }

    function setLayout(id, layout) {
        const key = String(id);
        if (!root.niriWindows[key])
            return;
        const next = Object.assign({}, root.niriWindows);
        next[key] = Object.assign({}, next[key], { layout: layout });
        root.niriWindows = next;
    }

    function consume(line) {
        if (!line)
            return;

        let event;
        try {
            event = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (!event || typeof event !== "object")
            return;

        if (event.WindowsChanged) {
            const next = {};
            const windows = event.WindowsChanged.windows || [];
            for (let i = 0; i < windows.length; i++) {
                const win = windows[i];
                if (win && win.id !== undefined)
                    next[String(win.id)] = win;
            }
            root.niriWindows = next;
            return;
        }

        if (event.WindowOpenedOrChanged) {
            root.replaceWindow(event.WindowOpenedOrChanged.window);
            return;
        }

        if (event.WindowFocusChanged) {
            root.setFocused(event.WindowFocusChanged.id);
            return;
        }

        if (event.WindowLayoutsChanged) {
            const changes = event.WindowLayoutsChanged.changes || [];
            for (let i = 0; i < changes.length; i++) {
                const change = changes[i];
                if (change && change.length >= 2)
                    root.setLayout(change[0], change[1]);
            }
            return;
        }

        if (event.WindowClosed) {
            root.removeWindow(event.WindowClosed.id);
        }
    }

    Process {
        id: niriStream
        running: root.isNiri
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            onRead: (line) => root.consume(line)
        }
        onExited: if (root.isNiri) restart.start()
    }

    Timer {
        id: restart
        interval: 1000
        repeat: false
        onTriggered: if (root.isNiri) niriStream.running = true
    }
}
