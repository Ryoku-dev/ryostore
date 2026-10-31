import QtQuick
import QtQuick.Effects
import Quickshell
import shell.services

Item {
  id: root

  property bool mprisPlaying: false
  property string artUrl: ""
  property color textColor: "#ffffff"
  property color accentColor: "#ffffff"

  readonly property bool showVisualizer: root.mprisPlaying || Media.playing

  Row {
    id: compactRow
    anchors.centerIn: parent
    spacing: 12

    Item {
      id: artSlot
      width: 24
      height: 24
      anchors.verticalCenter: parent.verticalCenter
      visible: root.artUrl.length > 0

      property string artSource: root.artUrl
      property int retriesLeft: 10

      Connections {
        target: root
        function onArtUrlChanged() {
          artSlot.artSource = root.artUrl
          artSlot.retriesLeft = 10
          artRetryTimer.stop()
        }
      }

      Timer {
        id: artRetryTimer
        interval: 250
        repeat: false
        onTriggered: {
          var u = root.artUrl
          artSlot.artSource = ""
          Qt.callLater(function() { artSlot.artSource = u })
        }
      }

      Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Qt.rgba(1, 1, 1, 0.16)
      }

      Image {
        id: artImage
        anchors.fill: parent
        source: artSlot.visible ? artSlot.artSource : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 48
        sourceSize.height: 48
        mipmap: true
        smooth: true
        asynchronous: true
        visible: status === Image.Ready
        layer.enabled: true
        layer.effect: MultiEffect {
          maskEnabled: true
          maskSource: artMask
          maskThresholdMin: 0.5
          maskSpreadAtMin: 0.5
        }

        onStatusChanged: {
          if (status === Image.Error && artSlot.retriesLeft > 0) {
            artSlot.retriesLeft--
            artRetryTimer.restart()
          }
        }
      }

      Item {
        id: artMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Rectangle {
          anchors.fill: parent
          radius: width / 2
          color: "#000000"
        }
      }

      Text {
        anchors.centerIn: parent
        visible: artImage.status !== Image.Ready
        text: "\u{F03C6}"
        font.family: "JetBrainsMono Nerd Font, Font Awesome 7 Free, sans-serif"
        font.pixelSize: 12
        color: root.textColor
        renderType: Text.NativeRendering
      }
    }

    MediaWaveform {
      id: waveform
      anchors.verticalCenter: parent.verticalCenter
      startColor: root.accentColor
      endColor: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.45)
      active: root.showVisualizer
      barCount: 18
      barWidth: 3.5
      barSpacing: 3.5
      maxHeight: 18
    }
  }
}
