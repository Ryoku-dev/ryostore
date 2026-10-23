pragma Singleton

import Quickshell
import shell.services

Singleton {
    readonly property string name: ""
    readonly property real percentage: Sysinfo.cpu
    readonly property real temperature: Sysinfo.tempC
    readonly property int updateInterval: 1500

    function ref(owner: var): void {
        Sysinfo.setActive(owner, true);
    }

    function unref(owner: var): void {
        Sysinfo.setActive(owner, false);
    }
}
