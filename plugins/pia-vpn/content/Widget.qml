pragma ComponentBehavior: Bound
import QtQuick
import Ryoku.PluginKit.Singletons

// content/Widget.qml: the bar glyph. A fixed-width VPN icon (Material Symbols
// Rounded "vpn_lock", the icon font every qsbar built-in widget uses) plus a
// small status dot -- solid when Connected, an empty ring otherwise. Fixed
// width on purpose: a long region/server name used to push neighbouring
// widgets off the bar, so nothing variable-length renders here any more.
// Left click only opens the panel (no click on the bar ever mutates anything);
// region name, IP, connect/disconnect and the region switcher all live in
// Panel.qml.
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
    readonly property string state: service ? service.connectionState : "Unknown"
    readonly property bool connected: root.state === "Connected"

    readonly property color iconColor: (root.active || root.open || root.connected) ? Theme.accent : Theme.dim

    implicitWidth: row.implicitWidth
    implicitHeight: Math.max(row.implicitHeight, 18 * root.s)

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5 * root.s

        // Material Symbols Rounded ligature, same icon font every qsbar
        // built-in widget uses (see IconMap.js / IconText.qml); "vpn_lock" is
        // the closest stock glyph to a VPN mark.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "vpn_lock"
            renderType: Text.QtRendering
            font.family: "Material Symbols Rounded"
            color: root.iconColor
            font.pixelSize: 15 * root.s
            Behavior on color { ColorAnimation { duration: 160 } }
        }

        Rectangle {
            id: dot
            anchors.verticalCenter: parent.verticalCenter
            width: 7 * root.s
            height: 7 * root.s
            radius: width / 2
            color: root.connected ? Theme.accent : "transparent"
            border.width: root.connected ? 0 : Math.max(1, 1 * root.s)
            border.color: Theme.dim
            Behavior on color { ColorAnimation { duration: 160 } }
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
