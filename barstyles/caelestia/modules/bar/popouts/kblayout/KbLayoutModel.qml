import QtQuick
import Ryoku.Ui.Singletons

QtObject {
    id: root

    readonly property var visibleModel: layouts
    readonly property string activeLabel: Wm.keyboardLayout || ""
    property bool started: false

    function label(entry): string {
        if (typeof entry === "string")
            return entry;
        return String(entry?.label ?? entry?.name ?? entry?.layout ?? "");
    }

    function start(): void {
        if (started)
            return;
        started = true;
        refresh();
    }

    function refresh(): void {
        layouts.clear();
        const configured = Wm.keyboardLayouts || [];
        for (let index = 0; index < configured.length; index++)
            layouts.append({ layoutIndex: index, label: label(configured[index]) });
        if (!configured.length && activeLabel)
            layouts.append({ layoutIndex: 0, label: activeLabel });
    }

    function switchTo(index: int): void {
        const values = Wm.keyboardLayouts || [];
        if (!Wm.caps.keyboardLayoutSwitch || !values.length)
            return;
        const current = Math.max(0, values.findIndex(entry => label(entry) === activeLabel));
        const steps = (index - current + values.length) % values.length;
        for (let step = 0; step < steps; step++)
            Wm.cycleKeyboardLayout();
    }

    onActiveLabelChanged: refresh()

    property Connections wmConnections: Connections {
        target: Wm
        function onKeyboardLayoutsChanged(): void { root.refresh(); }
    }

    property ListModel layouts: ListModel {}
}
