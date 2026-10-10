pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Ryoku.PluginKit.Singletons
Item {
    id: root
    property var pluginApi
    property var screen
    property bool active: false
    property string density: "glyph"
    property real s: 1
    property real widthBudget: 220
    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    implicitWidth: glyph.implicitWidth
    implicitHeight: 22
    Text {
        id: glyph
        anchors.verticalCenter: parent.verticalCenter
        text: root.service && root.service.enabled ? "battery_alert" : "notifications_off"
        font.family: "Material Symbols Rounded"
        font.pixelSize: 19
        font.weight: 500
        font.variableAxes: ({"FILL": root.service && root.service.enabled ? 1 : 0, "opsz": 20})
        color: root.service && root.service.enabled ? Theme.accent : Theme.dim
        renderType: Text.QtRendering
    }
    HoverHandler { id: hover }
    ToolTip.visible: hover.hovered
    ToolTip.delay: 350
    ToolTip.text: root.service && root.service.enabled
        ? qsTr("Battery alerts · %1% / %2% (click to configure)").arg(root.service.lowThreshold).arg(root.service.criticalThreshold)
        : qsTr("Battery alerts paused (click to configure)")
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.pluginApi) root.pluginApi.togglePanel() }
}
