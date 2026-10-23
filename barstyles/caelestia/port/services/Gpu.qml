pragma Singleton

import Quickshell
import shell.services
import "../../config"
Singleton {
    id: root

    enum Type {
        Auto,
        None,
        Nvidia,
        Generic
    }

    readonly property int userType: {
        const u = (GlobalConfig.services.gpuType || "").trim().toUpperCase();
        if (u === "" || u === "AUTO")
            return Gpu.Auto;
        if (u === "NVIDIA")
            return Gpu.Nvidia;
        if (u === "GENERIC")
            return Gpu.Generic;
        return Gpu.None;
    }

    // Use boot-time sensor paths (nv/amd) rather than gpuAvailable so cards gated on
    // Gpu.type !== Gpu.None can mount their ServiceRef and start StatsFeed polling.
    readonly property int autoType: {
        if (StatsFeed.nv !== "")
            return Gpu.Nvidia;
        if (StatsFeed.amd !== "" || StatsFeed.gpuAvailable)
            return Gpu.Generic;
        return Gpu.None;
    }

    readonly property int type: userType === Gpu.Auto ? autoType : userType
    readonly property string name: ""
    readonly property real percentage: type !== Gpu.None && StatsFeed.gpuAvailable ? StatsFeed.gpuPct / 100 : 0
    readonly property real temperature: type !== Gpu.None && StatsFeed.gpuAvailable ? StatsFeed.gpuTempC : 0
    readonly property int updateInterval: StatsFeed.pollMs

    function ref(owner: var): void {
        StatsFeed.setActive(owner, true);
    }

    function unref(owner: var): void {
        StatsFeed.setActive(owner, false);
    }
}
