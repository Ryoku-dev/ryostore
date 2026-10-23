pragma Singleton

import Quickshell
import shell.services

Singleton {
    id: root

    // Sysinfo reports GiB; Caelestia consumers pass Memory.used/total to Units.formatKibUsage.
    readonly property real _kibPerGib: 1048576

    readonly property real used: Sysinfo.memUsedGiB * _kibPerGib
    readonly property real total: Sysinfo.memTotalGiB > 0 ? Sysinfo.memTotalGiB * _kibPerGib : 1
    readonly property real percentage: Sysinfo.mem
    readonly property int updateInterval: 1500

    function ref(owner: var): void {
        Sysinfo.setActive(owner, true);
    }

    function unref(owner: var): void {
        Sysinfo.setActive(owner, false);
    }
}
