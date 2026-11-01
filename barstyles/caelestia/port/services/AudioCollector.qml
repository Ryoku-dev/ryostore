pragma Singleton

import QtQuick
import shell.services as ShellServices

QtObject {
    id: root

    property var refs: []
    readonly property var values: ShellServices.AudioBars.levels

    function ref(sender: QtObject): void {
        if (!sender || refs.indexOf(sender) >= 0)
            return;
        refs = refs.concat([sender]);
        ShellServices.AudioBars.setActive(root, true);
    }

    function unref(sender: QtObject): void {
        const index = refs.indexOf(sender);
        if (index >= 0)
            refs = refs.slice(0, index).concat(refs.slice(index + 1));
        if (!refs.length)
            ShellServices.AudioBars.setActive(root, false);
    }

    Component.onDestruction: ShellServices.AudioBars.setActive(root, false)
}
