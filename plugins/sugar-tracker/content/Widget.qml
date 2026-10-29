pragma ComponentBehavior: Bound
import QtQuick
import Ryoku.PluginKit
import Ryoku.PluginKit.Singletons

Item {
  id: root
  property var pluginApi
  property var screen
  property bool active
  property string density: "glyph"
  property real s: 1
  property real widthBudget: 0

  readonly property var service: pluginApi ? pluginApi.mainInstance : null
  readonly property real contentW: density === "glyph" ? 32 * s : Math.min(widthBudget > 0 ? widthBudget : 320 * s, 320 * s)
  implicitWidth: contentW
  implicitHeight: density === "glyph" ? 32 * s : body.implicitHeight

  Text {
    anchors.centerIn: parent
    visible: root.density === "glyph"
    text: "fork_spoon"
    color: root.service?.overGoal ? Theme.brand : Theme.cream
    font.family: "Material Symbols Rounded"
    font.pixelSize: 20 * root.s
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.pluginApi?.togglePanel()
  }

  Column {
    id: body
    visible: root.density !== "glyph"
    width: root.contentW
    spacing: 8 * root.s
    MicroLabel { label: qsTr("SUGAR TODAY"); s: root.s }
    Text {
      width: root.contentW
      text: root.service ? root.service.todayGrams + " / " + root.service.dailyGoal + " g" : "—"
      color: root.service?.overGoal ? Theme.brand : Theme.cream
      font.family: Theme.font
      font.pixelSize: 24 * root.s
      font.bold: true
    }
  }
}
