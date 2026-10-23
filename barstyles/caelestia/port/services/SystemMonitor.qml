import QtQuick
import Quickshell.Io
import shell.services

// The dashboard's per-core, frequency, swap and disk I/O readings, from /proc on a
// 1.5 s tick while active. The rest of the plugin-era SystemMonitor has no source
// here: no VRAM or drive temperature readout.
Item {
    id: root

    property bool active: false
    property int sampleCount: 0

    readonly property real cpuPercent: Sysinfo.cpu * 100
    readonly property real cpuTemp: Sysinfo.tempC
    property var coreLoads: []
    readonly property int coreCount: coreLoads.length
    property real cpuFrequencyGhz: 0
    property real swapUsedGiB: 0
    property real swapTotalGiB: 0
    property real diskReadBytesPerSec: 0
    property real diskWriteBytesPerSec: 0
    readonly property bool gpuMemoryAvailable: false
    readonly property real gpuMemoryUsedGiB: 0
    readonly property real gpuMemoryTotalGiB: 0
    readonly property bool storageTempAvailable: false
    readonly property real storageTemp: 0

    property var _prevCores: []
    property var _prevDisk: null
    property real _prevTime: 0

    // per-core percent (0..100) from the "cpuN ..." lines' busy share since last tick
    function readStat(text: string): void {
        const cores = [];
        for (const line of text.split("\n")) {
            const p = line.trim().split(/\s+/);
            if (!/^cpu\d+$/.test(p[0]))
                continue;
            const v = p.slice(1).map(Number);
            const total = v.reduce((a, b) => a + b, 0);
            cores.push({ total: total, idle: (v[3] || 0) + (v[4] || 0) });
        }
        if (_prevCores.length === cores.length)
            coreLoads = cores.map((c, i) => {
                const dt = c.total - _prevCores[i].total;
                return dt > 0 ? Math.max(0, Math.min(100, (1 - (c.idle - _prevCores[i].idle) / dt) * 100)) : 0;
            });
        _prevCores = cores;
    }

    function readCpuInfo(text: string): void {
        const re = /^cpu MHz\s*:\s*([\d.]+)/gm, mhz = [];
        for (let m = re.exec(text); m; m = re.exec(text))
            mhz.push(Number(m[1]));
        cpuFrequencyGhz = mhz.length ? Math.max(...mhz) / 1000 : 0;
    }

    function readMemInfo(text: string): void {
        const kib = key => Number((text.match(new RegExp(`^${key}:\\s+(\\d+)`, "m")) || [])[1] || 0);
        swapTotalGiB = kib("SwapTotal") / 1048576;
        swapUsedGiB = (kib("SwapTotal") - kib("SwapFree")) / 1048576;
    }

    // whole disks only (sdX, nvmeXnY, vdX, mmcblkN), sectors are 512 bytes
    function readDiskStats(text: string): void {
        let read = 0, written = 0;
        for (const line of text.split("\n")) {
            const p = line.trim().split(/\s+/);
            if (!/^(sd[a-z]+|vd[a-z]+|nvme\d+n\d+|mmcblk\d+)$/.test(p[2] || ""))
                continue;
            read += Number(p[5]) * 512;
            written += Number(p[9]) * 512;
        }
        const now = Date.now();
        if (_prevDisk && now > _prevTime) {
            const s = (now - _prevTime) / 1000;
            diskReadBytesPerSec = Math.max(0, (read - _prevDisk.read) / s);
            diskWriteBytesPerSec = Math.max(0, (written - _prevDisk.written) / s);
        }
        _prevDisk = { read: read, written: written };
        _prevTime = now;
    }

    onActiveChanged: Sysinfo.setActive(root, active)
    Component.onDestruction: Sysinfo.setActive(root, false)

    FileView { id: stat; path: "/proc/stat"; blockLoading: true; printErrors: false; onLoaded: root.readStat(text()) }
    FileView { id: cpuinfo; path: "/proc/cpuinfo"; blockLoading: true; printErrors: false; onLoaded: root.readCpuInfo(text()) }
    FileView { id: meminfo; path: "/proc/meminfo"; blockLoading: true; printErrors: false; onLoaded: root.readMemInfo(text()) }
    FileView { id: diskstats; path: "/proc/diskstats"; blockLoading: true; printErrors: false; onLoaded: root.readDiskStats(text()) }

    Timer {
        interval: 1500
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            cpuinfo.reload();
            meminfo.reload();
            diskstats.reload();
            root.sampleCount++;
        }
    }
}
