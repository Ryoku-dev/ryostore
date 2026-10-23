pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// What the panels used from the plugin's CUtils, in QML.
Singleton {
    id: root

    // shortcut: no lock-key state without the plugin; the caps/num lock icons stay hidden
    readonly property bool capsLock: false
    readonly property bool numLock: false

    function clamp(value: real, min: real, max: real): real {
        return Math.min(Math.max(value, min), max);
    }

    function toLocalFile(url: url): string {
        return decodeURIComponent(url.toString().replace(/^file:\/\//, ""));
    }

    function copyFile(source: url, target: url): bool {
        const reader = fileView.createObject(root, { path: toLocalFile(source) });
        const data = reader.data();
        reader.destroy();
        if (!data || data.byteLength === 0)
            return false;
        const writer = fileView.createObject(root, { path: toLocalFile(target) });
        writer.setData(data);
        writer.destroy();
        return true;
    }

    function deleteFile(path: url): bool {
        Quickshell.execDetached(["rm", "-f", "--", toLocalFile(path)]);
        return true;
    }

    function saveItem(target: Item, path: url, onSaved: var, onFailed: var): void {
        target.grabToImage(result => {
            if (result.saveToFile(toLocalFile(path)))
                onSaved?.();
            else
                onFailed?.();
        });
    }

    function findChildren(item: Item, name: string): list<Item> {
        return matching(item, child => child.objectName === name);
    }

    function findChild(item: Item, name: string): Item {
        return findChildren(item, name)[0] ?? null;
    }

    function findChildrenMatching(item: Item, pattern: string): list<Item> {
        const re = new RegExp(pattern);
        return matching(item, child => re.test(child.objectName));
    }

    function matching(item: Item, test: var): var {
        const out = [];
        const walk = node => {
            for (const child of node?.children ?? []) {
                if (test(child))
                    out.push(child);
                walk(child);
            }
        };
        walk(item);
        return out;
    }

    Component {
        id: fileView

        FileView {
            blockLoading: true
            blockWrites: true
            printErrors: false
        }
    }
}
