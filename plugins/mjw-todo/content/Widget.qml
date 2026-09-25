pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "."

// Host adapter for a ported MJW desktop tile. Three jobs:
//  1. hydrate the widget's config entry from the tile's live settings: the
//     host's pluginSettings is a reactive binding, so a Ryoku Settings write
//     flows through onPluginApiChanged without a shell restart;
//  2. bridge the host accent handoff onto Appearance;
//  3. re-export the content's keyboard flag as `editing` for the host.
Item {
    id: root

    property var pluginApi
    property var screen
    property bool active: true
    property string density: "compact"
    property real s: 1
    property real widthBudget: 0

    // accent handoff (the host pushes these onto every colors-capable tile)
    property color accentColor: "transparent"
    property bool accentFromHost: false
    readonly property bool accentOn: accentFromHost && accentColor.a > 0
    onAccentColorChanged: Appearance.setAccent(accentOn ? accentColor : "transparent")
    onAccentFromHostChanged: Appearance.setAccent(accentOn ? accentColor : "transparent")

    // the host reads `editing` off the tile root to grab the keyboard layer
    readonly property bool editing: wdg._kb

    // resolve the installed folder for shipped bin scripts
    property string pluginDir: (pluginApi && pluginApi.pluginDir) ? pluginApi.pluginDir : ""
    onPluginDirChanged: Directories.pluginDir = root.pluginDir

    // settings hydration: pluginApi.pluginSettings re-emits when the host's
    // registry re-reads placement, so every write lands here live.
    property var lastSettings: null
    onPluginApiChanged: {
        root.lastSettings = (pluginApi && pluginApi.pluginSettings) ? pluginApi.pluginSettings : null;
        Config.hydrate(root.lastSettings);
    }
    Connections {
        target: (root.pluginApi && root.pluginApi.pluginSettings) ? root.pluginApi : null
        function onPluginSettingsChanged() {
            root.lastSettings = root.pluginApi.pluginSettings;
            Config.hydrate(root.lastSettings);
        }
    }

    Component.onCompleted: {
        Appearance.setAccent(accentOn ? accentColor : "transparent");
        Directories.pluginDir = root.pluginDir;
        Config.hydrate((pluginApi && pluginApi.pluginSettings) ? pluginApi.pluginSettings : null);
    }

    implicitWidth: wdg.implicitWidth
    implicitHeight: wdg.implicitHeight

    TodoWidget {
        id: wdg
        pluginApi: root.pluginApi
        screen: root.screen
        active: root.active
        density: root.density
        s: root.s
        widthBudget: root.widthBudget
    }
}
