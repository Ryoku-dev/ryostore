pragma Singleton

import QtQuick
import Quickshell

// The shell's toasts, newest first.
Singleton {
    id: root

    property list<Toast> toasts

    function toast(title: string, message: string, icon: string, type: int, timeout: int): void {
        const t = toastComponent.createObject(root, {
            title: title,
            message: message,
            icon: icon ?? "",
            type: type ?? Toast.Info,
            timeout: timeout ?? 0
        });
        t.finishedClose.connect(() => {
            root.toasts = Array.from(root.toasts).filter(x => x !== t);
            t.destroy();
        });
        root.toasts = [t].concat(Array.from(root.toasts));
    }

    Component {
        id: toastComponent

        Toast {}
    }
}
