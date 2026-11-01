import QtQuick
import shell.services
import "."

Item {
  id: root

  required property var settings
  required property var frameConfig
  property string fontFamily: ""

  signal closeRequested()

  readonly property color plateColor: Theme.surface
  readonly property color textColor: Theme.onSurface
  readonly property color mutedColor: Theme.onSurfaceVariant
  readonly property color accentColor: frameConfig.activeBorderColor

  function set(key, value) {
    if (root.settings) root.settings.update(key, value)
  }

  implicitWidth: 372
  implicitHeight: content.implicitHeight + 40

  property alias cardItem: card

  Rectangle {
    id: card
    anchors.fill: parent
    radius: 18
    color: root.plateColor
    border.width: 1
    border.color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.08)

    Column {
      id: content
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: 20
      spacing: 2

      Item {
        width: parent.width
        height: 40

        Text {
          anchors.left: parent.left
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 10
          text: "Lumania"
          color: root.textColor
          font.family: root.fontFamily
          font.pixelSize: 15
          font.weight: Font.DemiBold
        }

        Text {
          anchors.right: closeButton.left
          anchors.rightMargin: 10
          anchors.verticalCenter: parent.verticalCenter
          text: "Frame"
          color: root.mutedColor
          font.family: root.fontFamily
          font.pixelSize: 11
        }

        Rectangle {
          id: closeButton
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          width: 26
          height: 26
          radius: 13
          color: closeArea.containsMouse
            ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.1)
            : "transparent"

          Text {
            anchors.centerIn: parent
            text: "\u00d7"
            color: root.mutedColor
            font.pixelSize: 16
          }

          MouseArea {
            id: closeArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            onClicked: root.closeRequested()
          }
        }
      }

      SettingSlider {
        width: parent.width
        label: "Border"
        from: 1
        to: 12
        step: 1
        value: root.frameConfig.borderThickness
        suffix: " px"
        fontFamily: root.fontFamily
        textColor: root.textColor
        mutedColor: root.mutedColor
        accentColor: root.accentColor
        onMoved: value => root.set("borderThickness", Math.round(value))
      }

      SettingSlider {
        width: parent.width
        label: "Corner radius"
        from: 0
        to: 32
        step: 1
        value: root.frameConfig.topLeftRadius
        suffix: " px"
        fontFamily: root.fontFamily
        textColor: root.textColor
        mutedColor: root.mutedColor
        accentColor: root.accentColor
        onMoved: value => root.set("radius", Math.round(value))
      }

      SettingSlider {
        width: parent.width
        label: "Island width"
        from: 150
        to: 320
        step: 2
        value: root.frameConfig.islandBodyWidth
        suffix: " px"
        fontFamily: root.fontFamily
        textColor: root.textColor
        mutedColor: root.mutedColor
        accentColor: root.accentColor
        onMoved: value => root.set("islandWidth", Math.round(value))
      }

      SettingSlider {
        width: parent.width
        label: "Wallpaper thumbs"
        from: 3
        to: 7
        step: 1
        value: root.frameConfig.wallpaperMaxVisibleThumbs
        fontFamily: root.fontFamily
        textColor: root.textColor
        mutedColor: root.mutedColor
        accentColor: root.accentColor
        onMoved: value => root.set("wallpaperThumbs", Math.round(value))
      }

      SettingToggle {
        width: parent.width
        label: "Island notifications"
        checked: root.frameConfig.islandNotifications
        fontFamily: root.fontFamily
        textColor: root.textColor
        accentColor: root.accentColor
        onToggled: checked => root.set("islandNotifications", checked)
      }

      SettingToggle {
        width: parent.width
        label: "Reduce motion"
        checked: root.frameConfig.reduceMotion
        fontFamily: root.fontFamily
        textColor: root.textColor
        accentColor: root.accentColor
        onToggled: checked => root.set("reduceMotion", checked)
      }

      Item {
        width: parent.width
        height: 36

        Rectangle {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          width: 66
          height: 24
          radius: 8
          color: resetArea.containsMouse
            ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.12)
            : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.06)

          Text {
            anchors.centerIn: parent
            text: "Reset"
            color: root.mutedColor
            font.family: root.fontFamily
            font.pixelSize: 11
          }

          MouseArea {
            id: resetArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            onClicked: if (root.settings) root.settings.reset()
          }
        }
      }
    }
  }

  Keys.onEscapePressed: root.closeRequested()

  Component.onCompleted: forceActiveFocus()
}
