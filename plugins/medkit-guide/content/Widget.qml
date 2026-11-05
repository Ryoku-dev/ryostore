pragma ComponentBehavior: Bound
import QtQuick

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

  property real glyphW: 22
  property real glyphH: 22
  readonly property var service: pluginApi && pluginApi.mainInstance ? pluginApi.mainInstance : null

  implicitWidth: root.glyphW * root.s
  implicitHeight: root.glyphH * root.s

  Item {
    anchors.centerIn: parent
    width: root.glyphW * root.s
    height: root.glyphH * root.s

    Rectangle {
      anchors.centerIn: parent
      width: 16 * root.s
      height: 8 * root.s
      radius: height / 2
      color: "#4ade80"

      Rectangle {
        width: parent.width / 2
        height: parent.height
        radius: parent.radius
        color: "#ffffff4d"
      }

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(1, root.s)
        height: parent.height
        color: "#33000000"
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    onClicked: {
      if (!root.pluginApi)
        return
      if (root.open)
        root.requestClose()
      else if (root.pluginApi.togglePanel)
        root.pluginApi.togglePanel()
    }
  }
}
