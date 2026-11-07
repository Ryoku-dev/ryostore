import QtQuick
import Ryoku.PluginKit.Singletons
Item {
    id:root
    property var pluginApi
    property string density:"full"
    property real widthBudget:320
    property real s:1
    property bool active:false
    implicitHeight:140*s
    Column {
        anchors.fill:parent;anchors.margins:16*root.s;spacing:12*root.s
        Text {text:"Keymoji";font.pixelSize:18*root.s;color:Theme.bright}
        Text {text:"Emojis no campo ativo, sem copiar.";color:Theme.dim;font.pixelSize:12*root.s}
        Rectangle {
            width:parent.width;height:36*root.s;radius:8*root.s;color:"transparent";border.color:Theme.accent
            Text {anchors.centerIn:parent;text:"Abrir teclado";font.pixelSize:13*root.s;color:Theme.accent}
            MouseArea {anchors.fill:parent;onClicked:if(root.pluginApi&&root.pluginApi.mainInstance)root.pluginApi.mainInstance.launch()}
        }
    }
}
