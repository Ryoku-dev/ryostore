import QtQuick

Item {
  id: root

  property string label: ""
  property real from: 0
  property real to: 1
  property real step: 1
  property real value: 0
  property string suffix: ""
  property string fontFamily: ""
  property color textColor: "#ffffff"
  property color mutedColor: Qt.rgba(1, 1, 1, 0.6)
  property color accentColor: "#ffffff"

  signal moved(real value)

  implicitHeight: 40

  function quantize(v) {
    var q = Math.round((v - root.from) / root.step) * root.step + root.from
    return Math.min(root.to, Math.max(root.from, q))
  }

  Text {
    id: labelText
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: 128
    text: root.label
    color: root.textColor
    font.family: root.fontFamily
    font.pixelSize: 12
    elide: Text.ElideRight
  }

  Text {
    id: valueText
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    width: 42
    horizontalAlignment: Text.AlignRight
    text: Math.round(root.value) + root.suffix
    color: root.mutedColor
    font.family: root.fontFamily
    font.pixelSize: 11
  }

  Rectangle {
    id: track
    anchors.left: labelText.right
    anchors.leftMargin: 12
    anchors.right: valueText.left
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    height: 4
    radius: 2
    color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.16)

    readonly property real fraction: (root.value - root.from) / Math.max(0.0001, root.to - root.from)

    Rectangle {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: Math.max(0, Math.min(parent.width, parent.width * track.fraction))
      height: parent.height
      radius: parent.radius
      color: root.accentColor
    }

    Rectangle {
      x: Math.max(0, Math.min(track.width - width, track.width * track.fraction - width / 2))
      anchors.verticalCenter: parent.verticalCenter
      width: 12
      height: 12
      radius: 6
      color: root.accentColor
    }

    MouseArea {
      anchors.fill: parent
      anchors.topMargin: -10
      anchors.bottomMargin: -10
      acceptedButtons: Qt.LeftButton
      onPositionChanged: if (pressed) root.moved(root.quantize(root.from + (mouse.x / width) * (root.to - root.from)))
      onClicked: root.moved(root.quantize(root.from + (mouse.x / width) * (root.to - root.from)))
    }
  }
}
