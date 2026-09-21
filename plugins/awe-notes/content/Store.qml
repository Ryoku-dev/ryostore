pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Per-plugin local state: one JSON document at
// $XDG_STATE_HOME/ryoku/plugins/<id>/state.json. Sections are top-level keys;
// save(section, value) replaces one section and rewrites the file. Reads are
// synchronous at completion (blockLoading); `loaded` is set for consumers that
// prefer to adopt state reactively.
Singleton {
    id: root

    readonly property string pluginId: "awe-notes"
    readonly property string dir: (Quickshell.env("XDG_STATE_HOME")
        || (Quickshell.env("HOME") + "/.local/state")) + "/ryoku/plugins/" + root.pluginId
    readonly property string path: root.dir + "/state.json"

    property var doc: ({})
    property bool loaded: false
    property bool dirReady: false
    property bool savePending: false

    function save(section, value) {
        var d = {}
        for (var k in root.doc) d[k] = root.doc[k]
        d[section] = value
        root.doc = d
        if (!root.dirReady) {
            root.savePending = true
            mkdir.running = true
            return
        }
        root.flush()
    }

    function flush() {
        store.setText(JSON.stringify(root.doc, null, 2))
    }

    FileView {
        id: store
        path: root.path
        blockLoading: true
        atomicWrites: true
        printErrors: false
    }

    Process {
        id: mkdir
        command: ["mkdir", "-p", root.dir]
        onExited: {
            root.dirReady = true
            if (root.savePending) {
                root.savePending = false
                root.flush()
            }
        }
    }

    Component.onCompleted: {
        mkdir.running = true
        var raw = ""
        try { raw = store.text() } catch (e) {}
        try {
            root.doc = (raw && raw.length > 0) ? JSON.parse(raw) : ({})
        } catch (e) {
            root.doc = ({})
        }
        root.loaded = true
    }
}
