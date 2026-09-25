pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

// Persistent state for the MJW kit, scoped to the plugin's own state dir.
// Carries only the sections the ported widgets keep across shell restarts
// (the timer engine); the file is debounced exactly like end4's Persistent.
Singleton {
    id: root

    property alias states: persistentStatesJsonAdapter
    property string filePath: Directories.pluginState + "/states.json"
    property bool ready: false

    Timer {
        id: fileWriteTimer
        interval: 100
        onTriggered: persistentStatesFileView.writeAdapter()
    }

    FileView {
        id: persistentStatesFileView
        path: root.filePath
        watchChanges: true
        onAdapterUpdated: fileWriteTimer.restart()
        onLoaded: root.ready = true
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound)
                fileWriteTimer.restart();
        }

        adapter: JsonAdapter {
            id: persistentStatesJsonAdapter

            property JsonObject timer: JsonObject {
                property JsonObject pomodoro: JsonObject {
                    property bool running: false
                    property int start: 0
                    property bool isBreak: false
                    property int cycle: 0
                }
                property JsonObject stopwatch: JsonObject {
                    property bool running: false
                    property int start: 0
                    property list<var> laps: []
                }
                property JsonObject countdown: JsonObject {
                    property bool running: false
                    property int duration: 0
                    property int start: 0
                }
            }
        }
    }
}
