pragma ComponentBehavior: Bound
import QtQuick
import Ryoku.PluginKit.Singletons

// Bar glyph: a status dot, the exit country's flag, the country and the IP.
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
    readonly property var cfg: pluginApi ? pluginApi.pluginSettings : null
    readonly property bool showFlag: (cfg && cfg.showFlag) ?? true
    readonly property bool showIp: (cfg && cfg.showIp) ?? true
    readonly property string countryStyle: (cfg && cfg.countryStyle) ?? "name"

    readonly property bool flagShown: root.showFlag && !!root.service && root.service.connected && root.service.geoOk && root.service.cc !== ""

    readonly property string label: {
        const sv = root.service;
        if (!sv) return "Happ";
        if (!sv.running) return sv.t("Happ off", "Happ выкл");
        if (!sv.tun) return sv.t("Happ: no tunnel", "Happ: нет туннеля");
        if (!sv.geoOk) return sv.geoBusy ? "Happ…" : sv.t("Happ: no exit", "Happ: нет выхода");
        const parts = [];
        if (root.countryStyle !== "none")
            parts.push(root.countryStyle === "code" ? sv.cc : (sv.country || sv.cc));
        if (root.showIp && sv.ip) parts.push(sv.ip);
        return parts.join(" · ") || (root.flagShown ? "" : "Happ");
    }

    implicitWidth: row.implicitWidth
    implicitHeight: Math.max(row.implicitHeight, 18 * root.s)

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6 * root.s

        Rectangle {
            visible: !root.flagShown
            anchors.verticalCenter: parent.verticalCenter
            width: 7 * root.s; height: width; radius: width / 2
            color: !root.service || !root.service.running ? Theme.faint
                 : (root.service.connected && root.service.geoOk) ? Theme.accent : Theme.sun
        }

        Text {
            visible: root.flagShown
            anchors.verticalCenter: parent.verticalCenter
            text: root.service ? root.service.flag(root.service.cc) : ""
            font.pixelSize: 13 * root.s
        }

        Text {
            visible: root.label !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: root.service && root.service.connected ? Theme.bright : Theme.dim
            font.family: Theme.font
            font.pixelSize: 13 * root.s
            elide: Text.ElideRight
            width: root.widthBudget > 0 ? Math.min(implicitWidth, root.widthBudget - 40 * root.s) : implicitWidth
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (!root.pluginApi) return;
            if (root.open) root.requestClose();
            else if (root.pluginApi.togglePanel) root.pluginApi.togglePanel();
        }
    }
}
