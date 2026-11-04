pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Networking as QNet
import shell.services as HostServices
import "../modules/common"

/**
 * Live network state, from the host's network service.
 *
 * NetworkManager lives in the daemon (network topic), so nothing here polls,
 * parses text or speaks D-Bus: the streamed frame is the state. Read only
 * on purpose - writes go through the host's network intents, and Network is
 * the facade the rest of the shell binds to.
 *
 * The frame carries less than a local NetworkManager walk would: interface
 * names, MACs, link speed and a portal state have no frame fields, so those
 * members answer neutrally instead of making something up.
 */
Singleton {
    id: root

    // The frame arrives a beat after the shell starts. Latch readiness on the
    // first frame so consumers can hold onto their startup values instead of
    // flashing "no adapter".
    property bool ready: false
    function _markReady() {
        root.ready = true;
    }

    Connections {
        target: HostServices.Network
        function onWifiChanged() {
            root._markReady();
        }
        function onWiredChanged() {
            root._markReady();
        }
        function onAccessPointsChanged() {
            root._markReady();
        }
    }

    readonly property bool hasWifiDevice: HostServices.Network.wifiPresent
    // The frame has no hardware-kill state; a present radio is a working one.
    readonly property bool wifiHardwareEnabled: root.hasWifiDevice
    readonly property bool wifiEnabled: root.hasWifiDevice && HostServices.Network.wifiRadio

    // Scanning is the daemon's business; it streams whatever it sees.
    readonly property bool wifiFromNmcli: false
    readonly property bool accessPointMode: false
    readonly property bool captivePortal: false
    readonly property bool limited: false

    readonly property bool wifiConnected: HostServices.Network.wifiConnectivity === "Connected"
    readonly property bool wifiConnecting: false

    readonly property string wifiInterface: ""
    readonly property string wifiMac: ""
    readonly property string wifiNetworkName: root.wifiConnected ? HostServices.Network.activeSsid : ""

    readonly property var wifiNetworks: HostServices.Network.accessPoints ?? []
    readonly property var activeWifiNetwork: root.wifiNetworks.find(n => n && n.active) ?? null

    function findNetwork(ssid: string): var {
        return root.wifiNetworks.find(n => n && n.ssid === ssid) ?? null;
    }

    function setScannerEnabled(enabled: bool): void {
        // The daemon scans on its own; the request has no receiver.
    }

    readonly property bool wiredConnected: HostServices.Network.kind === "ethernet"
    readonly property bool wiredConnecting: false
    readonly property var wiredDevice: null
    readonly property var wiredNetwork: null
    readonly property string wiredInterface: ""
    readonly property int wiredLinkSpeed: 0
    readonly property string wiredNetworkName: ""

    function isEnterprise(security: int): bool {
        return security === QNet.WifiSecurityType.Wpa2Eap || security === QNet.WifiSecurityType.WpaEap || security === QNet.WifiSecurityType.Wpa3SuiteB192 || security === QNet.WifiSecurityType.DynamicWep || security === QNet.WifiSecurityType.Leap;
    }

    function securityLabel(security: int): string {
        switch (security) {
        case QNet.WifiSecurityType.Wpa3SuiteB192:
            return "WPA3 Suite-B 192";
        case QNet.WifiSecurityType.Sae:
            return "WPA3";
        case QNet.WifiSecurityType.Wpa2Eap:
            return "WPA2 802.1X";
        case QNet.WifiSecurityType.Wpa2Psk:
            return "WPA2";
        case QNet.WifiSecurityType.WpaEap:
            return "WPA 802.1X";
        case QNet.WifiSecurityType.WpaPsk:
            return "WPA";
        case QNet.WifiSecurityType.StaticWep:
            return "WEP";
        case QNet.WifiSecurityType.DynamicWep:
            return "Dynamic WEP";
        case QNet.WifiSecurityType.Leap:
            return "LEAP";
        case QNet.WifiSecurityType.Owe:
            return "OWE";
        default:
            return "";
        }
    }

    function failReasonLabel(reason: int): string {
        switch (reason) {
        case QNet.ConnectionFailReason.NoSecrets:
            return Translation.tr("Wrong password");
        case QNet.ConnectionFailReason.WifiClientDisconnected:
            return Translation.tr("The network dropped the connection");
        case QNet.ConnectionFailReason.WifiClientFailed:
            return Translation.tr("The network refused the connection");
        case QNet.ConnectionFailReason.WifiAuthTimeout:
            return Translation.tr("Authentication timed out");
        case QNet.ConnectionFailReason.WifiNetworkLost:
            return Translation.tr("The network went out of range");
        default:
            return Translation.tr("Could not connect");
        }
    }
}
