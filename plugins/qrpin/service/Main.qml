pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// QR Pin service: keep one URL pinned as a QR PNG under stateDir so it
// survives reboots until cleared. Desktop pluginApi may lack saveSetting /
// stateDir, so the helper always takes an explicit state path.
Item {
    id: svc

    property var pluginApi
    readonly property var settings: pluginApi ? pluginApi.pluginSettings : null

    property string url: ""
    property string imagePath: ""
    property int imageGen: 0
    property string error: ""
    property bool busy: false
    property string draft: ""
    // When CLEAR arrives during encode/paste, discard that result and run
    // clear as soon as the process is free.
    property bool _wantClear: false

    readonly property bool hasPin: url.length > 0 && imagePath.length > 0
    readonly property string displayHost: {
        if (url.length === 0)
            return "";
        var s = url;
        var i = s.indexOf("://");
        if (i >= 0)
            s = s.substring(i + 3);
        var slash = s.indexOf("/");
        if (slash >= 0)
            s = s.substring(0, slash);
        return s;
    }

    readonly property string _bin: {
        var dir = pluginApi && pluginApi.pluginDir ? pluginApi.pluginDir : "";
        return dir.length > 0 ? (dir + "/bin/qrpin") : "";
    }

    readonly property string _stateDir: {
        if (pluginApi && pluginApi.stateDir)
            return String(pluginApi.stateDir);
        var xdg = Quickshell.env("XDG_STATE_HOME");
        var home = Quickshell.env("HOME");
        var base = (xdg && xdg.length > 0) ? xdg : (home + "/.local/state");
        return base + "/ryoku/plugins/qrpin";
    }

    function _settingsUrl() {
        if (!settings || settings.url === undefined || settings.url === null)
            return "";
        return String(settings.url).trim();
    }

    function _run(args) {
        if (!_bin || proc.running)
            return false;
        busy = true;
        error = "";
        proc.command = [_bin].concat(args);
        proc.running = true;
        return true;
    }

    function _refreshImage() {
        var p = _stateDir + "/qr.png";
        imagePath = p;
        imageGen += 1;
    }

    function _persistSetting(u) {
        if (pluginApi && pluginApi.saveSetting)
            pluginApi.saveSetting("url", u);
    }

    function _wipeUi() {
        url = "";
        draft = "";
        imagePath = "";
        error = "";
    }

    function setUrl(raw) {
        var text = String(raw || "").trim();
        if (text.length === 0) {
            clear();
            return;
        }
        _wantClear = false;
        draft = text;
        _run(["encode", _stateDir, text]);
    }

    function paste() {
        _wantClear = false;
        draft = "";
        _run(["paste", _stateDir]);
    }

    function clear() {
        _wipeUi();
        _persistSetting("");
        _wantClear = true;
        if (!proc.running)
            _run(["clear", _stateDir]);
    }

    function reload() {
        if (!_bin)
            return;
        if (proc.running)
            return;
        busy = true;
        error = "";
        proc._purpose = "read";
        proc.command = [_bin, "read", _stateDir];
        proc.running = true;
    }

    Process {
        id: proc
        property string _purpose: "encode"
        stdout: StdioCollector {
            id: out
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: err
            waitForEnd: true
        }
        onRunningChanged: {
            if (running)
                proc._purpose = (proc.command && proc.command.length > 0)
                    ? String(proc.command[1] || "encode")
                    : "encode";
        }
        onExited: function(code) {
            svc.busy = false;
            var text = String(out.text || "").trim();
            var errText = String(err.text || "").trim();
            var purpose = proc._purpose;

            if (purpose === "clear") {
                svc._wantClear = false;
                svc._wipeUi();
                return;
            }

            // CLEAR was requested while encode/paste/read ran — drop that
            // result and delete the on-disk pin next.
            if (svc._wantClear) {
                svc._wipeUi();
                svc._persistSetting("");
                svc._run(["clear", svc._stateDir]);
                return;
            }

            if (purpose === "read") {
                if (code === 0 && text.length > 0) {
                    svc.url = text;
                    svc.draft = text;
                    svc._refreshImage();
                    svc.error = "";
                } else {
                    // Fall back to a Hub / settings url if state is empty.
                    var fromSettings = svc._settingsUrl();
                    if (fromSettings.length > 0)
                        svc.setUrl(fromSettings);
                    else {
                        svc.url = "";
                        svc.imagePath = "";
                    }
                }
                return;
            }

            // encode / paste
            if (code !== 0 || text.length === 0) {
                svc.error = errText.length > 0 ? errText : "could not make QR";
                return;
            }
            svc.url = text;
            svc.draft = text;
            svc._persistSetting(text);
            svc._refreshImage();
            svc.error = "";
        }
    }

    onPluginApiChanged: Qt.callLater(svc.reload)
    Component.onCompleted: Qt.callLater(svc.reload)
}
