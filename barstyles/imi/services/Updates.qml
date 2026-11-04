pragma Singleton

import QtQuick
import Quickshell
import shell.services as HostServices

// Adapter over the host's updates service: the daemon owns the background check (ryoku status topic) and streams the frame, so there is nothing to poll or parse here.
Singleton {
    id: root

    readonly property bool available: HostServices.Updates.available
    readonly property int count: HostServices.Updates.pending

    function refresh() {
        HostServices.Updates.check();
    }
}
