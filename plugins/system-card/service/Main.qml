pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/rarity.js" as Rarity

// service/Main.qml — the card's data layer, no UI. It is the plugin's
// twin of the hub's SysInfo (slow dossier) + LiveStats (fast telemetry):
//   bin/dossier runs the read-only ryoku-sysinfo / ryoku-profile-stats
//     helpers (or /proc fallbacks), then two identity lines: the dbus
//     machine id and `ryoku --version` → the printed parts: user, host,
//     distro, kernel, CPU model, GPU names, RAM and disk totals, uptime,
//     packages, resolution, WM version, codename, palette.
//   bin/poll  → one sample: cpu %, ram %, cpu temp, load, net rates, gpu
//     util/temp/VRAM (nvidia only when awake; amdgpu via sysfs).
// Plus a FileView for the hero figure config in profile.json and one `stat`
// read for the install date. Everything is read-only; every field degrades
// to "-" or 0 when its source is absent.
Item {
    id: svc

    property var pluginApi
    readonly property var settings: pluginApi ? pluginApi.pluginSettings : null

    // The content view mirrors the host's `active` here: nothing polls while
    // the tile is unmounted, exactly like the hub card's `live` gate.
    property bool active: false

    // ---- dossier (ryoku-sysinfo, 20 lines) ----
    property string sysUser: "user"
    property string sysHost: "host"
    property string sysDistro: "Linux"
    property string sysArch: "x86_64"
    property string sysKernel: "-"
    property string sysShell: "sh"
    property string sysCpu: "-"
    property string sysCpuCores: "-"
    property string sysGpu: "-"
    property string sysGpu2: ""
    property string sysRam: "- / -"
    property string sysDisk: "- / -"
    property int sysDiskPct: 0
    property string sysUptime: "-"
    property string sysPackages: "-"
    property string sysResolution: "-"
    property string sysRefresh: ""
    property string codename: "-"
    readonly property string sysWM: {
        const d = Quickshell.env("XDG_CURRENT_DESKTOP") || "";
        return d === "" ? "-" : d.charAt(0).toUpperCase() + d.slice(1);
    }
    // ---- extended dossier (ryoku-profile-stats, 11 lines) ----
    property string sysWm: "-"
    property string sysWmVer: "-"
    property string sysPkgExplicit: "-"
    property string sysPkgAur: "-"
    property string sysPalette: ""
    // ---- identity (dossier tail) ----
    property string machineId: ""
    property string ryokuVersion: ""     // `ryoku --version`, e.g. "v1.1.0"
    property string releaseName: ""      // the edition name, e.g. "Amaterasu"
    property string installDate: ""

    // ---- the collectible face: rarity, code, mark ----
    property string distroId: ""         // os-release ID, the code's --distro
    property string markText: "力"       // brand.json's mark
    property var code: null              // `ryoku-hub profile code` JSON
    readonly property string serial: code && /^[0-9a-f]{16}$/.test(String(code.cardId))
        ? String(code.cardId).slice(0, 6) : ""
    function num(re, s) {
        const m = re.exec(String(s || ""));
        return m ? parseInt(m[1]) : 0;
    }
    readonly property int threads: num(/(\d+)\s*T/, sysCpuCores) || num(/(\d+)/, sysCpuCores)
    readonly property int ramGb: num(/\/\s*(\d+)/, sysRam)
    readonly property int refresh: num(/(\d+)/, sysRefresh)
    readonly property int screenWidth: num(/^(\d+)/, sysResolution)
    readonly property string strongestGpu: Rarity.strongest([sysGpu, sysGpu2])
    readonly property int gpuClass: Rarity.gpuClass(strongestGpu)
    readonly property bool discrete: Rarity.discrete(gpuClass, strongestGpu)
    readonly property var rarity: Rarity.of({ threads: threads, ramGb: ramGb,
        gpus: [sysGpu, sysGpu2], refresh: refresh, width: screenWidth })
    readonly property int level: rarity.level
    readonly property var tier: rarity.tier
    readonly property int power: Rarity.power(threads, ramGb, discrete)
    readonly property string gpuShort: strongestGpu.replace(/NVIDIA |GeForce |AMD |Radeon |Intel | Laptop GPU| Max-Q/gi, "").trim()
    readonly property var codeArgv: distroId.length > 0 && sysCpu !== "-"
        ? ["ryoku-hub", "profile", "code", "--threads", String(threads), "--ram", String(ramGb),
           "--refresh", String(refresh), "--width", String(screenWidth),
           "--gpu-class", String(gpuClass), "--igpu=" + String(Rarity.bothGraphics([sysGpu, sysGpu2])),
           "--gpu", gpuShort, "--distro", distroId, "--wm", sysWM.toLowerCase()]
        : []
    Timer {
        id: codeSettle
        interval: 400
        onTriggered: codeReader.running = true
    }
    onCodeArgvChanged: if (codeArgv.length > 0) codeSettle.restart();
    Process {
        id: codeReader
        command: svc.codeArgv
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    svc.code = JSON.parse(this.text);
                } catch (e) {
                    svc.code = null;
                }
            }
        }
        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0)
                svc.code = null;
        }
    }
    // the set's mark word
    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config"))
            + "/ryoku/brand.json"
        onLoaded: {
            try {
                const b = JSON.parse(text());
                if (b.markText)
                    svc.markText = b.markText;
            } catch (e) {
            }
        }
    }

    // ---- live telemetry (bin/poll) ----
    property int cpu: 0
    property int ram: 0
    property int cpuTemp: 0
    property real load: 0
    property int netDown: 0
    property int netUp: 0
    property int gpuUtil: 0
    property int gpuTemp: 0
    property int gpuVramUsed: 0
    property int gpuVramTotal: 1
    property bool gpuOk: false

    // ---- hero figure config (~/.config/ryoku/profile.json → .hero) ----
    property var heroConfig: ({})
    // the hub's own card store: profile.json is what Settings > About >
    // Customise writes (CardStore wraps ProfileStore). The tile reads it
    // first, so every edit saved in the hub appears here live.
    property var cardStore: ({})
    readonly property string heroKind: heroConfig.kind || "default"
    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME")
        || (Quickshell.env("HOME") + "/.config")) + "/ryoku"

    function bin(name) {
        return (pluginApi ? pluginApi.pluginDir : "") + "/bin/" + name;
    }

    // ---------------- dossier ----------------
    Process {
        id: dossier
        command: [svc.bin("dossier")]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = this.text.split("\n");
                if (l.length < 21)
                    return;                 // keep the last good read
                svc.sysUser = (l[0] || "user").trim();
                svc.sysHost = (l[1] || "host").trim();
                svc.sysDistro = (l[2] || "Linux").trim();
                svc.sysArch = (l[3] || "x86_64").trim();
                svc.sysKernel = (l[4] || "-").trim();
                svc.sysShell = (l[5] || "sh").trim();
                svc.sysCpu = (l[6] || "-").trim();
                svc.sysCpuCores = (l[7] || "-").trim();
                svc.sysGpu = (l[8] || "-").trim();
                svc.sysGpu2 = (l[9] || "").trim();
                svc.sysRam = (l[10] || "- / -").trim();
                svc.sysDisk = (l[12] || "- / -").trim();
                svc.sysDiskPct = parseInt(l[13]) || 0;
                svc.sysUptime = (l[14] || "-").trim();
                svc.sysPackages = (l[15] || "-").trim();
                svc.sysResolution = (l[16] || "-").trim();
                svc.sysRefresh = (l[17] || "").trim();
                if (l[18] && l[18].trim().length > 0)
                    svc.codename = l[18].trim();
                // extended block: same stream, lines 20..30
                dossier.parseExtended(l);
                // identity block: lines 31..33 (machine id, ryoku version, release name)
                svc.machineId = (l[31] || "").trim();
                svc.ryokuVersion = (l[32] || "").trim();
                svc.releaseName = (l[33] || "").trim();
                svc.distroId = (l[34] || "").trim() || "linux";
                dossier.running = false;
            }
        }
        function parseExtended(l) {
            svc.sysWmVer = (l[25] || "-").trim();   // extended: WM version
            svc.sysPkgExplicit = (l[27] || "-").trim();
            svc.sysPkgAur = (l[28] || "-").trim();
            svc.sysPalette = (l[30] || "").trim();
        }
    }
    // first read on enable; a slow 60 s cadence while the tile is mounted,
    // matching the hub's dossier refresh class
    Timer {
        interval: 60000
        running: svc.active
        repeat: true
        triggeredOnStart: true
        onTriggered: dossier.running = true
    }

    // ---------------- live telemetry ----------------
    Process {
        id: poller
        command: [svc.bin("poll")]
        stdout: SplitParser {
            onRead: function (line) {
                const p = line.trim().split(/\s+/);
                if (p.length < 6)
                    return;
                svc.cpu = parseInt(p[0]) || 0;
                svc.ram = parseInt(p[1]) || 0;
                svc.cpuTemp = parseInt(p[2]) || 0;
                svc.load = parseFloat(p[3]) || 0;
                svc.netDown = parseInt(p[4]) || 0;
                svc.netUp = parseInt(p[5]) || 0;
                if (p.length >= 10) {
                    svc.gpuUtil = parseInt(p[6]) || 0;
                    svc.gpuTemp = parseInt(p[7]) || 0;
                    svc.gpuVramUsed = parseInt(p[8]) || 0;
                    svc.gpuVramTotal = parseInt(p[9]) || 1;
                    svc.gpuOk = true;
                }
                poller.running = false;
            }
        }
    }
    Timer {
        interval: Math.max(500, svc.settings ? (svc.settings.pollMs ?? 1500) : 1500)
        running: svc.active
        repeat: true
        triggeredOnStart: true
        onTriggered: poller.running = true
    }

    // the machine's own birth: the root fs creation time, like the hub card's
    Process {
        id: installProbe
        running: true
        command: ["stat", "-c", "%W", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const e = parseInt(this.text.trim());
                svc.installDate = e > 0
                    ? Qt.formatDateTime(new Date(e * 1000), "yyyyMMdd")
                    : "";
                installProbe.running = false;
            }
        }
    }

    // ---------------- hero figure config + hub card store ----------------
    FileView {
        path: svc.configDir + "/profile.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const j = JSON.parse(text());
                svc.cardStore = j;
                svc.heroConfig = j.hero || {};
            } catch (e) {
                svc.cardStore = {};
                svc.heroConfig = {};
            }
            if (svc.codeArgv.length > 0)
                codeSettle.restart();
        }
    }
}
