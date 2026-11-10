import QtQuick
import "../app" as App
import Ryoku.PluginKit.Singletons
Item {
    id:root
    property var pluginApi
    property var screen
    property bool active:false
    property string density:"glyph"
    property real s:1
    property real widthBudget:220
    implicitWidth:24*s
    implicitHeight:24*s
    App.Icon {anchors.centerIn:parent;name:"keyboard";width:20*root.s;height:20*root.s;ink:Theme.accent}
    MouseArea {anchors.fill:parent;onClicked:if(root.pluginApi)root.pluginApi.togglePanel()}
}
