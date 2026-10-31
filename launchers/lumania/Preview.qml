import QtQuick
import Ryoku.Ui.Singletons

// Lumania's launcher in Ryoku Settings: the corner notch with its search line
// and one row of app tiles.
Item {
  id: root

  property var settings: ({})
  signal editRequested(string key, var value)

  implicitWidth: 720
  implicitHeight: 250

  readonly property var tiles: [
    ["B", "Browser"], ["T", "Terminal"], ["F", "Files"],
    ["M", "Music"], ["S", "Settings"]
  ]

  Rectangle {
    anchors.fill: parent
    color: Tokens.paper
  }

  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: 6
    color: Tokens.ink
  }

  Rectangle {
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    width: 420
    height: 214
    color: Tokens.paperLift
    border.width: 1
    border.color: Tokens.line
    topRightRadius: 18

    Column {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: 22
      spacing: 18

      Rectangle {
        width: parent.width
        height: 40
        radius: 20
        color: Tokens.tint5
        border.width: 1
        border.color: Tokens.lineSoft

        Text {
          anchors.left: parent.left
          anchors.leftMargin: 16
          anchors.verticalCenter: parent.verticalCenter
          text: "\u2315"
          color: Tokens.inkMuted
          font.pixelSize: 13
        }

        Text {
          anchors.left: parent.left
          anchors.leftMargin: 38
          anchors.verticalCenter: parent.verticalCenter
          text: "Search applications"
          color: Tokens.inkMuted
          font.family: Tokens.ui
          font.pixelSize: Tokens.fSmall
        }

        Rectangle {
          anchors.right: parent.right
          anchors.rightMargin: 10
          anchors.verticalCenter: parent.verticalCenter
          width: 34
          height: 20
          radius: 6
          color: Tokens.tint5

          Text {
            anchors.centerIn: parent
            text: "esc"
            color: Tokens.inkFaint
            font.family: Tokens.ui
            font.pixelSize: Tokens.fTiny
          }
        }
      }

      Row {
        spacing: 14

        Repeater {
          model: root.tiles

          delegate: Item {
            required property var modelData

            width: 56
            height: 64

            Rectangle {
              anchors.horizontalCenter: parent.horizontalCenter
              width: 44
              height: 44
              radius: 12
              color: Tokens.tint10

              Text {
                anchors.centerIn: parent
                text: modelData[0]
                color: Tokens.ink
                font.family: Tokens.ui
                font.pixelSize: 18
                font.weight: Font.DemiBold
              }
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.bottom: parent.bottom
              text: modelData[1]
              color: Tokens.inkDim
              font.family: Tokens.ui
              font.pixelSize: Tokens.fTiny
              elide: Text.ElideRight
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
            }
          }
        }
      }
    }
  }
}
