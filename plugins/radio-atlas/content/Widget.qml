import QtQuick
import Ryoku.PluginKit.Singletons

// Radio Atlas glyph: a globe mark with the station or the volume beside it.
//
// Ported from the Omarchy bar widget's BarWidget.qml + WidgetButton. The
// Omarchy original got its click targets from a `bar` handle the shell injected;
// Ryoku's host instead hands every content root a `pluginApi` with the panel
// controls, so the bar bindings collapse to pluginApi calls.
Item {
    id: root

    property var pluginApi
    property var screen
    property bool active: false
    property string density: "glyph"
    property real s: 1
    property real widthBudget: 220

    readonly property var service: pluginApi ? pluginApi.mainInstance : null

    readonly property bool running: service ? service.running === true : false
    readonly property bool paused: service ? service.paused === true : false
    readonly property bool stopped: service ? service.stopped === true : false
    readonly property string stationName: service ? String(service.stationName) : ""
    readonly property string title: service ? String(service.title) : ""
    readonly property string error: service ? String(service.streamError) : ""
    readonly property bool muted: service ? service.muted === true : false
    readonly property int volume: service ? Number(service.volume) : 70
    readonly property string fetchError: service ? String(service.fetchError) : ""

    readonly property string barMode: {
        var s = root.pluginApi && root.pluginApi.pluginSettings;
        return s && s.barMode ? String(s.barMode) : "globe";
    }

    readonly property string labelText: {
        if (root.error !== "") return "radio!";
        if (!root.running) return root.stopped ? "stopped" : "Radio Atlas";
        var name = root.stationName !== "" ? root.stationName : root.title;
        if (name === "") name = "Radio Atlas";
        return name.length > 26 ? name.slice(0, 26) + "…" : name;
    }

    implicitWidth: row.implicitWidth + 4 * s
    implicitHeight: Math.max(row.implicitHeight, 18 * s)

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6 * root.s

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf0ac"
            color: root.error !== "" ? Theme.verm
                : root.running && !root.paused ? Theme.accent : Theme.dim
            font.family: Theme.font
            font.pixelSize: 13 * root.s
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.labelText
            color: root.error !== "" ? Theme.verm : Theme.bright
            font.family: Theme.font
            font.pixelSize: 13 * root.s
            elide: Text.ElideRight
            width: root.widthBudget > 0
                ? Math.min(implicitWidth, root.widthBudget - 18 * root.s)
                : implicitWidth
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onWheel: function(delta) { root.service && root.service.volumeUp(); }
        onClicked: function(mouse) {
            var svc = root.service;
            if (!svc) return;
            if (mouse.button === Qt.MiddleButton) {
                svc.random();
                return;
            }
            if (mouse.button === Qt.RightButton) {
                if (root.stopped) svc.resume();
                else if (root.running) svc.stop();
                return;
            }
            if (root.pluginApi && typeof root.pluginApi.togglePanel === "function")
                root.pluginApi.togglePanel();
        }
    }
}
