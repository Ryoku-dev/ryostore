import QtQuick
import Quickshell
import "../config"
import "../services"
Scope {
    Component.onCompleted: {
        Notifs;
    }

    Timer {
        id: deferredServices

        interval: 250
        repeat: false
        running: true

        onTriggered: {
            IdleInhibitor;
            GameMode;
            Players;
            Brightness;
            Weather.reload();
            WorkspaceTrackerGuard;

            if (GlobalConfig.utilities.vpn.enabled)
                VPN;
        }
    }
}
