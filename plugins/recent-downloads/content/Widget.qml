pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Ryoku.PluginKit.Singletons

Item {
    id: root
    property var pluginApi
    property var screen
    property bool active: false
    property string density: "glyph"
    property real s: 1
    property real widthBudget: 220
    property bool open: false
    property real reveal: 0
    property bool tabActive: false
    signal requestClose()

    implicitWidth: 24 * root.s
    implicitHeight: 24 * root.s

    Shape {
        anchors.centerIn: parent
        width: 24
        height: 24
        scale: root.s * 0.78
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: hover.containsMouse ? Theme.bright : Theme.dim
            strokeWidth: 1.5
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            fillColor: "transparent"
            startX: 6
            startY: 20
            PathLine { x: 18; y: 20 }
            PathMove { x: 12; y: 4 }
            PathLine { x: 12; y: 16 }
            PathLine { x: 15.5; y: 12.5 }
            PathMove { x: 12; y: 16 }
            PathLine { x: 8.5; y: 12.5 }
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            if (root.pluginApi && root.pluginApi.togglePanel)
                root.pluginApi.togglePanel();
        }
        ToolTip.visible: containsMouse
        ToolTip.text: "Recent Downloads"
        ToolTip.delay: 450
        ToolTip.timeout: 3000
    }
}
