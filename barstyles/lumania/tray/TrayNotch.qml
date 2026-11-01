import QtQuick
import QtQuick.Shapes
import Quickshell
import shell.services
import "."

Item {
  id: root

  required property var frameConfig
  property int borderThickness: frameConfig ? frameConfig.borderThickness : 5
  property color notchColor: frameConfig ? frameConfig.activeBorderColor : "#ba5f58"
  property color textColor: frameConfig ? frameConfig.activeTextColor : "#ffffff"
  property color mutedColor: frameConfig ? frameConfig.mutedColor : Qt.rgba(1, 1, 1, 0.6)
  property string fontFamily: Theme.fontPrimary
  property bool hasOpenApps: false

  readonly property real baseHeight: frameConfig ? frameConfig.trayNotchBaseHeight : 37
  readonly property real topCurveRadius: frameConfig ? frameConfig.trayNotchTopCurveRadius : 10
  readonly property real bottomCornerRadius: frameConfig ? frameConfig.trayNotchBottomCornerRadius : 15
  readonly property real itemSize: 26
  readonly property real itemRadius: 7
  readonly property real itemSpacing: 6
  readonly property real sidePadding: 12

  property alias maskItem: activeRegionItem
  property alias wakeItem: edgeTriggerItem

  readonly property var trayList: Tray.items
  readonly property int trayCount: trayList.length

  readonly property bool micMuted: !!(Audio.source && Audio.source.audio && Audio.source.audio.muted)

  function toggleMic() {
    if (Audio.source && Audio.source.audio)
      Audio.source.audio.muted = !Audio.source.audio.muted
  }

  readonly property real micWidth: root.itemSize
  readonly property real dividerWidth: 8
  readonly property real traySectionWidth: trayCount > 0
    ? (trayCount * root.itemSize + (trayCount - 1) * root.itemSpacing)
    : 0

  readonly property real targetNotchWidth: (root.sidePadding * 2)
    + (root.topCurveRadius * 2)
    + root.micWidth
    + (trayCount > 0 ? (root.dividerWidth + root.traySectionWidth) : 0)

  property real animatedWidth: targetNotchWidth
  Behavior on animatedWidth {
    NumberAnimation {
      duration: 260
      easing.type: Easing.OutCubic
    }
  }

  readonly property bool isPointerOver: notchHover.hovered || edgeTriggerHover.hovered
  readonly property bool menuOpen: false
  readonly property real targetReveal: 1.0
  property real revealProgress: targetReveal

  Behavior on revealProgress {
    NumberAnimation {
      duration: (!root.hasOpenApps || root.isPointerOver) ? 340 : 280
      easing.type: (!root.hasOpenApps || root.isPointerOver) ? Easing.OutBack : Easing.OutCubic
      easing.overshoot: (!root.hasOpenApps || root.isPointerOver) ? 1.08 : 1.0
    }
  }

  readonly property real currentHeight: root.borderThickness
    + (revealProgress * (root.baseHeight - root.borderThickness))
    + (Math.sin(Math.min(1.0, Math.max(0.0, revealProgress)) * Math.PI) * 4.0)

  readonly property real effectiveFlare: Math.min(root.topCurveRadius, Math.max(0, (currentHeight - root.borderThickness) * 0.35))
  readonly property real effectiveCorner: Math.min(root.bottomCornerRadius, Math.max(0, (currentHeight - root.borderThickness) - effectiveFlare))

  function openTrayMenu(item, slot) {
    root.menuOpen = true
    trayMenu.openFor(item, slot)
  }

  TrayMenu {
    id: trayMenu
    onClosed: root.menuOpen = false
  }

  Item {
    id: edgeTriggerItem
    anchors.top: parent.top
    anchors.horizontalCenter: notchContainer.horizontalCenter
    width: notchContainer.width
    height: root.borderThickness + 14

    HoverHandler {
      id: edgeTriggerHover
    }
  }

  Item {
    id: activeRegionItem
    anchors.top: notchContainer.top
    anchors.horizontalCenter: notchContainer.horizontalCenter
    width: notchContainer.width + 10
    height: notchContainer.height
  }

  Item {
    id: notchContainer
    anchors.top: parent.top
    anchors.right: parent.right
    width: root.animatedWidth
    height: root.currentHeight
    transformOrigin: Item.Top

    HoverHandler {
      id: notchHover
      cursorShape: Qt.ArrowCursor
    }

    Shape {
      id: notchShape
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer

      readonly property real w: notchContainer.width
      readonly property real h: notchContainer.height
      readonly property real rTop: root.effectiveFlare
      readonly property real rBot: root.effectiveCorner
      readonly property real b: root.borderThickness

      ShapePath {
        strokeWidth: 0
        strokeColor: "transparent"
        fillColor: root.notchColor
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin

        startX: 0
        startY: -2.0

        PathLine {
          x: notchShape.w
          y: -2.0
        }

        PathLine {
          x: notchShape.w
          y: notchShape.b
        }

        PathCubic {
          x: notchShape.w - notchShape.rTop
          y: notchShape.b + notchShape.rTop
          control1X: notchShape.w - (notchShape.rTop * 0.5)
          control1Y: notchShape.b
          control2X: notchShape.w - notchShape.rTop
          control2Y: notchShape.b + (notchShape.rTop * 0.5)
        }

        PathLine {
          x: notchShape.w - notchShape.rTop
          y: Math.max(notchShape.b + notchShape.rTop, notchShape.h - notchShape.rBot)
        }

        PathArc {
          x: notchShape.w - notchShape.rTop - notchShape.rBot
          y: notchShape.h
          radiusX: Math.max(1, notchShape.rBot)
          radiusY: Math.max(1, notchShape.rBot)
          direction: PathArc.Clockwise
        }

        PathLine {
          x: notchShape.rTop + notchShape.rBot
          y: notchShape.h
        }

        PathArc {
          x: notchShape.rTop
          y: Math.max(notchShape.b + notchShape.rTop, notchShape.h - notchShape.rBot)
          radiusX: Math.max(1, notchShape.rBot)
          radiusY: Math.max(1, notchShape.rBot)
          direction: PathArc.Clockwise
        }

        PathLine {
          x: notchShape.rTop
          y: notchShape.b + notchShape.rTop
        }

        PathCubic {
          x: 0
          y: notchShape.b
          control1X: notchShape.rTop
          control1Y: notchShape.b + (notchShape.rTop * 0.5)
          control2X: notchShape.rTop * 0.5
          control2Y: notchShape.b
        }

        PathLine {
          x: 0
          y: -2.0
        }
      }
    }

    Row {
      id: contentRow
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: root.borderThickness / 2
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 6
      opacity: Math.max(0.0, (root.revealProgress - 0.35) / 0.65)
      visible: opacity > 0

      Item {
        id: micBtn
        width: root.itemSize
        height: root.itemSize
        anchors.verticalCenter: parent.verticalCenter

        property bool isHovered: micHover.hovered
        property bool isPressed: micMouse.pressed

        scale: isPressed ? 0.92 : 1.0
        Behavior on scale {
          NumberAnimation {
            duration: micBtn.isPressed ? 110 : 220
            easing.type: Easing.OutQuad
          }
        }

        Rectangle {
          anchors.fill: parent
          radius: root.itemRadius
          color: root.micMuted
            ? Qt.rgba(1.0, 0.35, 0.35, micBtn.isHovered ? 0.35 : 0.22)
            : (micBtn.isHovered ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10) : "transparent")
          Behavior on color { ColorAnimation { duration: 150 } }
        }

        Text {
          anchors.centerIn: parent
          text: root.micMuted ? "\uf131" : "\uf130"
          font.family: Theme.mono
          font.pixelSize: 14
          color: root.micMuted ? "#ff7878" : (micBtn.isHovered ? root.textColor : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.90))
        }

        HoverHandler {
          id: micHover
          cursorShape: Qt.PointingHandCursor
        }

        MouseArea {
          id: micMouse
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton
          cursorShape: Qt.PointingHandCursor
          onClicked: root.toggleMic()
        }
      }

      Rectangle {
        id: separator
        visible: root.trayCount > 0
        anchors.verticalCenter: parent.verticalCenter
        width: 1
        height: 12
        radius: 0.5
        color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.20)
      }

      Row {
        id: trayRow
        visible: root.trayCount > 0
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.itemSpacing

        Repeater {
          model: root.trayList

          delegate: Item {
            id: traySlot
            required property var modelData
            width: root.itemSize
            height: root.itemSize
            anchors.verticalCenter: parent.verticalCenter

            property bool isHovered: itemMouse.containsMouse
            property bool isPressed: itemMouse.pressed

            scale: isPressed ? 0.92 : 1.0
            Behavior on scale {
              NumberAnimation {
                duration: traySlot.isPressed ? 110 : 220
                easing.type: Easing.OutQuad
              }
            }

            Rectangle {
              anchors.fill: parent
              radius: root.itemRadius
              color: traySlot.isHovered ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10) : "transparent"
              Behavior on color { ColorAnimation { duration: 150 } }
            }

            Image {
              id: trayIcon
              anchors.centerIn: parent
              width: 14
              height: 14
              sourceSize: Qt.size(14, 14)
              source: traySlot.modelData.iconPath
                ? "file://" + traySlot.modelData.iconPath
                : Quickshell.iconPath(String(traySlot.modelData.iconName || ""), true)
            }

            Text {
              textFormat: Text.PlainText
              anchors.centerIn: parent
              visible: trayIcon.status !== Image.Ready
              text: (traySlot.modelData.title && traySlot.modelData.title.length > 0)
                ? traySlot.modelData.title.charAt(0).toUpperCase()
                : "\uf02d"
              font.family: root.fontFamily
              font.pixelSize: 10
              font.bold: true
              color: root.textColor
            }

            MouseArea {
              id: itemMouse
              anchors.fill: parent
              acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor

              onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton) {
                  root.openTrayMenu(traySlot.modelData, traySlot)
                } else {
                  const g = traySlot.mapToGlobal(0, traySlot.height)
                  Tray.activate(traySlot.modelData.service, Math.round(g.x), Math.round(g.y))
                }
              }

              onWheel: function(wheel) {
                Tray.scroll(traySlot.modelData.service, wheel.angleDelta.y, false)
              }
            }
          }
        }
      }
    }
  }
}
