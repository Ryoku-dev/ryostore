pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "functions"

// Trimmed from the barstyle Persistent to the search state the launcher owns:
// recent queries, recent emojis, aliases and result keybinds. One file at
// ~/.local/state/imi/states.json, shared with the barstyle's state directory.
Singleton {
    id: root

    property alias states: persistentStatesJsonAdapter
    readonly property string fileDir: FileUtils.trimFileProtocol(`${Directories.state}/imi`)
    readonly property string fileName: "states.json"
    readonly property string filePath: `${root.fileDir}/${root.fileName}`

    property bool ready: false
    property bool blockWrites: false
    property real initTimestamp: Date.now()
    property int missingFileGracePeriod: 5000
    property int missingFileRetryInterval: 1500

    Timer {
        id: fileWriteTimer
        interval: 75
        repeat: false
        onTriggered: {
            if (root.blockWrites)
                return;
            if (!root.ready) {
                fileWriteTimer.restart();
                return;
            }
            if (Date.now() - root.initTimestamp < 3000) {
                fileWriteTimer.restart();
                return;
            }
            statesFileView.writeAdapter();
        }
    }

    onStatesChanged: fileWriteTimer.restart()

    Timer {
        id: missingFileRetryTimer
        interval: root.missingFileRetryInterval
        repeat: false
        onTriggered: statesFileView.reload()
    }

    FileView {
        id: statesFileView
        path: Qt.resolvedUrl(root.filePath)
        adapter: persistentStatesJsonAdapter
        watchChanges: false
        onAdapterUpdated: fileWriteTimer.restart()
        onLoaded: root.ready = true
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound) {
                if (Date.now() - root.initTimestamp > root.missingFileGracePeriod)
                    statesFileView.writeAdapter();
                else
                    missingFileRetryTimer.restart();
                return;
            }
            console.log("[imi-launcher] States load error:", error);
        }
    }

    JsonAdapter {
        id: persistentStatesJsonAdapter

        property JsonObject search: JsonObject {
            property list<var> aliases: []
            property list<string> recentEmojis: []
            property list<string> recentQueries: []
            property list<var> resultKeybinds: []
            property list<var> pinnedEntries: []
            property list<var> panelUsage: []
            property list<var> calculatorHistory: []
            property real exchangeRatesUpdatedAt: 0
        }

        property JsonObject clipboard: JsonObject {
            property list<string> historySeen: []
        }
    }
}
