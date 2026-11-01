// Generated from caelestia-dots/shell b51fdb35ca7a14ac5a49e0d94fc5de2d79756aed. Do not edit.
pragma Singleton

import QtQuick
import Quickshell

Singleton {
    readonly property QtObject appearance: GlobalConfig.appearance
    readonly property QtObject general: GlobalConfig.general
    readonly property QtObject background: GlobalConfig.background
    readonly property QtObject bar: GlobalConfig.bar
    readonly property QtObject border: GlobalConfig.border
    readonly property QtObject dashboard: GlobalConfig.dashboard
    readonly property QtObject launcher: GlobalConfig.launcher
    readonly property QtObject lock: GlobalConfig.lock
    readonly property QtObject nexus: GlobalConfig.nexus
    readonly property QtObject notifs: GlobalConfig.notifs
    readonly property QtObject osd: GlobalConfig.osd
    readonly property QtObject services: GlobalConfig.services
    readonly property QtObject session: GlobalConfig.session
    readonly property QtObject sidebar: GlobalConfig.sidebar
    readonly property QtObject utilities: GlobalConfig.utilities
    readonly property QtObject paths: GlobalConfig.paths

    function forScreen(screen: string): QtObject {
        return GlobalConfig;
    }
}
