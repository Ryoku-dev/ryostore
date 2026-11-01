pragma ComponentBehavior: Bound
import QtQuick
import Ryoku.PluginKit.Singletons

// content/Widget.qml is the one view every host mounts (on the bar, this is the
// glyph). It reads live state from the service through pluginApi.mainInstance.
// Kept to a FIXED-width icon + a small count badge -- every variable-length
// detail (drive names, mountpoints) lives in the panel instead, never here.
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
    readonly property int readyCount: service ? service.readyCount : 0
    readonly property bool showBadge: {
        if (!pluginApi || !pluginApi.pluginSettings)
            return true;
        var v = pluginApi.pluginSettings.showBadge;
        return v === undefined ? true : v;
    }

    implicitWidth: 22 * root.s
    implicitHeight: Math.max(22 * root.s, 18 * root.s)

    Text {
        id: glyph
        anchors.centerIn: parent
        text: "usb"
        font.family: "Material Symbols Rounded"
        renderType: Text.QtRendering
        font.pixelSize: 16 * root.s
        color: root.readyCount > 0 ? Theme.accent : ((root.active || root.open) ? Theme.bright : Theme.dim)
    }

    // Small fixed badge, never wider than this -- the count itself can only
    // ever be a small number of plugged-in drives.
    Rectangle {
        visible: root.showBadge && root.readyCount > 0
        width: 14 * root.s
        height: 14 * root.s
        radius: width / 2
        color: Theme.accent
        anchors.right: glyph.right
        anchors.top: glyph.top
        anchors.rightMargin: -6 * root.s
        anchors.topMargin: -4 * root.s

        Text {
            anchors.centerIn: parent
            text: root.readyCount > 9 ? "9+" : String(root.readyCount)
            color: Theme.cardBot
            font.family: Theme.font
            font.pixelSize: 9 * root.s
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
