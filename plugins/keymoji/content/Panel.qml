import QtQuick
import "../app" as App
import Ryoku.PluginKit.Singletons
Item {
    id:root
    property var pluginApi
    property string density:"full"
    property real widthBudget:320
    property real s:1
    property bool active:false
    App.Localization {id:i18n;stateDir:root.pluginApi?root.pluginApi.stateDir:""}
    implicitHeight:content.implicitHeight+32*s
    Column {
        id:content
        anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:16*root.s;spacing:12*root.s
        Text {text:"Keymoji";font.pixelSize:18*root.s;color:Theme.bright}
        Text {width:parent.width;wrapMode:Text.WordWrap;text:i18n.t("panel.subtitle");color:Theme.dim;font.pixelSize:12*root.s}
        Rectangle {
            width:parent.width;height:36*root.s;radius:8*root.s;color:"transparent";border.color:Theme.accent
            Text {anchors.centerIn:parent;text:i18n.t("panel.open");font.pixelSize:13*root.s;color:Theme.accent}
            MouseArea {anchors.fill:parent;onClicked:if(root.pluginApi&&root.pluginApi.mainInstance)root.pluginApi.mainInstance.launch()}
        }
    }
}
