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
  readonly property real progress: {
    if (!service) return 0
    var goal = Number(service.dailyGoal)
    if (!isFinite(goal) || goal <= 0) return service.todayGrams > 0 ? 1 : 0
    return Math.max(0, service.todayGrams / goal)
  }
  readonly property color spoonColor: root.rampColor(root.progress)

  // White at zero, green around a third, orange approaching the goal, red at it.
  function rampColor(progress) {
    var stops = [
      { at: 0.00, color: [1.00, 1.00, 1.00] },
      { at: 0.35, color: [0.31, 0.81, 0.45] },
      { at: 0.70, color: [1.00, 0.63, 0.20] },
      { at: 1.00, color: [0.98, 0.23, 0.19] }
    ]
    var p = Math.max(0, Math.min(1, Number(progress) || 0))
    for (var i = 1; i < stops.length; i++) {
      if (p <= stops[i].at) {
        var from = stops[i - 1]
        var to = stops[i]
        var span = to.at - from.at
        var t = span > 0 ? (p - from.at) / span : 0
        return Qt.rgba(
          from.color[0] + (to.color[0] - from.color[0]) * t,
          from.color[1] + (to.color[1] - from.color[1]) * t,
          from.color[2] + (to.color[2] - from.color[2]) * t,
          1)
      }
    }
    return Qt.rgba(stops[stops.length - 1].color[0], stops[stops.length - 1].color[1], stops[stops.length - 1].color[2], 1)
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
      ctx.setTransform(1, 0, 0, 1, 0, 0)
      ctx.clearRect(0, 0, width, height)
      ctx.save()
      ctx.scale(scale, scale)
      ctx.fillStyle = root.spoonColor

      // Bowl.
      ctx.beginPath()
      ctx.ellipse(11.0, 8.6, 7.2, 8.2, 0, 0, 2 * Math.PI)
      ctx.fill()

      // Tapered handle with a rounded tip.
      ctx.beginPath()
      ctx.moveTo(9.4, 16.6)
      ctx.bezierCurveTo(9.5, 21.2, 10.2, 26.8, 10.4, 30.1)
      ctx.quadraticCurveTo(10.5, 31.4, 11.0, 31.4)
      ctx.quadraticCurveTo(11.5, 31.4, 11.6, 30.1)
      ctx.bezierCurveTo(11.8, 26.8, 12.5, 21.2, 12.6, 16.6)
      ctx.closePath()
      ctx.fill()

      // Shaded hollow of the bowl, so the spoon still reads at small sizes.
      ctx.beginPath()
      ctx.ellipse(11.0, 8.8, 3.8, 5.0, 0, 0, 2 * Math.PI)
      ctx.globalAlpha = 0.16
      ctx.fillStyle = "#000000"
      ctx.fill()
      ctx.globalAlpha = 1.0

      ctx.restore()
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
      color: root.service?.overGoal ? "#fa3b30" : Theme.cream
      font.family: Theme.font
      font.pixelSize: 24 * root.s
      font.bold: true
    }
  }
}
