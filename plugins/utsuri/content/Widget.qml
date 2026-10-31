pragma ComponentBehavior: Bound
import QtQuick
import Ryoku.PluginKit.Singletons
import "urls.js" as Urls

// The bar glyph, and the drop target that replaces Utsuri's Shift trigger
// (Wayland never lets an app read global Shift/mouse state). Drag files from
// Dolphin onto it: the panel opens with everything that can be done to them.
Item {
    id: root

    property var pluginApi
    property var screen
    property bool active: false
    property string density: "glyph"
    property real s: 1
    property real widthBudget: 0
    property bool open: false
    property real reveal: 0
    property bool tabActive: false
    signal requestClose()

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property bool busy: service ? service.busy : false
    readonly property bool broken: service ? service.doctorState === "error" : false
    readonly property bool panelOpen: pluginApi ? !!pluginApi.panelOpen : false
    // The radial menu (Shift while dragging) is the main way in. The bar icon
    // ("auto") stays until the Shift+drag trigger has fired once, so a fresh
    // install always has a visible way in and the setup help in its panel.
    readonly property bool shown: {
        const v = pluginApi && pluginApi.pluginSettings ? pluginApi.pluginSettings.barIcon : undefined;
        if (v === true || v === "true" || v === "on")
            return true;
        if (v === "off")
            return false;
        return !(service && service.triggerSeen);
    }

    visible: root.shown
    implicitWidth: root.shown ? mark.implicitWidth + 8 * root.s : 0
    implicitHeight: Math.max(mark.implicitHeight, 18 * root.s)

    Rectangle {
        anchors.fill: parent
        anchors.margins: -2 * root.s
        radius: Theme.radius
        color: drop.containsDrag ? Theme.threadBg : "transparent"
        border.width: drop.containsDrag ? 1 : 0
        border.color: Theme.accent
    }

    Text {
        id: mark
        anchors.centerIn: parent
        text: "⇄"
        color: root.broken ? Theme.sun
             : (drop.containsDrag || root.busy || root.panelOpen) ? Theme.accent : Theme.dim
        font.family: Theme.font
        font.pixelSize: 15 * root.s
        opacity: 1

        // a slow pulse while a conversion runs
        SequentialAnimation on opacity {
            running: root.busy
            loops: Animation.Infinite
            NumberAnimation { to: 0.35; duration: 500 }
            NumberAnimation { to: 1; duration: 500 }
            onRunningChanged: if (!running) mark.opacity = 1
        }
    }

    DropArea {
        id: drop
        anchors.fill: parent
        anchors.margins: -4 * root.s
        keys: ["text/uri-list"]
        onEntered: (drag) => {
            if (drag.hasUrls)
                drag.accept(Qt.CopyAction);
        }
        onDropped: (ev) => {
            const paths = Urls.toPaths(ev.urls);
            if (paths.length === 0 || !root.service)
                return;
            ev.accept(Qt.CopyAction);
            root.service.setFiles(paths);
            if (root.pluginApi && root.pluginApi.openPanel)
                root.pluginApi.openPanel();
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (!root.pluginApi)
                return;
            if (root.open)
                root.requestClose();
            else if (root.pluginApi.togglePanel)
                root.pluginApi.togglePanel();
        }
    }
}
