pragma ComponentBehavior: Bound

import QtQuick
import shell.services

// One rail in the settings list: name plus a three way mode switch.
Item {
  id: root

  property string label: ""
  property string mode: "auto"
  property string fontFamily: ""
  property color textColor: Theme.onSurface
  property color mutedColor: Theme.onSurfaceVariant
  property color accentColor: Theme.primary
  property color accentTextColor: Theme.onPrimary
  property bool highlighted: false

  signal picked(string mode)
  signal railHovered()
  signal railUnhovered()

  implicitHeight: 34

  HoverHandler {
    onHoveredChanged: hovered ? root.railHovered() : root.railUnhovered()
  }

  readonly property var options: [
    { key: "always", label: "Always" },
    { key: "auto", label: "Hide" },
    { key: "off", label: "Off" }
  ]

  Text {
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    text: root.label
    color: root.highlighted ? root.textColor : root.mutedColor
    font.family: root.fontFamily
    font.pixelSize: 12
  }

  Rectangle {
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    width: 162
    height: 24
    radius: 8
    color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.06)

    Row {
      anchors.fill: parent
      anchors.margins: 2
      spacing: 2

      Repeater {
        model: root.options

        delegate: Rectangle {
          id: seg
          required property var modelData

          readonly property bool active: root.mode === modelData.key

          width: (162 - 4 - 4) / 3
          height: 20
          radius: 6
          color: seg.active
            ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.9)
            : (segHover.hovered ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.08)
                                : "transparent")
          Behavior on color { ColorAnimation { duration: 140 } }

          Text {
            anchors.centerIn: parent
            text: seg.modelData.label
            color: seg.active ? root.accentTextColor : root.mutedColor
            font.family: root.fontFamily
            font.pixelSize: 10
            font.weight: seg.active ? Font.DemiBold : Font.Normal
          }

          HoverHandler {
            id: segHover
            cursorShape: Qt.PointingHandCursor
          }

          TapHandler {
            onTapped: root.picked(seg.modelData.key)
          }
        }
      }
    }
  }
}
