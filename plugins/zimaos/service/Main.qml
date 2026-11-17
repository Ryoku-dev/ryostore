pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// One ZimaOS box. Public device info needs no login. Network rates, the
// storage pool and CPU/RAM come from the same calls the ZimaOS dashboard makes,
// after a session written only under pluginApi.stateDir.
Item {
    id: svc

    property var pluginApi
    readonly property var settings: pluginApi ? pluginApi.pluginSettings : null

    // Typed on the login screen, then saved. Empty until the user sets one.
    property string activeHost: ""
    readonly property string savedHost: {
        var raw = settings && settings.host !== undefined && settings.host !== null
                ? ("" + settings.host).trim() : "";
        return raw;
    }
    readonly property string host: svc.activeHost.length > 0 ? svc.activeHost : svc.savedHost
    readonly property bool hostReady: svc.normalizeHost(svc.host).length > 0
    readonly property int pollSec: {
        var n = settings && settings.poll !== undefined ? Number(settings.poll) : 8;
        if (!isFinite(n))
            return 8;
        return Math.max(3, Math.min(60, Math.round(n)));
    }
    readonly property string binPath: pluginApi && pluginApi.pluginDir
            ? pluginApi.pluginDir + "/bin/zima" : ""
    readonly property string stateFile: pluginApi && pluginApi.stateDir
            ? pluginApi.stateDir + "/session.json" : ""

    property bool online: false
    property bool authed: false
    property bool busy: false
    property string errorText: ""
    property string authError: ""
    property string username: ""
    property string deviceName: ""
    property string osVersion: ""
    property string deviceModel: ""
    property string cpuModel: ""
    property real memoryBytes: -1
    property real cpuPercent: -1
    property real memPercent: -1
    property string ifaceLabel: "LAN"
    property string ipAddress: ""
    property bool linkRemote: false
    property bool linkWifi: false
    property bool linkEthernet: false
    property bool linkThunderbolt: false
    property string linkActive: ""
    property real downBps: 0
    property real upBps: 0
    property string storageName: ""
    property real storageTotal: -1
    property real storageUsed: -1
    property real storageAvail: -1
    property string dashboardUrl: ""
    property string filesUrl: ""
    property string backupUrl: ""
    property string peerDropUrl: ""
    property string deviceImage: ""

    property real _prevSent: -1
    property real _prevRecv: -1
    property real _prevStamp: -1
    property var _queue: []
    property bool _statusAfterLogin: false
    property bool _statusAgain: false

    function formatBytes(n) {
        if (n === undefined || n === null || !isFinite(n) || n < 0)
            return "";
        var units = ["B", "KB", "MB", "GB", "TB"];
        var v = n;
        var i = 0;
        while (v >= 1024 && i < units.length - 1) {
            v /= 1024;
            i++;
        }
        var digits = (i === 0 || v >= 100) ? 0 : (v >= 10 ? 1 : 2);
        return v.toFixed(digits) + " " + units[i];
    }

    function formatRate(bps) {
        if (!isFinite(bps) || bps < 1)
            return "0 B";
        return svc.formatBytes(bps);
    }

    readonly property string downText: svc.authed ? svc.formatRate(svc.downBps) : "—"
    readonly property string upText: svc.authed ? svc.formatRate(svc.upBps) : "—"
    readonly property string cpuText: svc.cpuPercent >= 0 ? Math.round(svc.cpuPercent) + "%" : "—"
    readonly property string ramText: svc.memPercent >= 0
            ? Math.round(svc.memPercent) + "%"
            : (svc.memoryBytes > 0 ? svc.formatBytes(svc.memoryBytes) : "—")
    readonly property string storageTitle: svc.storageName.length > 0 ? svc.storageName : ""
    readonly property string storageLine: {
        if (svc.storageAvail >= 0 && svc.storageTotal >= 0)
            return svc.formatBytes(svc.storageAvail) + "  ·  " + svc.formatBytes(svc.storageTotal);
        if (svc.storageTotal >= 0)
            return svc.formatBytes(svc.storageTotal);
        return "";
    }
    readonly property real storageFraction: {
        if (svc.storageTotal <= 0 || svc.storageUsed < 0)
            return 0;
        return Math.max(0, Math.min(1, svc.storageUsed / svc.storageTotal));
    }

    function enqueue(op) {
        var next = svc._queue.slice();
        next.push(op);
        svc._queue = next;
        svc.pump();
    }

    function pump() {
        if (proc.running || svc._queue.length === 0 || svc.binPath === "")
            return;
        var op = svc._queue[0];
        svc._queue = svc._queue.slice(1);
        proc.opKind = op.kind;
        proc.opHost = op.host || "";
        proc.payload = op.payload || "";
        proc.command = op.command;
        proc.running = true;
    }

    function normalizeHost(raw) {
        var text = (raw || "").trim();
        // Bare LAN addresses stay http on the Python side. https:// is kept so
        // that call verifies the certificate. http:// is stored without a scheme
        // so an existing session for the same host still matches.
        var scheme = "";
        var lower = text.toLowerCase();
        if (lower.indexOf("https://") === 0) {
            scheme = "https";
            text = text.substring(8);
        } else if (lower.indexOf("http://") === 0) {
            scheme = "http";
            text = text.substring(7);
        }
        if (text.length === 0 || text.indexOf("@") >= 0 || text.indexOf("://") >= 0
                || text.indexOf("/") >= 0 || text.indexOf("\\") >= 0 || text.indexOf(" ") >= 0)
            return "";
        var host = text;
        var port = "";
        if (host.charAt(0) === "[") {
            var end = host.indexOf("]");
            if (end < 0)
                return "";
            port = host.substring(end + 1);
            host = host.substring(0, end + 1);
            if (port.charAt(0) === ":")
                port = port.substring(1);
            else if (port.length > 0)
                return "";
        } else {
            var pieces = host.split(":");
            if (pieces.length === 2) {
                host = pieces[0];
                port = pieces[1];
            } else if (pieces.length > 2) {
                return "";
            }
        }
        var ipv4 = /^(?:\d{1,3}\.){3}\d{1,3}$/.test(host);
        var name = /^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$/.test(host);
        if (ipv4) {
            var nums = host.split(".");
            for (var i = 0; i < nums.length; ++i) {
                if (Number(nums[i]) > 255)
                    return "";
            }
        } else if (!name) {
            return "";
        }
        if (port.length > 0) {
            if (!/^\d{1,5}$/.test(port))
                return "";
            var n = Number(port);
            if (n < 1 || n > 65535)
                return "";
            return scheme === "https" ? ("https://" + host + ":" + n) : (host + ":" + n);
        }
        return scheme === "https" ? ("https://" + host) : host;
    }

    function useHost(raw) {
        var clean = svc.normalizeHost(raw);
        if (clean === "")
            return false;
        svc.activeHost = clean;
        if (svc.pluginApi && svc.savedHost !== clean)
            svc.pluginApi.saveSetting("host", clean);
        return true;
    }

    function statusOp() {
        return {
            kind: "status",
            host: svc.host,
            command: [svc.binPath, "status", svc.host, svc.stateFile]
        };
    }

    function refresh() {
        if (!svc.hostReady || svc.binPath === "" || svc.stateFile === "")
            return;
        // A status already running for another host must not swallow this
        // refresh. Its result is ignored, then this host is fetched.
        if (proc.running && proc.opKind === "status") {
            if (proc.opHost !== svc.host)
                svc._statusAgain = true;
            return;
        }
        var kept = [];
        var hasCurrent = false;
        for (var i = 0; i < svc._queue.length; i++) {
            var item = svc._queue[i];
            if (item.kind === "status") {
                if (item.host === svc.host && !hasCurrent) {
                    kept.push(item);
                    hasCurrent = true;
                }
                continue;
            }
            kept.push(item);
        }
        svc._queue = kept;
        if (hasCurrent)
            return;
        svc.enqueue(svc.statusOp());
    }

    // useHost() starts a status poll before login() is queued. That poll, or
    // one already sitting in the queue, used to make the post-login refresh()
    // return early, so the sign-in form stayed up until the next timer tick.
    function refreshAfterLogin() {
        if (!svc.hostReady || svc.binPath === "" || svc.stateFile === "")
            return;
        var kept = [];
        for (var i = 0; i < svc._queue.length; i++) {
            if (svc._queue[i].kind !== "status")
                kept.push(svc._queue[i]);
        }
        svc._queue = kept;
        if (proc.running && proc.opKind === "status") {
            svc._statusAfterLogin = true;
            return;
        }
        svc._statusAfterLogin = false;
        svc.enqueue(svc.statusOp());
    }

    function takeLoginStatus() {
        if (!svc._statusAfterLogin)
            return;
        svc._statusAfterLogin = false;
        svc.enqueue(svc.statusOp());
    }

    function login(username, password) {
        if (!svc.hostReady || svc.binPath === "" || svc.stateFile === "")
            return;
        svc.busy = true;
        svc.authError = "";
        svc.enqueue({
            kind: "login",
            payload: JSON.stringify({ username: username, password: password }),
            command: [svc.binPath, "login", svc.host, svc.stateFile]
        });
    }

    function logout() {
        if (svc.binPath === "" || svc.stateFile === "")
            return;
        svc.enqueue({
            kind: "logout",
            command: [svc.binPath, "logout", svc.stateFile]
        });
    }

    function openUrl(url) {
        if (!url)
            return;
        if (url.indexOf("http://") !== 0 && url.indexOf("https://") !== 0)
            return;
        Quickshell.execDetached(["xdg-open", url]);
    }

    function num(value) {
        if (value === null || value === undefined)
            return -1;
        var n = Number(value);
        return isFinite(n) ? n : -1;
    }

    function noteRates(sent, recv, stamp) {
        var now = Date.now() / 1000;
        var mark = (stamp !== null && stamp !== undefined && isFinite(Number(stamp)) && Number(stamp) > 0)
                ? Number(stamp) : now;
        if (svc._prevStamp > 0 && sent >= 0 && recv >= 0 && svc._prevSent >= 0) {
            var dt = mark - svc._prevStamp;
            if (dt <= 0 || dt > 120)
                dt = now - svc._prevWall;
            if (dt > 0 && dt < 120) {
                svc.upBps = Math.max(0, (sent - svc._prevSent) / dt);
                svc.downBps = Math.max(0, (recv - svc._prevRecv) / dt);
            }
        }
        svc._prevSent = sent;
        svc._prevRecv = recv;
        svc._prevStamp = mark;
        svc._prevWall = now;
    }

    property real _prevWall: 0

    function applyStatus(parsed) {
        if (!parsed || parsed.ok !== true) {
            svc.online = false;
            svc.errorText = parsed && parsed.error ? ("" + parsed.error) : "offline";
            return;
        }
        svc.online = true;
        svc.errorText = "";
        svc.authError = parsed.authError ? ("" + parsed.authError) : "";
        svc.authed = parsed.authed === true;
        svc.username = parsed.username ? ("" + parsed.username) : "";
        svc.deviceName = parsed.deviceName ? ("" + parsed.deviceName) : "";
        svc.osVersion = parsed.osVersion ? ("" + parsed.osVersion) : "";
        svc.deviceModel = parsed.deviceModel ? ("" + parsed.deviceModel) : "";
        svc.cpuModel = parsed.cpuModel ? ("" + parsed.cpuModel) : "";
        svc.memoryBytes = svc.num(parsed.memoryBytes);
        svc.dashboardUrl = parsed.dashboardUrl ? ("" + parsed.dashboardUrl) : "";
        svc.filesUrl = parsed.filesUrl ? ("" + parsed.filesUrl) : "";
        svc.backupUrl = parsed.backupUrl ? ("" + parsed.backupUrl) : "";
        svc.peerDropUrl = parsed.peerDropUrl ? ("" + parsed.peerDropUrl) : "";
        if (parsed.deviceImage)
            svc.deviceImage = "" + parsed.deviceImage;
        if (!svc.authed) {
            svc.cpuPercent = -1;
            svc.memPercent = -1;
            svc.downBps = 0;
            svc.upBps = 0;
            svc._prevStamp = -1;
            svc.storageName = "";
            svc.storageTotal = -1;
            svc.storageUsed = -1;
            svc.storageAvail = -1;
            svc.ifaceLabel = "LAN";
            svc.ipAddress = svc.host;
            svc.linkRemote = false;
            svc.linkWifi = false;
            svc.linkEthernet = false;
            svc.linkThunderbolt = false;
            svc.linkActive = "";
            return;
        }
        svc.cpuPercent = svc.num(parsed.cpuPercent);
        svc.memPercent = svc.num(parsed.memPercent);
        var net = parsed.network || {};
        svc.ifaceLabel = net.label ? ("" + net.label) : "LAN";
        svc.ipAddress = net.ip ? ("" + net.ip) : svc.host;
        svc.linkRemote = net.remote === true;
        svc.linkWifi = net.wifi === true;
        svc.linkEthernet = net.ethernet === true;
        svc.linkThunderbolt = net.thunderbolt === true;
        svc.linkActive = net.active ? ("" + net.active) : "";
        svc.noteRates(svc.num(net.bytesSent), svc.num(net.bytesRecv), net.time);
        var disk = parsed.storage || null;
        if (disk) {
            svc.storageName = disk.name ? ("" + disk.name) : "";
            svc.storageTotal = svc.num(disk.total);
            svc.storageUsed = svc.num(disk.used);
            svc.storageAvail = svc.num(disk.avail);
        } else {
            svc.storageName = "";
            svc.storageTotal = -1;
            svc.storageUsed = -1;
            svc.storageAvail = -1;
        }
    }

    function applyResult(kind, text) {
        var parsed = null;
        try {
            parsed = JSON.parse((text || "").trim());
        } catch (e) {
            parsed = { ok: false, error: "bad response" };
        }
        if (kind === "status") {
            // Drop a result fetched for a host that is no longer active, or the
            // panel keeps the previous server after the address changes.
            if (proc.opHost === svc.host) {
                svc.applyStatus(parsed);
                svc._statusAgain = false;
            } else {
                svc._statusAgain = true;
            }
            svc.takeLoginStatus();
            if (svc._statusAgain) {
                svc._statusAgain = false;
                svc.refresh();
            }
        } else if (kind === "login") {
            svc.busy = false;
            if (parsed && parsed.ok === true) {
                svc.authError = "";
                svc.refreshAfterLogin();
            } else {
                svc.authError = parsed && parsed.error ? ("" + parsed.error) : "login failed";
            }
        } else if (kind === "logout") {
            svc.authed = false;
            svc.username = "";
            svc.authError = "";
            svc.cpuPercent = -1;
            svc.memPercent = -1;
            svc.downBps = 0;
            svc.upBps = 0;
            svc._prevStamp = -1;
            svc.storageName = "";
            svc.linkRemote = false;
            svc.linkWifi = false;
            svc.linkEthernet = false;
            svc.linkThunderbolt = false;
            svc.linkActive = "";
            svc.refresh();
        }
    }

    onHostChanged: {
        svc._prevStamp = -1;
        svc.downBps = 0;
        svc.upBps = 0;
        svc.online = false;
        svc.authed = false;
        svc.deviceName = "";
        svc.osVersion = "";
        svc.deviceModel = "";
        svc.deviceImage = "";
        svc.dashboardUrl = "";
        svc.filesUrl = "";
        svc.backupUrl = "";
        svc.peerDropUrl = "";
        svc.username = "";
        svc.authError = "";
        svc.errorText = "";
        svc.ipAddress = "";
        svc.storageName = "";
        svc.storageTotal = -1;
        svc.storageUsed = -1;
        svc.storageAvail = -1;
        if (!svc.hostReady)
            return;
        svc.refresh();
    }

    Timer {
        interval: svc.pollSec * 1000
        repeat: true
        running: svc.hostReady && svc.binPath !== "" && svc.stateFile !== ""
        triggeredOnStart: true
        onTriggered: svc.refresh()
    }

    Process {
        id: proc
        running: false
        property string opKind: ""
        property string opHost: ""
        property string payload: ""
        property bool outputSeen: false

        onRunningChanged: {
            if (!proc.running)
                return;
            proc.outputSeen = false;
            proc.stdinEnabled = true;
            if (proc.payload.length > 0)
                proc.write(proc.payload);
            proc.payload = "";
            proc.stdinEnabled = false;
        }

        stdout: StdioCollector {
            id: out
            onStreamFinished: {
                proc.outputSeen = true;
                svc.applyResult(proc.opKind, out.text);
            }
        }

        onExited: {
            if (!proc.outputSeen)
                svc.applyResult(proc.opKind, out.text);
            else if (proc.opKind === "status")
                svc.takeLoginStatus();
            Qt.callLater(svc.pump);
        }
    }
}
