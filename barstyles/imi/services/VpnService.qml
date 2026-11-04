pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// VpnService is not in this port; members read as empty.
Singleton {
    property var active: null
    property bool activeProfile: false
    property string activeProvider: ""
    property bool available: false
    property var availableProviders: null
    property string blockLanSupported: ""
    property string displayActive: ""
    property real enabled: 0
    property string errorMessage: ""
    property var killSwitchEnabled: null
    property var killSwitchPending: null
    property string killSwitchSupported: ""
    property var lastErrorOutput: null
    property string loading: ""
    property var nordvpnLocation: null
    property string operationPending: ""
    property var profiles: null
    property var protonConnected: null
    property var protonvpnAvailable: null
    property var statusText: null
    function connectDefault() {
    }
    function connectProfile() {
    }
    function connectProvider() {
    }
    function disconnectVpn() {
    }
    function openFilePicker() {
    }
    function refresh() {
    }
    function runDiagnostics() {
    }
    function setKillSwitch() {
    }
    function toggleVpn() {
    }
}
