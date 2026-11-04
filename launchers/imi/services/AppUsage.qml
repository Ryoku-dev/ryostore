pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "../modules/common"

// Launch frecency for the app list. A small JSON file at
// ~/.local/state/imi/app-usage.json maps desktop entry ids to a launch count
// and a last-launch timestamp; the score decays with age so an app used a lot
// last month does not outrank one used this morning.
Singleton {
    id: root

    readonly property string filePath: FileUtils.trimFileProtocol(`${Directories.state}/imi/app-usage.json`)
    property bool ready: false
    property var usage: ({})

    // Half-life of one week, in milliseconds.
    readonly property real halfLifeMs: 7.0 * 24.0 * 60.0 * 60.0 * 1000.0

    function getScore(appId) {
        const entry = root.usage[String(appId ?? "")];
        if (!entry)
            return 0;
        const count = Number(entry.count) || 0;
        const last = Number(entry.last) || 0;
        if (count <= 0)
            return 0;
        const age = Math.max(0, Date.now() - last);
        return count * Math.pow(0.5, age / root.halfLifeMs);
    }

    function recordLaunch(appId) {
        const id = String(appId ?? "");
        if (id.length === 0)
            return;
        const next = Object.assign({}, root.usage);
        const entry = Object.assign({}, next[id] ?? {});
        entry.count = (Number(entry.count) || 0) + 1;
        entry.last = Date.now();
        next[id] = entry;
        root.usage = next;
        persistTimer.restart();
    }

    function resetRanking() {
        root.usage = {};
        persistTimer.restart();
    }

    Timer {
        id: persistTimer
        interval: 250
        onTriggered: store.setText(JSON.stringify(root.usage))
    }

    FileView {
        id: store
        path: Qt.resolvedUrl(root.filePath)
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                const parsed = JSON.parse(store.text());
                root.usage = parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : {};
            } catch (e) {
                root.usage = {};
            }
            root.ready = true;
        }
        onLoadFailed: root.ready = true
    }
}
