pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// NetworkFallback is not in this port; members read as empty.
Singleton {
    property var hasWifiDevice: null
    property var hasWiredDevice: null
    property var loaded: null
    property var radioEnabled: null
    property var radioHardwareEnabled: null
    property var reachable: null
    property bool wifiConnected: false
    property var wifiConnecting: null
    property var wifiConnectionName: ({})
    property var wifiInterface: ({})
    property var wifiMac: ({})
    property var wiredConnected: null
    property var wiredConnecting: null
    property var wiredConnectionName: ({})
    property bool wiredHasLink: false
    property var wiredInterface: ({})
    property var wiredMac: ({})
    function refresh() {
    }
}
