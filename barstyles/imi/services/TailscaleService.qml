pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../modules/common"
import shell.services as HostServices

// Tailscale status and actions for the sidebar dialog, over the host's Tailscale
// service (which owns the `tailscale status` polling and the operator handling).
// The CLI-level extras the old service drove (netcheck, peer pings, logout, the
// auth URL) have no counterpart on the host; those members answer inertly.
Singleton {
    id: root

    readonly property bool enabled: Config.options?.tailscale?.enabled ?? true
    readonly property bool available: root.enabled && HostServices.Tailscale.available
    readonly property bool active: HostServices.Tailscale.up

    // "" until the first read, then Running | Stopped | NeedsLogin | NoState |
    // Unavailable | Missing, straight from the host's reader.
    readonly property string backendState: {
        const state = HostServices.Tailscale.state;
        return state.length === 0 ? "NoState" : state;
    }

    readonly property string nodeName: HostServices.Tailscale.hostName
    readonly property string tailnetName: HostServices.Tailscale.tailnet
    readonly property string tailscaleIp4: HostServices.Tailscale.ip4
    readonly property string tailscaleIp6: HostServices.Tailscale.ip6
    readonly property string errorMessage: HostServices.Tailscale.lastError
    readonly property bool loading: HostServices.Tailscale.busy

    // The daemon never hands out an auth URL; login happens through the admin console.
    readonly property string loginUrl: ""

    readonly property string statusText: {
        if (!root.enabled) return Translation.tr("Disabled");
        if (root.backendState === "Running") return root.nodeName.length > 0 ? root.nodeName : Translation.tr("Connected");
        if (root.backendState === "NeedsLogin") return Translation.tr("Needs Login");
        if (root.backendState === "Stopped") return Translation.tr("Stopped");
        return Translation.tr("Unavailable");
    }

    readonly property string permissionState: {
        if (!root.enabled) return "disabled";
        if (HostServices.Tailscale.needsOperator) return "permission-denied";
        if (root.backendState === "NeedsLogin") return "needs-login";
        if (root.active) return "ok";
        return "unknown";
    }

    // The host only tracks exit-node-capable peers; they are what both lists show.
    readonly property var _hostExitNodes: HostServices.Tailscale.exitNodes || []
    readonly property var peers: root._hostExitNodes.map(peer => ({
        id: peer.id,
        hostname: peer.name,
        ip: peer.ip,
        online: peer.online,
        os: peer.os,
        exitNodeOption: true,
        isExitNode: peer.active === true
    }))
    readonly property var exitNodes: root.peers

    readonly property string currentExitNode: HostServices.Tailscale.exitNodeName
    readonly property bool advertiseExitNode: HostServices.Tailscale.advertisingExit

    // Prefs the host cannot apply. Kept config-backed so the switches persist and
    // read back; the daemon has no surface for them.
    property bool acceptDns: Config.options?.tailscale?.acceptDns ?? true
    property bool shieldsUp: Config.options?.tailscale?.shieldsUp ?? false
    property bool sshEnabled: Config.options?.tailscale?.ssh ?? false
    property var advertiseRoutes: Config.options?.tailscale?.advertiseRoutes ?? []

    // No netcheck or ping on the host.
    readonly property string diagnosticsText: ""
    readonly property bool netcheckLoading: false
    property string lastPingResult: ""
    property bool lastPingSuccess: false

    Component.onCompleted: {
        // Registering as an owner keeps the host's 10 s poll alive, so the bar's
        // passive status dot and this dialog read live state without probing here.
        HostServices.Tailscale.setActive(root, true);
        HostServices.Tailscale.refresh();
    }

    function refresh() {
        HostServices.Tailscale.refresh();
    }

    function toggleTailscale() {
        if (root.active)
            root.disconnectTailscale();
        else
            root.connectTailscale();
    }

    function connectTailscale() {
        HostServices.Tailscale.turnOn();
    }

    function disconnectTailscale() {
        HostServices.Tailscale.turnOff();
    }

    function logout() {}

    function openLoginUrl() {
        HostServices.Tailscale.openAdmin();
    }

    function setExitNode(nodeNameOrIp) {
        if (!nodeNameOrIp || nodeNameOrIp.length === 0) {
            root.clearExitNode();
            return;
        }
        HostServices.Tailscale.useExitNode({ ip: nodeNameOrIp });
    }

    function clearExitNode() {
        HostServices.Tailscale.stopExitNode();
    }

    function setAdvertiseExitNode(value) {
        HostServices.Tailscale.setAdvertiseExit(value === true);
    }

    function setAcceptDns(value) {
        root.acceptDns = value;
        if (Config.ready) Config.options.tailscale.acceptDns = value;
    }

    function setShieldsUp(value) {
        root.shieldsUp = value;
        if (Config.ready) Config.options.tailscale.shieldsUp = value;
    }

    function setSshEnabled(value) {
        root.sshEnabled = value;
        if (Config.ready) Config.options.tailscale.ssh = value;
    }

    function setAdvertiseRoutes(routes) {
        root.advertiseRoutes = routes;
        if (Config.ready) Config.options.tailscale.advertiseRoutes = routes;
    }

    function netcheck() {}
    function refreshDiagnostics() {}

    function pingPeer(peerIp, callback) {
        root.lastPingSuccess = false;
        root.lastPingResult = Translation.tr("Ping is unavailable");
        if (callback)
            callback(false, root.lastPingResult);
    }
}
