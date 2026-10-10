pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
Item {
    id: svc
    property var pluginApi
    readonly property var settings: pluginApi ? pluginApi.pluginSettings : null
    property var status: ({active: false, manual: false, gaming: false, games: 0, error: ""})
    property string configured: ""
    readonly property bool enabled: status.active === true
    function invoke(verb, args) {
        if (!pluginApi || action.running) return;
        action.command = [pluginApi.pluginDir + "/bin/game-memory", verb].concat(args || []);
        action.running = true;
    }
    function toggleManual() { invoke(status.manual ? "off" : "on"); }
    function refresh() {
        if (!pluginApi || query.running || action.running) return;
        var cfg = JSON.stringify({automatic: settings?.automatic ?? true,
            followGaming: settings?.followGaming ?? true, staticImage: settings?.staticImage ?? ""});
        if (cfg !== configured) { configured = cfg; invoke("configure", [cfg]); }
        else { query.command = [pluginApi.pluginDir + "/bin/game-memory", "status"]; query.running = true; }
    }
    Process {
        id: query
        stdout: StdioCollector { onStreamFinished: { try { svc.status = JSON.parse(text); } catch (e) {} } }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) svc.status = Object.assign({}, svc.status, {error: text.trim()}); }
    }
    Process {
        id: action
        stdout: StdioCollector { onStreamFinished: { try { svc.status = JSON.parse(text); } catch (e) {} } }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) svc.status = Object.assign({}, svc.status, {error: text.trim()}); }
        onExited: (code, exitStatus) => { if (code !== 0) svc.configured = ""; }
    }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: svc.refresh() }
}
