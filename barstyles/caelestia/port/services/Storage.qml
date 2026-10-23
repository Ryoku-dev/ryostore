pragma Singleton

import QtQml
import Quickshell
import shell.services

Singleton {
    id: root

    // StatsFeed reports `/` in GiB; Caelestia consumers pass DiskInfo.used/total to Units.formatKibUsage.
    readonly property real _kibPerGib: 1048576

    readonly property var disks: StatsFeed.diskTotalGiB > 0 ? [rootDisk] : []
    property DiskInfo manualPrimaryDisk: null
    readonly property DiskInfo primaryDisk: manualPrimaryDisk ?? (StatsFeed.diskTotalGiB > 0 ? rootDisk : null)
    readonly property real percentage: rootDisk.perc
    readonly property int updateInterval: 30000

    function ref(owner: var): void {
        StatsFeed.setActive(owner, true);
    }

    function unref(owner: var): void {
        StatsFeed.setActive(owner, false);
    }

    DiskInfo {
        id: rootDisk

        mount: "/"
        used: StatsFeed.diskUsedGiB * root._kibPerGib
        total: StatsFeed.diskTotalGiB * root._kibPerGib
        hasRoot: true
    }
}
