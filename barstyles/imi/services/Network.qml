pragma Singleton
pragma ComponentBehavior: Bound

// Took many bits from https://github.com/caelestia-dots/shell (GPLv3)

import QtQuick
import Quickshell
import shell.services as HostServices
import "network"
import "network/NetworkConnectionSelection.js" as ConnectionSelection

/**
 * Wi-Fi and wired status.
 *
 * State is read from NetworkState, which sits on the host's network service
 * (NetworkManager lives in the daemon), and writes go out as host network
 * intents. The shape below is what the bar, the sidebars and the mode
 * conditions already bind to, and is kept stable on purpose.
 */
Singleton {
    id: root

    readonly property bool ready: NetworkState.ready
    readonly property bool wifi: root.wifiStatus === "connected"
    readonly property bool ethernet: root.ready && NetworkState.wiredConnected
    readonly property bool wifiEnabled: root.ready && NetworkState.wifiEnabled
    readonly property bool wifiHardwareEnabled: NetworkState.wifiHardwareEnabled

    property bool wifiScanning: false
    readonly property bool wifiConnecting: root.wifiConnectTarget !== null

    property string lastWifiError: ""
    property int lastWifiExitCode: 0
    property WifiAccessPoint wifiConnectTarget
    property WifiAccessPoint wifiErrorTarget

    // SSIDs the daemon reports as saved: the only "known" signal the frame
    // carries, read by WifiAccessPoint when it has no backend network object.
    readonly property var savedSsids: (HostServices.Network.accessPoints ?? [])
        .filter(ap => ap && ap.saved)
        .map(ap => ap.ssid)

    readonly property list<WifiAccessPoint> wifiNetworks: root._apList
    readonly property WifiAccessPoint active: wifiNetworks.find(n => n && n.active) ?? null

    // Sorted by connection state then signal strength. Recomputed explicitly
    // rather than as a live binding: reading `.active`/`.strength` off every
    // access point inside a binding subscribes it to every AP's RSSI, so this
    // used to re-sort — and hand every listener a brand-new array — on every
    // signal fluctuation from any network in range, freezing the Wi-Fi tab and
    // the sidebar/quick-toggle Wi-Fi lists whenever several APs were visible.
    property list<var> friendlyWifiNetworks: []

    function resortFriendlyNetworks(): void {
        root.friendlyWifiNetworks = [...root.wifiNetworks].sort((a, b) => {
            if (a.active && !b.active)
                return -1;
            if (!a.active && b.active)
                return 1;
            return b.strength - a.strength;
        });
    }

    readonly property string wifiStatus: {
        if (!root.ready)
            return "disconnected";
        if (!NetworkState.hasWifiDevice || !NetworkState.wifiEnabled || !NetworkState.wifiHardwareEnabled)
            return "disabled";
        if (root.wifiConnectTarget !== null)
            return "connecting";
        if (!NetworkState.wifiConnected)
            return "disconnected";
        return NetworkState.limited ? "limited" : "connected";
    }

    readonly property string networkName: ConnectionSelection.preferredConnectionName(
        NetworkState.wiredConnected,
        NetworkState.wiredNetworkName,
        NetworkState.wifiConnected,
        NetworkState.wifiNetworkName
    );
    readonly property string activeConnectionName: root.networkName
    readonly property string activeInterface: ConnectionSelection.preferredInterface(
        NetworkState.wiredConnected,
        NetworkState.wiredInterface,
        NetworkState.wifiConnected,
        NetworkState.wifiInterface
    )
    readonly property int networkStrength: root.active?.strength ?? 0
    readonly property string materialSymbol: NetworkState.accessPointMode ? "wifi_tethering" : root.ethernet ? "lan" : (root.wifiEnabled && root.wifiStatus === "connected") ? ((root.active?.strength ?? 0) > 83 ? "android_wifi_4_bar" : (root.active?.strength ?? 0) > 67 ? "android_wifi_3_bar" : (root.active?.strength ?? 0) > 50 ? "wifi_2_bar" : (root.active?.strength ?? 0) > 33 ? "wifi_2_bar" : (root.active?.strength ?? 0) > 17 ? "wifi_1_bar" : "signal_wifi_0_bar") : (root.wifiStatus === "connecting") ? "signal_wifi_statusbar_not_connected" : (root.wifiStatus === "disconnected") ? "wifi_find" : (root.wifiStatus === "disabled") ? "signal_wifi_off" : "signal_wifi_bad"

    // The frame carries no address fields; the surfaces that printed them read
    // empty, same as with the stubbed command backend before the port.
    property string ipAddress: ""

    // Control
    function enableWifi(enabled = true): void {
        HostServices.Network.setWifiEnabled(enabled);
    }

    function toggleWifi(): void {
        root.enableWifi(!root.wifiEnabled);
    }

    function rescanWifi(): void {
        if (root.wifiScanning)
            return;
        root.wifiScanning = true;
        scanPulse.restart();
        HostServices.Network.refresh();
    }

    // The daemon rescans on its own; the pulse just keeps the spinner honest
    // for the surfaces that bind to it.
    Timer {
        id: scanPulse
        interval: 1500
        onTriggered: root.wifiScanning = false
    }

    // ---- Keeping the list of networks alive -------------------------------
    /**
     * The surfaces currently showing a list of networks, by name.
     *
     * The daemon streams the scan continuously, so unlike a NetworkManager
     * walk there is no radio state to hold here; the holder set survives for
     * the surfaces that release it, and answers the same question.
     */
    property var wifiScanHolders: ({})
    readonly property bool wifiScanWanted: Object.keys(root.wifiScanHolders).length > 0

    function setWifiScanHolder(key: string, held: bool): void {
        if ((root.wifiScanHolders[key] === true) === held)
            return;
        const holders = Object.assign({}, root.wifiScanHolders);
        if (held)
            holders[key] = true;
        else
            delete holders[key];
        root.wifiScanHolders = holders;
    }

    function connectToWifiNetwork(accessPoint: WifiAccessPoint): void {
        if (!accessPoint)
            return;
        const attempt = root.beginConnect(accessPoint);
        const id = HostServices.Network.connectWifi(accessPoint.ssid, "", accessPoint.bssid ?? "", false);
        root._pendingConnects[id] = attempt;
    }

    // `domain` is the 802.1X server domain; the host intent carries none of
    // the saved-profile editing, so it is accepted and unused.
    function connectWithPassword(ssid: string, password: string, username = "", hidden = false, domain = null): void {
        const accessPoint = root.wifiNetworks.find(n => n && n.ssid === ssid) ?? null;
        const attempt = root.beginConnect(accessPoint);
        const id = HostServices.Network.connectWifi(ssid, password, "", hidden);
        root._pendingConnects[id] = attempt;
    }

    function changePassword(network: WifiAccessPoint, password: string, username = "", domain = null): void {
        if (!network)
            return;
        root.connectWithPassword(network.ssid, password, username, false, domain);
    }

    function disconnectWifiNetwork(): void {
        HostServices.Network.disconnectWifi();
    }

    function forgetWifiNetwork(ssid: string): void {
        HostServices.Network.forgetWifi(ssid);
    }

    // ---- Connection bookkeeping -------------------------------------------
    // Connects run one at a time on the daemon side, so a network clicked
    // while another is still connecting waits its turn. Numbering the attempts
    // keeps the first one's result off the target and error state the second
    // one now owns.
    property int connectAttempt: 0
    property var _pendingConnects: ({})

    function beginConnect(accessPoint): int {
        root.lastWifiError = "";
        root.lastWifiExitCode = 0;
        root.wifiErrorTarget = null;
        root.wifiConnectTarget = accessPoint;
        if (accessPoint)
            accessPoint.askingPassword = false;
        return ++root.connectAttempt;
    }

    function finishConnect(attempt: int, ok: bool, error: string): void {
        if (attempt !== root.connectAttempt)
            return;
        const target = root.wifiConnectTarget;
        root.wifiConnectTarget = null;
        root.lastWifiError = (error ?? "").trim();
        if (!target)
            return;
        // A failure the daemon blames on secrets is what the password prompt
        // is for; anything else stays an error on the row.
        target.askingPassword = !ok && /secret|password|802-1x|auth/i.test(root.lastWifiError);
        if (ok) {
            root.lastWifiExitCode = 0;
            root.wifiErrorTarget = null;
            return;
        }
        root.lastWifiExitCode = 1;
        root.wifiErrorTarget = target;
    }

    Connections {
        target: HostServices.Network
        function onReplied(id: int, ok: bool, error: string) {
            const attempt = root._pendingConnects[id];
            if (attempt === undefined)
                return;
            delete root._pendingConnects[id];
            root.finishConnect(attempt, ok, error);
        }
        function onAccessPointsChanged() {
            root.syncNetworks();
        }
    }

    // What a saved 802.1X prompt would prefill. The frame carries no saved
    // profiles, so the prompt starts empty instead of pretending to know.
    function loadEnterpriseProfile(accessPoint: WifiAccessPoint): void {
        accessPoint.savedIdentity = "";
        accessPoint.savedDomain = "";
        accessPoint.savedCaCert = false;
    }

    // ---- Frame to WifiAccessPoint bridge -----------------------------------
    // One wrapper per SSID, kept across frames: an access point being asked
    // for a password must not be destroyed under the dialog asking.
    property var _apCache: ({})
    property var _apList: []

    function syncNetworks(): void {
        const rows = HostServices.Network.accessPoints ?? [];
        const wrappers = [];
        const seen = {};
        for (let i = 0; i < rows.length; i++) {
            const row = rows[i];
            if (!row || !row.ssid)
                continue;
            seen[row.ssid] = true;
            let wrapper = root._apCache[row.ssid];
            if (!wrapper) {
                wrapper = apComponent.createObject(root, {});
                root._apCache[row.ssid] = wrapper;
            }
            wrapper.lastIpcObject = row;
            wrapper.details = row;
            wrappers.push(wrapper);
        }
        for (const ssid in root._apCache) {
            if (seen[ssid])
                continue;
            const gone = root._apCache[ssid];
            if (root.wifiConnectTarget === gone)
                root.wifiConnectTarget = null;
            if (root.wifiErrorTarget === gone)
                root.wifiErrorTarget = null;
            gone.destroy();
            delete root._apCache[ssid];
        }
        root._apList = wrappers;
        root.resortFriendlyNetworks();
    }

    onReadyChanged: root.syncNetworks()

    Component {
        id: apComponent

        WifiAccessPoint {}
    }

    // Catches signal drift between frames. Explicit and throttled on purpose —
    // see the note on friendlyWifiNetworks above.
    Timer {
        interval: 4000
        repeat: true
        running: root.wifiNetworks.length > 0
        onTriggered: root.resortFriendlyNetworks()
    }

    Component.onCompleted: {
        root.syncNetworks();
    }
}
