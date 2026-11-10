pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: svc

    property var pluginApi
    property var items: []
    property string downloadDir: ""
    property string error: ""
    property bool refreshing: false

    function refresh() {
        if (svc.refreshing || !svc.pluginApi || !svc.pluginApi.pluginDir)
            return;
        svc.error = "";
        svc.refreshing = true;
        listing.running = true;
    }

    function apply(line) {
        try {
            const data = JSON.parse(String(line));
            svc.downloadDir = String(data.dir || "");
            svc.items = Array.isArray(data.items) ? data.items : [];
            svc.error = data.error ? String(data.error) : "";
        } catch (e) {
            svc.items = [];
            svc.error = "Could not read the Downloads folder.";
        }
    }

    function openFile(path) {
        if (path)
            Quickshell.execDetached(["xdg-open", String(path)]);
    }

    function openFolder() {
        if (svc.downloadDir)
            Quickshell.execDetached(["xdg-open", svc.downloadDir]);
    }

    Process {
        id: listing
        command: svc.pluginApi && svc.pluginApi.pluginDir
            ? [svc.pluginApi.pluginDir + "/bin/recent-downloads"] : []
        running: false
        stdout: SplitParser {
            onRead: line => svc.apply(line)
        }
        stderr: SplitParser {
            onRead: line => console.warn("Recent Downloads:", line)
        }
        onExited: (code, status) => {
            svc.refreshing = false;
            if (code !== 0 && svc.error === "")
                svc.error = "Could not read the Downloads folder.";
        }
    }
}
