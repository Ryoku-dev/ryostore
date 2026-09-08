pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../../services"
import ".." as C

NestableObject {
    id: root

    required property var screen
    readonly property string monitorName: screen?.name ?? ""

    readonly property var hyprMonitor: Hyprland.monitorFor(screen)
    readonly property var liveMonitorData: (HyprlandData.monitors && Array.isArray(HyprlandData.monitors)) ? HyprlandData.monitors.find(m => m && m.id === hyprMonitor?.id) : null

    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel
    readonly property int shownCount: C.Config.options.bar.workspaces.shown
    readonly property bool showAllMonitors: C.Config.options.bar.workspaces.showAllMonitors

    readonly property int activeNumber: hyprMonitor?.activeWorkspace?.id ?? 1

    readonly property bool currentWorkspaceNotFake: activeWindow?.activated ?? false
    readonly property int fakeWorkspace: currentWorkspaceNotFake ? -9999 : activeNumber

    readonly property int group: Math.floor((activeNumber - 1) / shownCount)

    readonly property var specialWorkspace: liveMonitorData?.specialWorkspace
    readonly property bool specialWorkspaceActive: Boolean(specialWorkspace && specialWorkspace.id !== 0 && specialWorkspace.name && specialWorkspace.name !== "")
    readonly property string specialWorkspaceName: specialWorkspaceActive ? (specialWorkspace.name.replace("special:", "") || "special") : ""

    property list<bool> occupied: []
    property list<var> biggestWindow: occupied.map((_, index) => {
        const number = getWorkspaceIdAt(index)
        return root.biggestWindowForNumber(number)
    })

    function getWorkspaceId(group, index) {
        return group * root.shownCount + index + 1
    }
    function getWorkspaceIdAt(index) {
        return root.getWorkspaceId(root.group, index)
    }

    function biggestWindowForNumber(number) {
        if (typeof HyprlandData.biggestWindowForWorkspace === "function") {
            return HyprlandData.biggestWindowForWorkspace(number);
        }
        return null;
    }

    function updateWorkspaceOccupied() {
        root.occupied = Array.from({ length: root.shownCount }, (_, i) => {
            const thisWorkspaceId = getWorkspaceId(root.group, i)
            return Hyprland.workspaces.values.some(ws => ws.id === thisWorkspaceId)
        })
    }

    Component.onCompleted: updateWorkspaceOccupied()

    Connections {
        target: Hyprland.workspaces
        function onValuesChanged() {
            root.updateWorkspaceOccupied()
        }
    }
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            root.updateWorkspaceOccupied()
        }
    }

    onGroupChanged: {
        updateWorkspaceOccupied()
    }
    onShowAllMonitorsChanged: {
        updateWorkspaceOccupied();
    }
}
