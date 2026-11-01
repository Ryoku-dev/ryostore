pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import shell.services as RyokuServices
import "modules/drawers" as Drawers
import "services" as CaelestiaServices

Item {
    id: scene

    property var modelData: null
    width: 0
    height: 0

    readonly property bool primary: modelData !== null && Quickshell.screens.length > 0
        && modelData.name === Quickshell.screens[0].name

    function screenFor(name: string): var {
        if (name)
            return Quickshell.screens.find(screen => screen.name === name) || null;
        return Quickshell.screens.find(screen => screen.name === CaelestiaServices.Hypr.focusedMonitor?.name)
            || Quickshell.screens[0] || null;
    }

    function stateFor(name: string): var {
        const screen = screenFor(name);
        return screen ? CaelestiaServices.ShellState.forScreen(screen) : null;
    }

    function componentsFor(name: string): var {
        const screen = screenFor(name);
        return screen ? CaelestiaServices.ShellState.componentsFor(screen) : null;
    }

    function closeState(state): void {
        if (!state)
            return;
        state.launcher = false;
        state.session = false;
        state.sidebar = false;
        state.dashboard = false;
        state.utilities = false;
    }

    function routeSurface(id: string, monitor: string): void {
        const base = id.split("#")[0];
        const state = stateFor(monitor);
        if (!state)
            return;

        if (base === "launcher") {
            const opening = !state.launcher;
            closeState(state);
            state.launcher = opening;
        } else if (base === "settings") {
            const panels = componentsFor(monitor)?.panels;
            if (!panels)
                return;
            const opening = !panels.popouts.isDetached;
            closeState(state);
            if (opening)
                panels.popouts.detach("appearance");
            else
                panels.popouts.close();
        } else if (base === "dashboard") {
            closeState(state);
            state.dashboard = true;
        } else if (base === "session") {
            closeState(state);
            state.session = true;
        } else if (base === "sidebar") {
            closeState(state);
            state.sidebar = true;
        } else if (base === "utilities") {
            closeState(state);
            state.utilities = true;
        }
    }

    Connections {
        target: RyokuServices.ShellState

        function onSurfaceRequested(id, monitor, context): void {
            scene.routeSurface(id, monitor);
        }

        function onSurfaceClosed(id, monitor): void {
            const state = scene.stateFor(monitor);
            if (!state)
                return;
            const base = id.split("#")[0];
            if (!base || base === "launcher")
                state.launcher = false;
            if (!base || base === "session")
                state.session = false;
            if (!base || base === "sidebar")
                state.sidebar = false;
            if (!base || base === "dashboard")
                state.dashboard = false;
            if (!base || base === "settings")
                scene.componentsFor(monitor)?.panels?.popouts.close();
        }
    }

    Loader {
        active: scene.primary
        sourceComponent: Item {
            Component.onCompleted: {
                CaelestiaServices.Notifs;
                CaelestiaServices.Players;
                CaelestiaServices.Brightness;
                CaelestiaServices.Weather.reload();
            }

            Drawers.Drawers {}
        }
    }
}
