pragma Singleton

import Quickshell

// Where the style's settings entry points lead. The bar, panels and style pages are
// the style's own settings panel (modules/settings); anything else opens the Ryoku Hub.
Singleton {
    id: root

    property bool settingsOpen: false
    property string settingsPage: "bar"

    readonly property var stylePages: ({
            shellbar: "bar",
            shellpanels: "panels",
            shellstyle: "style"
        })

    function open(page): void {
        if (root.stylePages[page]) {
            root.settingsPage = root.stylePages[page];
            root.settingsOpen = true;
            return;
        }
        Quickshell.execDetached(["ryoku-shell", "hub", "open"].concat(page ? [String(page)] : []));
    }

    // the bar's context cards carry a page number of the old Nexus app: all are bar settings
    function openPage(subPageIdx: int): void {
        root.open("shellbar");
    }
}
