pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "Model.js" as Model
import "IconResolver.js" as IconResolver

Item {
    id: svc
    property var pluginApi
    property bool engaged: false
    property bool shown: false
    property bool rendered: false
    property var panelView: null
    property var windows: []
    property var history: []
    property int selected: 0
    property bool workspaceOnly: false
    property int workspaceId: 0
    property string outputName: ""
    property string pendingFocus: ""
    property int showCount: 0
    property var iconIndex: ({})
    function iconFor(window) {
        return IconResolver.forWindow(window, iconIndex, function(cls) { return DesktopEntries.heuristicLookup(cls); });
    }
    Process {
        id: iconLoader
        command: ['ryoku-shell', 'icons']
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try { var data = JSON.parse(text); svc.iconIndex = data.icons || ({}); }
                catch (error) { console.warn('Native Switcher icon index:', error); }
            }
        }
    }
    Timer { id: iconRefresh; interval: 1000; onTriggered: if (!iconLoader.running) iconLoader.running = true }
    Connections { target: DesktopEntries; function onApplicationsChanged() { iconRefresh.restart(); } }

    Process { id: bindingChecker }
    function checkBindings() {
        var script = (svc.pluginApi && svc.pluginApi.pluginDir)
            ? (svc.pluginApi.pluginDir + '/bin/check-bindings')
            : '';
        if (script.length > 0) {
            bindingChecker.command = [script];
            bindingChecker.running = true;
        }
    }
    Timer {
        id: startupCheck
        interval: 2000
        running: true
        repeat: false
        onTriggered: svc.checkBindings()
    }

    readonly property int delayMs: pluginApi && pluginApi.pluginSettings.delayMs !== undefined
        ? Math.max(80, Number(pluginApi.pluginSettings.delayMs)) : 160

    function focusAddress(address) {
        if (!Model.validAddress(address)) return;
        Hyprland.dispatch('hl.dsp.focus({window="address:' + address + '"})');
        Hyprland.dispatch('hl.dsp.window.alter_zorder({mode="top",window="address:' + address + '"})');
    }
    function step(direction, localOnly) {
        if (engaged && localOnly !== undefined && workspaceOnly !== localOnly) cancel();
        if (!engaged) {
            if (dismiss.running) { dismiss.stop(); finishDismiss(); }
            workspaceOnly = localOnly === true;
            var monitor = Hyprland.focusedMonitor;
            workspaceId = monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 0;
            if (focusDelay.running) { focusDelay.stop(); focusAddress(pendingFocus); pendingFocus = ""; }
            var clients = Hyprland.toplevels.values.map(function(t) { return Model.clientFromToplevel(t); });
            var active = Hyprland.activeToplevel ? '0x' + Hyprland.activeToplevel.address.replace(/^0x/, '') : '';
            windows = Model.snapshot(clients, history, active, workspaceOnly ? workspaceId : undefined);
            if (!windows.length || (!workspaceOnly && windows.length < 2)) return;
            outputName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : '';
            selected = direction > 0 ? (windows.length > 1 ? 1 : 0) : windows.length - 1;
            engaged = true;
            reveal.restart();
        } else {
            selected = Model.wrap(selected, direction, windows.length);
        }
    }
    function cancel() {
        reveal.stop(); shown = false; engaged = false;
        if (rendered) dismiss.restart();
    }
    function finishDismiss() {
        rendered = false;
        if (pendingFocus) focusDelay.restart();
    }
    function commit() {
        if (!engaged) return;
        var address = windows[selected] ? windows[selected].address : '';
        var wasShown = shown;
        cancel();
        if (wasShown) { pendingFocus = address; }
        else focusAddress(address);
    }
    function pick(index) {
        if (!engaged || index < 0 || index >= windows.length) return;
        selected = index; commit();
    }
    Timer { id: reveal; interval: svc.delayMs; onTriggered: { if (svc.engaged) { svc.rendered = true; svc.shown = true; svc.showCount++; } } }
    Timer { id: dismiss; interval: 110; onTriggered: svc.finishDismiss() }
    // Event-driven metadata refresh, never idle polling.
    Timer { id: clientRefresh; interval: 30; onTriggered: Hyprland.refreshToplevels() }
    Timer { id: focusDelay; interval: 40; onTriggered: { svc.focusAddress(svc.pendingFocus); svc.pendingFocus = ''; } }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (['openwindow', 'closewindow', 'movewindow', 'movewindowv2'].indexOf(event.name) >= 0) {
                clientRefresh.restart();
                return;
            }
            if (event.name !== 'custom') return;
            if (event.data === 'native-switcher,next') svc.step(1, false);
            else if (event.data === 'native-switcher,prev') svc.step(-1, false);
            else if (event.data === 'native-switcher,local-next') svc.step(1, true);
            else if (event.data === 'native-switcher,local-prev') svc.step(-1, true);
            else if (event.data === 'native-switcher,release') svc.commit();
        }
        function onActiveToplevelChanged() {
            var t = Hyprland.activeToplevel;
            if (t) svc.history = Model.touch(svc.history, '0x' + t.address.replace(/^0x/, ''));
        }
    }
    IpcHandler {
        target: 'native-switcher'
        function next(): void { svc.step(1, false); }
        function prev(): void { svc.step(-1, false); }
        function localNext(): void { svc.step(1, true); }
        function localPrev(): void { svc.step(-1, true); }
        function release(): void { svc.commit(); }
        function cancel(): void { svc.cancel(); }
        function state(): string { return JSON.stringify({engaged:svc.engaged,shown:svc.shown,rendered:svc.rendered,workspaceOnly:svc.workspaceOnly,workspaceId:svc.workspaceId,selected:svc.selected,count:svc.windows.length,showCount:svc.showCount,addresses:svc.windows.map(w=>w.address)}); }
        function motion(): string { return JSON.stringify(svc.panelView ? svc.panelView.motionMetrics() : null); }
        function model(): string { return JSON.stringify(Hyprland.toplevels.values.map(t=>({address:t.address,data:t.lastIpcObject,workspace:t.workspace?t.workspace.name:''}))); }
        function refresh(): void { Hyprland.refreshToplevels(); }
        function icons(): string { return JSON.stringify({indexed:Object.keys(svc.iconIndex).length,windows:svc.windows.map(w=>({app:w.class,source:svc.iconFor(w)}))}); }
        function checkBindings(): void { svc.checkBindings(); }
    }
}
