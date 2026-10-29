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
  readonly property color spoonColor: {
    var progress = service ? Math.max(0, service.todayGrams / service.dailyGoal) : 0
    var start = progress < 0.5 ? Qt.rgba(1, 1, 1, 1) : Qt.rgba(0.20, 0.76, 0.39, 1)
    var end = progress < 0.5 ? Qt.rgba(0.20, 0.76, 0.39, 1) : Qt.rgba(1, 0.56, 0.18, 1)
    var amount = progress < 0.5 ? progress * 2 : Math.min(1, (progress - 0.5) * 2)
    return Qt.rgba(
      start.r + (end.r - start.r) * amount,
      start.g + (end.g - start.g) * amount,
      start.b + (end.b - start.b) * amount,
      1)
  }
  implicitWidth: contentW
  implicitHeight: density === "glyph" ? 32 * s : body.implicitHeight

  Canvas {
    id: spoonMark
    anchors.centerIn: parent
    visible: root.density === "glyph"
    width: 22 * root.s
    height: 32 * root.s
    onPaint: {
      var ctx = getContext("2d")
      var scale = root.s
      var color = root.spoonColor
      ctx.clearRect(0, 0, width, height)
      ctx.fillStyle = color
      ctx.strokeStyle = color
      ctx.lineCap = "round"
      ctx.beginPath()
      ctx.ellipse(11 * scale, 8 * scale, 7 * scale, 9 * scale, 0, 0, 2 * Math.PI)
      ctx.fill()
      ctx.lineWidth = 3 * scale
      ctx.beginPath()
      ctx.moveTo(11 * scale, 16 * scale)
      ctx.bezierCurveTo(11 * scale, 20 * scale, 12 * scale, 25 * scale, 12 * scale, 30 * scale)
      ctx.stroke()
    }
    Connections {
      target: root.service
      function onTodayGramsChanged() { spoonMark.requestPaint() }
      function onDailyGoalChanged() { spoonMark.requestPaint() }
    }
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
