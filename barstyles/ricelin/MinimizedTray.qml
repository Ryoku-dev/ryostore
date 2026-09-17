pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Ryoku.Ui.Singletons
import "Singletons"

/**
 * Row of icon buttons for windows parked on the minimised workspace (Super+M).
 * Clicking one moves it back to the workspace this pill lives on.
 *
 * A minimised workspace is a capability, not an assumption: a compositor with no
 * special workspaces reports none and this row stays empty, while the same code
 * drives whichever workspace the parked windows actually sit on.
 */
Row {
    id: root

    property real s: 1
    property string screenName: ""
    spacing: 8 * s

    readonly property bool parkedSupported: Wm.caps.specialWorkspace === true
    readonly property bool isParked: function (name) { return String(name || "").indexOf("special:") === 0; }

    /**
     * Resolve the workspace to restore into: the active workspace of the monitor
     * this pill lives on, so a window reappears on the screen the user clicked,
     * falling back to the focused workspace.
     */
    function restoreWorkspace() {
        var mon = Wm.outputByName(root.screenName);
        if (mon && mon.activeWorkspace)
            return String(mon.activeWorkspace);
        return Wm.focusedWorkspace ? String(Wm.focusedWorkspace.name) : "";
    }

    readonly property var items: {
        var out = [];
        if (!root.parkedSupported)
            return out;
        var wins = Wm.windows;
        for (var i = 0; i < wins.length; i++) {
            var w = wins[i];
            if (w && root.isParked(w.workspace))
                out.push(w);
        }
        return out;
    }
    readonly property int count: items.length

    /**
     * Resolve an icon path for a window by matching its app id to a desktop entry
     * id (the app id often differs from the icon-theme name), with a direct
     * icon-theme lookup as fallback.
     */
    function iconFor(w) {
        var cls = w ? String(w.appId || "") : "";
        if (!cls)
            return "";
        var apps = DesktopEntries.applications.values;
        for (var i = 0; i < apps.length; i++) {
            var e = apps[i];
            if (e && e.id && e.id.toLowerCase() === cls.toLowerCase() && e.icon)
                return Quickshell.iconPath(e.icon, "application-x-executable");
        }
        return Quickshell.iconPath(cls, "application-x-executable");
    }

    Repeater {
        model: root.items

        delegate: Item {
            id: chip
            required property var modelData
            width: 18 * root.s
            height: 18 * root.s

            readonly property string iconSrc: root.iconFor(chip.modelData)

            Image {
                anchors.fill: parent
                sourceSize.width: Math.round(36 * root.s)
                sourceSize.height: Math.round(36 * root.s)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
                source: chip.iconSrc
                opacity: area.containsMouse ? 1 : 0.78
                Behavior on opacity { NumberAnimation { duration: Motion.fast } }
            }

            MouseArea {
                id: area
                anchors.fill: parent
                anchors.margins: -3 * root.s
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var target = root.restoreWorkspace();
                    if (target !== "")
                        Wm.moveWindowToWorkspace(chip.modelData.id, target);
                }
            }

            Tooltip {
                s: root.s
                placement: "below"
                title: chip.modelData.title
                show: area.containsMouse
            }
        }
    }
}
