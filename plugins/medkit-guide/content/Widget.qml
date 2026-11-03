import QtQuick
import Ryoku.PluginKit

Item {
  id: root
  property var pluginApi
  property bool isGlyph: true
  property real s: 1
  property real glyphW: 22
  property real glyphH: 22

  readonly property var service: pluginApi && pluginApi.mainInstance ? pluginApi.mainInstance : null

  // Pill icon with status
  Canvas {
    id: pillMark
    anchors.centerIn: parent
    width: root.glyphW * root.s
    height: root.glyphH * root.s
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      var scale = Math.min(width / 24, height / 24)
      ctx.save()
      ctx.translate((width - 24 * scale) / 2, (height - 24 * scale) / 2)
      ctx.scale(scale, scale)

      // Pill shape (capsule)
      ctx.fillStyle = "#4ade80"
      ctx.beginPath()
      ctx.roundRect(4, 8, 16, 8, 4)
      ctx.fill()

      // Pill divider
      ctx.strokeStyle = "rgba(0,0,0,0.2)"
      ctx.lineWidth = 1
      ctx.beginPath()
      ctx.moveTo(12, 8)
      ctx.lineTo(12, 16)
      ctx.stroke()

      // Left half (white)
      ctx.fillStyle = "rgba(255,255,255,0.3)"
      ctx.beginPath()
      ctx.roundRect(4, 8, 8, 8, 4)
      ctx.fill()

      ctx.restore()
    }
  }

  MouseArea {
    anchors.fill: parent
    onClicked: root.pluginApi && root.pluginApi.togglePanel()
  }
}
