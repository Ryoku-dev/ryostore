pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Logic only. Runs bin/gpu-stat.sh every 2 s (every 1 s while the panel is open)
// and turns its snapshot into the values the widget and panel show. The script
// picks the GPU (i915, xe, amdgpu or nvidia) and reports a common set of keys;
// anything a GPU doesn't provide stays "unknown" and the panel hides that row.
// Nothing here writes anywhere and nothing needs root.
Item {
    id: svc

    property var pluginApi
    readonly property var settings: pluginApi ? pluginApi.pluginSettings : null
    readonly property bool panelOpen: pluginApi ? pluginApi.panelOpen === true : false
    readonly property string terminal: settings && settings.terminal ? String(settings.terminal) : "kitty"
    readonly property string gpuChoice: settings && settings.gpu ? String(settings.gpu) : "auto"

    // ── live values (-1 / "" = unknown) ──
    property bool found: true
    property bool ready: false
    property string driver: ""
    property string pci: ""
    property real busy: 0
    property real mediaBusy: -1
    property real actMhz: -1
    property real curMhz: -1
    property real maxMhz: -1
    property real minMhz: -1
    property real temp: -1
    property string tempSrc: ""
    property real vramUsed: -1
    property real vramTotal: -1
    property bool throttleKnown: false
    property string throttle: ""
    property string gpuName: ""
    property string codename: ""
    property var history: []
    property var topProcs: []

    // previous sample, for deltas
    property real _t: 0
    property real _rc6: -1
    property var _prev: ({})

    function n(v) {
        var x = parseFloat(v);
        return isFinite(x) ? x : -1;
    }

    function vendor(drv) {
        if (drv === "i915" || drv === "xe")
            return "Intel";
        if (drv === "amdgpu")
            return "AMD";
        if (drv === "nvidia")
            return "NVIDIA";
        return "";
    }

    function pushHistory(v) {
        var h = svc.history.slice();
        h.push(v);
        if (h.length > 60)
            h.shift();
        svc.history = h;
    }

    function parse(raw) {
        var kv = {};
        var procs = {};
        var direct = [];
        String(raw || "").split("\n").forEach(function(line) {
            if (line.indexOf("p\t") === 0) {
                var f = line.split("\t");
                procs[f[1]] = { r: Math.max(0, svc.n(f[2])), m: Math.max(0, svc.n(f[3])),
                                tot: Math.max(0, svc.n(f[4])), name: f[5] || f[1] };
                return;
            }
            if (line.indexOf("q\t") === 0) {
                var g = line.split("\t");
                direct.push({ name: g[3] || g[1], pct: Math.max(0, svc.n(g[2])) });
                return;
            }
            var i = line.indexOf("=");
            if (i > 0)
                kv[line.slice(0, i)] = line.slice(i + 1).trim();
        });

        if (kv.ok !== "1") {
            svc.found = false;
            svc.ready = false;
            return;
        }
        svc.found = true;

        if (kv.driver !== svc.driver || kv.pci !== svc.pci) {
            // GPU changed (setting edited): start the deltas over.
            svc.driver = kv.driver || "";
            svc.pci = kv.pci || "";
            svc._t = 0;
            svc._rc6 = -1;
            svc._prev = ({});
            svc.history = [];
            svc.ready = false;
            svc.codename = "";
            svc.gpuName = svc.vendor(svc.driver) + " GPU";
            if (kv.name)
                svc.gpuName = kv.name;
            else if (svc.pci !== "")
                nameProc.running = true;
        }

        var t = svc.n(kv.t);
        var dt = svc._t > 0 ? t - svc._t : 0;      // ms
        var cap = Math.max(1, svc.n(kv.cap));
        var cycles = kv.unit === "cycles";

        // ── busy % ──
        var busy = -1;
        var media = -1;
        if (kv.busy !== undefined && kv.busy !== "") {
            busy = svc.n(kv.busy);                  // AMD and NVIDIA report it directly
        } else if (dt > 0) {
            // Intel: sum of every client's engine time over the interval.
            var dR = 0, dM = 0, dTot = 0, shared = 0;
            for (var pid in procs) {
                var p = svc._prev[pid];
                if (!p)
                    continue;
                shared++;
                dR += Math.max(0, procs[pid].r - p.r);
                dM += Math.max(0, procs[pid].m - p.m);
                dTot = Math.max(dTot, procs[pid].tot - p.tot);
            }
            var denom = cycles ? dTot : dt * 1e6;
            if (shared > 0 && denom > 0) {
                busy = Math.min(100, 100 * dR / denom);
                media = Math.min(100, 100 * dM / (denom * cap));
            } else if (svc._rc6 >= 0 && svc.n(kv.rc6) >= 0) {
                // Fallback: RC6 residency (time awake, slightly overstates load).
                busy = Math.max(0, Math.min(100, 100 * (1 - (svc.n(kv.rc6) - svc._rc6) / dt)));
            }
        }
        if (busy >= 0) {
            svc.busy = busy;
            svc.ready = true;
            svc.pushHistory(busy);
        }
        svc.mediaBusy = media;

        // ── top processes ──
        if (direct.length > 0) {
            direct.sort(function(a, b) { return b.pct - a.pct; });
            svc.topProcs = direct.filter(function(x) { return x.pct > 0; }).slice(0, 3);
        } else if (dt > 0 && Object.keys(procs).length > 0) {
            var out = [];
            var dTot2 = 0;
            for (var q in procs) {
                if (svc._prev[q])
                    dTot2 = Math.max(dTot2, procs[q].tot - svc._prev[q].tot);
            }
            var den = cycles ? dTot2 : dt * 1e6;
            for (var k in procs) {
                var pv = svc._prev[k];
                if (!pv || den <= 0)
                    continue;
                var pct = 100 * ((procs[k].r - pv.r) + (procs[k].m - pv.m)) / den;
                if (pct > 0.05)
                    out.push({ name: procs[k].name, pct: Math.min(100, pct) });
            }
            out.sort(function(a, b) { return b.pct - a.pct; });
            svc.topProcs = out.slice(0, 3);
        } else if (!svc.panelOpen) {
            svc.topProcs = [];
        }

        svc._prev = procs;
        svc._t = t;
        svc._rc6 = svc.n(kv.rc6);

        // ── the rest ──
        svc.actMhz = svc.n(kv.act);
        svc.curMhz = svc.n(kv.cur);
        svc.maxMhz = svc.n(kv.max);
        svc.minMhz = svc.n(kv.min);
        var tm = svc.n(kv.temp);
        svc.temp = tm >= 0 ? tm / 1000 : -1;
        svc.tempSrc = kv.temp_src || "";
        svc.vramUsed = svc.n(kv.vram_used);
        svc.vramTotal = svc.n(kv.vram_total);
        svc.throttleKnown = kv.throttle !== undefined;
        svc.throttle = kv.throttle || "";
    }

    // lspci -vmm: "Device:\tArrow Lake-P [Arc Pro 130T/140T]"
    function parseName(raw) {
        var m = String(raw || "").match(/^Device:\s*(.+)$/m);
        if (!m)
            return;
        var dev = m[1].trim();
        var b = dev.match(/^(.*?)\s*\[(.+)\]\s*$/);
        var v = svc.vendor(svc.driver);
        if (b) {
            svc.codename = b[1];
            svc.gpuName = (v ? v + " " : "") + b[2];
        } else {
            svc.codename = "";
            svc.gpuName = (v ? v + " " : "") + dev;
        }
    }

    function openMonitor() {
        Quickshell.execDetached([svc.terminal, "-e", "btop"]);
        if (svc.pluginApi)
            svc.pluginApi.closePanel();
    }

    Process {
        id: statProc
        command: [svc.pluginApi ? svc.pluginApi.pluginDir + "/bin/gpu-stat.sh" : "",
                  svc.gpuChoice, svc.panelOpen ? "top" : ""]
        stdout: StdioCollector {
            onStreamFinished: svc.parse(text)
        }
    }

    Process {
        id: nameProc
        command: ["lspci", "-vmm", "-s", svc.pci]
        stdout: StdioCollector {
            onStreamFinished: svc.parseName(text)
        }
    }

    Timer {
        interval: svc.panelOpen ? 1000 : 2000
        running: svc.pluginApi !== null && svc.pluginApi !== undefined
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!statProc.running) statProc.running = true
    }
}
