pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Happ state, shared by the bar glyph and the panel. Two feeds, both from
// bin/happ-status: "local" (process + TUN interface + selected server, no
// network, every few seconds) and "geo" (exit IP and country over HTTPS,
// slower, and only while the tunnel is up).
Item {
    id: svc

    property var pluginApi
    readonly property var settings: pluginApi ? pluginApi.pluginSettings : null
    readonly property string script: pluginApi ? pluginApi.pluginDir + "/bin/happ-status" : ""
    readonly property int geoInterval: Math.max(30, (settings && settings.geoInterval) ?? 120)

    property bool running: false
    property bool tun: false
    property string server: ""
    readonly property bool connected: running && tun

    property bool geoOk: false
    property bool geoBusy: false
    property string ip: ""
    property string cc: ""
    property string country: ""
    property string city: ""
    property string isp: ""
    property date checkedAt

    // UI language: Russian when the system locale is Russian, English otherwise.
    readonly property bool ru: Qt.locale().name.startsWith("ru")
    function t(en, ruText) { return svc.ru ? ruText : en; }

    function flag(code) {
        if (!code || code.length !== 2) return "";
        const a = 0x1F1E6, up = code.toUpperCase();
        return String.fromCodePoint(a + up.charCodeAt(0) - 65, a + up.charCodeAt(1) - 65);
    }

    function refresh() {
        if (svc.script === "" || geoProc.running) return;
        svc.geoBusy = true;
        geoProc.running = true;
    }

    function openHapp() {
        Quickshell.execDetached(["/opt/happ/bin/Happ"]);
    }

    onConnectedChanged: {
        if (connected) Qt.callLater(svc.refresh);
        else { svc.geoOk = false; svc.ip = ""; svc.cc = ""; svc.country = ""; svc.city = ""; svc.isp = ""; }
    }
    // A new server picked in Happ: re-check the exit after it settles.
    onServerChanged: if (connected) settle.restart()

    Timer { id: settle; interval: 3000; onTriggered: svc.refresh() }

    Process {
        id: localProc
        command: [svc.script, "local"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(this.text);
                    svc.running = j.running === true;
                    svc.tun = j.tun === true;
                    svc.server = j.server || "";
                } catch (e) {}
            }
        }
    }

    Process {
        id: geoProc
        command: [svc.script, "geo"]
        stdout: StdioCollector {
            onStreamFinished: {
                svc.geoBusy = false;
                svc.checkedAt = new Date();
                try {
                    const j = JSON.parse(this.text);
                    svc.geoOk = j.ok === true;
                    if (svc.geoOk) {
                        svc.ip = j.ip || ""; svc.cc = j.cc || ""; svc.country = j.country || "";
                        svc.city = j.city || ""; svc.isp = j.isp || "";
                    }
                } catch (e) { svc.geoOk = false; }
            }
        }
        onExited: svc.geoBusy = false
    }

    Timer {
        interval: 5000; running: svc.script !== ""; repeat: true; triggeredOnStart: true
        onTriggered: if (!localProc.running) localProc.running = true
    }

    Timer {
        interval: svc.geoInterval * 1000; running: svc.connected; repeat: true
        onTriggered: svc.refresh()
    }
}
