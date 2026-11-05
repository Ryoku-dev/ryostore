pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

// service/Main.qml: all state and all piactl calls live here, no UI. The
// widget glyph and the panel both read this one instance through
// pluginApi.mainInstance, so they always agree on the live VPN state.
Item {
    id: svc

    property var pluginApi
    readonly property var settings: pluginApi ? pluginApi.pluginSettings : null

    // -- live state, refreshed on a timer and right after every action ------
    property string connectionState: "Unknown"   // Disconnected, Connecting, Connected, ...
    property string region: ""                   // current region id, or "auto"
    property string pubIp: ""
    property string vpnIp: ""
    property bool busy: false                    // true while connect/disconnect/setRegion run
    property string lastError: ""

    property var regionIds: []
    property bool regionsLoaded: false

    readonly property int pollSeconds: settings && settings.pollSeconds ? settings.pollSeconds : 5

    function validRegionId(id) {
        return typeof id === "string" && /^[a-z0-9-]{1,64}$/.test(id);
    }

    readonly property var favoriteRegions: {
        const raw = settings ? settings.favoriteRegions : "[]";
        try {
            const values = JSON.parse(raw || "[]");
            if (!Array.isArray(values))
                return [];
            return values.filter((id, index) => svc.validRegionId(id)
                && values.indexOf(id) === index);
        } catch (e) {
            return [];
        }
    }

    function isFavorite(id) {
        return svc.favoriteRegions.indexOf(id) !== -1;
    }

    function toggleFavorite(id) {
        if (!svc.pluginApi || !svc.validRegionId(id))
            return;
        const cur = svc.favoriteRegions.slice();
        const idx = cur.indexOf(id);
        if (idx === -1) {
            if (svc.regionIds.indexOf(id) === -1)
                return;
            cur.push(id);
        } else {
            cur.splice(idx, 1);
        }
        svc.pluginApi.saveSetting("favoriteRegions", JSON.stringify(cur));
    }

    // -- one-shot `piactl get <type>` helper ---------------------------------
    // Every argument is a separate argv entry (R9): no shell, no string
    // interpolation of settings or command output.
    function runGet(type, onValue) {
        const p = getComponent.createObject(svc, { argType: type, onValue: onValue });
        p.running = true;
    }

    Component {
        id: getComponent
        Process {
            id: proc
            property string argType: ""
            property var onValue: null
            command: ["piactl", "get", argType]
            stdout: StdioCollector {
                onStreamFinished: {
                    const text = this.text ? this.text.trim() : "";
                    if (proc.onValue)
                        proc.onValue(text);
                    proc.destroy();
                }
            }
            stderr: StdioCollector {
                onStreamFinished: {
                    if (this.text && this.text.trim().length)
                        svc.lastError = this.text.trim();
                }
            }
        }
    }

    function refreshStatus() {
        svc.runGet("connectionstate", (v) => { if (v) svc.connectionState = v; });
        svc.runGet("region", (v) => { if (v) svc.region = v; });
        svc.runGet("pubip", (v) => { svc.pubIp = v; });
        svc.runGet("vpnip", (v) => { svc.vpnIp = v; });
    }

    function refreshRegions() {
        const p = regionsProc.createObject(svc);
        p.running = true;
    }

    Component {
        id: regionsProc
        Process {
            id: proc
            command: ["piactl", "get", "regions"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const lines = (this.text || "").split("\n").map(s => s.trim())
                        .filter((id, index, all) => svc.validRegionId(id)
                            && all.indexOf(id) === index);
                    svc.regionIds = lines;
                    svc.regionsLoaded = true;
                    proc.destroy();
                }
            }
        }
    }

    // -- actions ---------------------------------------------------------
    function connectVpn() {
        svc.runAction(["piactl", "connect"]);
    }

    function disconnectVpn() {
        svc.runAction(["piactl", "disconnect"]);
    }

    function useRegion(id) {
        if (!svc.validRegionId(id) || svc.regionIds.indexOf(id) === -1) {
            svc.lastError = "That PIA region is not available.";
            return;
        }
        svc.busy = true;
        const setProc = actionComponent.createObject(svc, {
            argv: ["piactl", "set", "region", id],
            onDone: () => {
                svc.runAction(["piactl", "connect"]);
            }
        });
        setProc.running = true;
    }

    function runAction(argv) {
        svc.lastError = "";
        svc.busy = true;
        const p = actionComponent.createObject(svc, { argv: argv, onDone: null });
        p.running = true;
    }

    // Open the PIA desktop app. Its own single-instance guard shows the
    // dashboard if it is already running (see the plugin README). pia-client
    // logs its full startup diagnostics to stderr on every launch -- even on
    // the normal "already running, show dashboard" path -- so this one never
    // surfaces stderr as an error; only connectionstate (via refreshStatus)
    // tells us whether anything actually went wrong.
    function openApp() {
        svc.lastError = "";
        const p = appComponent.createObject(svc, {
            argv: ["/opt/piavpn/bin/pia-client", "--quiet"]
        });
        p.running = true;
    }

    Component {
        id: actionComponent
        Process {
            id: proc
            property var argv: []
            property var onDone: null
            command: proc.argv
            stdout: StdioCollector {}
            stderr: StdioCollector { id: errText }
            onExited: (exitCode) => {
                svc.busy = false;
                if (exitCode !== 0 && errText.text && errText.text.trim().length)
                    svc.lastError = errText.text.trim();
                svc.refreshStatus();
                if (proc.onDone)
                    proc.onDone();
                proc.destroy();
            }
        }
    }

    // Separate from actionComponent on purpose: pia-client's stderr is noisy
    // diagnostic logging, not an error channel, so it is never read here.
    Component {
        id: appComponent
        Process {
            id: proc
            property var argv: []
            command: proc.argv
            stdout: StdioCollector {}
            stderr: StdioCollector {}
            onExited: {
                svc.refreshStatus();
                proc.destroy();
            }
        }
    }

    Component.onCompleted: {
        svc.refreshStatus();
        svc.refreshRegions();
    }

    Timer {
        interval: svc.pollSeconds * 1000
        running: true
        repeat: true
        onTriggered: svc.refreshStatus()
    }
}
