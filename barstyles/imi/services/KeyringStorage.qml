pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Small secret storage for the bar (API keys for lyrics and wallpaper services).
 *
 * The host shell has no secret store: its Keyring service only drives the GNOME
 * keyring unlock prompt, and the daemon exposes no way to stash a blob. So the
 * JSON lives in a state file (written atomically, watched for outside changes)
 * instead of the login keyring. Same shape as the original: a single JSON object
 * addressed by key paths.
 */
Singleton {
    id: root

    signal dataChanged()

    property bool loaded: false
    readonly property var keyringData: adapter.data ?? {}

    readonly property string statePath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state"))
        + "/ryoku/barstyles/imi/keyring.json"

    function setNestedField(path, value) {
        root.setNestedFields([{ path: path, value: value }]);
    }

    function setNestedFields(entries) {
        if (!entries || entries.length === 0) return;
        let data;
        try {
            data = JSON.parse(JSON.stringify(root.keyringData ?? {}));
        } catch (e) {
            data = {};
        }

        for (let j = 0; j < entries.length; ++j) {
            const item = entries[j];
            if (!item || !item.path) continue;
            const keys = item.path;
            let obj = data;
            for (let i = 0; i < keys.length - 1; ++i) {
                if (!obj[keys[i]] || typeof obj[keys[i]] !== "object")
                    obj[keys[i]] = {};
                obj = obj[keys[i]];
            }
            obj[keys[keys.length - 1]] = item.value;
        }

        adapter.data = data;
        root.dataChanged();
    }

    // Kept name: reloads the stored JSON from disk.
    function fetchKeyringData() {
        store.reload();
    }

    function _ingest() {
        root.loaded = true;
        // Normalizing through parse+stringify replaces an unreadable file with {}.
        let parsed;
        try {
            parsed = JSON.parse(store.text() || "{}");
        } catch (e) {
            parsed = {};
        }
        if (!parsed || typeof parsed !== "object")
            parsed = {};
        // Skip the write-back when the file said what we already hold.
        if (JSON.stringify(adapter.data ?? {}) === JSON.stringify(parsed))
            return;
        adapter.data = parsed;
    }

    Component.onCompleted: root.fetchKeyringData()

    FileView {
        id: store
        path: root.statePath
        atomicWrites: true
        watchChanges: true
        printErrors: false
        onFileChanged: store.reload()
        onAdapterUpdated: store.writeAdapter()
        onLoaded: root._ingest()
        onLoadFailed: root._ingest()

        JsonAdapter {
            id: adapter
            property var data: ({})
        }
    }
}
