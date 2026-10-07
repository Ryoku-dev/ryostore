pragma ComponentBehavior: Bound
import QtQuick
import Ryoku.Ui.Singletons
import "../../../services"
import ".." as C

NestableObject {
    id: root

    required property var screen
    readonly property string monitorName: screen?.name ?? ""

    readonly property int shownCount: C.Config.options.bar.workspaces.shown
    readonly property bool showAllMonitors: C.Config.options.bar.workspaces.showAllMonitors

    readonly property bool dynamicModel: Wm.workspaceModel === "dynamic" || !WM.isHyprland

    readonly property var liveKeys: {
        const nums = [];
        const named = [];
        const seen = ({});
        const list = Wm.workspaces || [];
        for (let i = 0; i < list.length; i++) {
            const w = list[i];
            if (!w || w.special === true)
                continue;
            if (!root.showAllMonitors && WM.onOtherScreen(w, root.monitorName))
                continue;
            const num = WM.workspaceKey(w);
            const label = (num !== null) ? String(num) : String(w.name ?? "");
            if (label === "" || seen[label])
                continue;
            seen[label] = true;
            if (num !== null)
                nums.push(label);
            else
                named.push(label);
        }
        nums.sort((a, b) => Number(a) - Number(b));
        const out = nums.concat(named);
        if (root.activeKey !== "" && out.indexOf(root.activeKey) === -1)
            out.push(root.activeKey);
        return out;
    }

    readonly property string activeKey: {
        const list = Wm.workspaces || [];
        for (let i = 0; i < list.length; i++) {
            const w = list[i];
            if (!w || WM.onOtherScreen(w, root.monitorName))
                continue;
            if (w.active === true || w.focused === true || w.isActive === true || w.isFocused === true)
                return String(w.name ?? "");
        }
        const focused = Wm.focusedWorkspace;
        if (focused && !WM.onOtherScreen(focused, root.monitorName)
                && focused.name !== undefined && focused.name !== null)
            return String(focused.name);
        return String(WM.activeWorkspaceNumber(root.monitorName));
    }

    readonly property int activeIndex: {
        if (!root.dynamicModel)
            return (root.activeNumber - 1) % root.shownCount;
        return Math.max(0, root.liveKeys.indexOf(root.activeKey));
    }

    readonly property int slotCount: root.dynamicModel ? Math.max(1, root.liveKeys.length) : root.shownCount
    function slotKeyAt(index) {
        if (root.dynamicModel)
            return root.liveKeys[index] ?? "";
        return root.getWorkspaceIdAt(index);
    }

    readonly property int activeNumber: WM.activeWorkspaceNumber(root.monitorName)

    readonly property bool currentWorkspaceNotFake: root.activeWindow !== null && root.activeWindow !== undefined
    readonly property int fakeWorkspace: (root.dynamicModel || currentWorkspaceNotFake) ? -9999 : activeNumber

    readonly property int group: Math.floor((activeNumber - 1) / shownCount)

    readonly property var liveMonitorData: HyprlandData.monitors.find(m => m && m.name === root.monitorName) ?? null
    readonly property var specialWorkspace: liveMonitorData?.specialWorkspace ?? null
    readonly property bool specialWorkspaceActive: Boolean(specialWorkspace && specialWorkspace.id !== 0 && specialWorkspace.name && specialWorkspace.name !== "")
    readonly property string specialWorkspaceName: specialWorkspaceActive ? (specialWorkspace.name.replace("special:", "") || "special") : ""

    readonly property var activeWindow: Wm.focusedWindow

    readonly property list<bool> occupied: {
        const list = Wm.workspaces || [];
        const out = [];
        for (let i = 0; i < root.shownCount; i++) {
            const thisWorkspaceId = root.getWorkspaceId(root.group, i);
            let found = false;
            for (let k = 0; k < list.length; k++) {
                const w = list[k];
                if (!w || w.special === true)
                    continue;
                if (!root.showAllMonitors && WM.onOtherScreen(w, root.monitorName))
                    continue;
                if (WM.workspaceKey(w) === thisWorkspaceId) {
                    found = true;
                    break;
                }
            }
            out.push(found);
        }
        return out;
    }

    readonly property list<var> biggestWindow: {
        const out = [];
        for (let index = 0; index < root.occupied.length; index++)
            out.push(root.biggestWindowForNumber(root.getWorkspaceId(root.group, index)));
        return out;
    }

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
}
