import QtQuick
import Ryoku.PluginKit.Singletons

// content/Widget.qml: the bar capsule. Shows the configured channel's volume
// and scrolls it; a left click opens the panel, a right click mutes the mic.
// A channel that changes elsewhere (the device itself, another monitor's
// copy of this plugin) flashes its name and new level here briefly, since a
// bar plugin owns one panel and it is reserved for the user's own click.
Item {
    id: root

    property var pluginApi
    property var screen
    property bool active: false
    property string density: "glyph"
    property real s: 1
    property real widthBudget: 0

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property var settings: pluginApi ? pluginApi.pluginSettings : null

    readonly property string channel: (settings && settings.channel) ? settings.channel : "Mic"
    readonly property string displayMode: (settings && settings.display) ? settings.display : "glyph_value"
    readonly property string glyph: (settings && settings.glyph) ? settings.glyph : "\u25C6"
    readonly property string glyphStyle: (settings && settings.glyphStyle) ? settings.glyphStyle : "text"
    readonly property string glyphFont: root.glyphStyle === "icon" ? "Material Symbols Rounded" : Theme.mono
    readonly property bool showChannelName: settings ? settings.showChannelName === true : false
    readonly property bool muteIndicatorOn: settings ? settings.muteIndicator !== false : true
    readonly property bool hideWhenAbsent: settings ? settings.hideWhenAbsent === true : false
    readonly property int scrollStep: (settings && settings.scrollStep) ? settings.scrollStep : 2

    readonly property bool connected: service ? service.connected : false
    readonly property bool showingFlash: service ? (service.flashVisible && service.flashChannel !== "") : false
    readonly property string effectiveChannel: showingFlash ? service.flashChannel : root.channel
    readonly property var rawVolume: (service && service.volumes) ? service.volumes[root.effectiveChannel] : undefined
    readonly property bool muted: service ? service.channelMuted(root.effectiveChannel) : false

    function channelLabel(name) {
        const labels = {
            "Mic": "Mic",
            "LineIn": "Line In",
            "Console": "Console",
            "System": "System",
            "Game": "Game",
            "Chat": "Chat",
            "Sample": "Sample",
            "Music": "Music",
            "Headphones": "Headphones",
            "MicMonitor": "Mic Monitor",
            "LineOut": "Line Out"
        };
        return labels[name] || name;
    }

    function valueText() {
        if (!root.connected || root.rawVolume === undefined)
            return "--";
        var text = root.service.volumeText(root.rawVolume);
        if (root.showChannelName || root.showingFlash)
            text = root.channelLabel(root.effectiveChannel) + " " + text;
        return text;
    }

    visible: !(root.hideWhenAbsent && !root.connected)
    implicitWidth: root.visible ? row.implicitWidth : 0
    implicitHeight: Math.max(row.implicitHeight, 18 * root.s)

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6 * root.s

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.displayMode !== "value"
            text: root.muted && root.muteIndicatorOn ? "\u2716" : root.glyph
            color: {
                if (!root.connected)
                    return Theme.dim;
                if (root.showingFlash)
                    return Theme.accent;
                if (root.muted && root.muteIndicatorOn)
                    return Theme.vermDeep;
                return root.active ? Theme.accent : Theme.dim;
            }
            font.family: root.glyphFont
            font.pixelSize: 13 * root.s
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.displayMode !== "glyph"
            text: root.valueText()
            color: root.showingFlash ? Theme.accent : (root.muted && root.muteIndicatorOn ? Theme.vermDeep : Theme.bright)
            font.family: Theme.font
            font.pixelSize: 13 * root.s
            elide: Text.ElideRight
            width: root.widthBudget > 0 ? Math.min(implicitWidth, root.widthBudget) : implicitWidth
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                if (root.service)
                    root.service.toggleMicMute();
            } else if (root.pluginApi) {
                root.pluginApi.togglePanel();
            }
        }
        onWheel: wheel => {
            if (!root.service)
                return;
            var delta = wheel.angleDelta.y > 0 ? root.scrollStep : -root.scrollStep;
            root.service.adjustVolume(root.channel, delta);
        }
    }
}
