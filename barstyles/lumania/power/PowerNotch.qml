import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import shell.services

Item {
  id: root

  required property var frameConfig
  property int borderThickness: frameConfig ? frameConfig.borderThickness : 5
  property color notchColor: frameConfig ? frameConfig.activeBorderColor : "#ba5f58"
  property color textColor: frameConfig ? frameConfig.activeTextColor : "#ffffff"
  property color mutedColor: frameConfig ? frameConfig.mutedColor : Qt.rgba(1, 1, 1, 0.6)
  property string fontFamily: "Adwaita Sans, Inter, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif"
  property bool hasOpenApps: false

  readonly property real baseHeight: frameConfig ? frameConfig.trayNotchBaseHeight : 37
  readonly property real topCurveRadius: frameConfig ? frameConfig.trayNotchTopCurveRadius : 10
  readonly property real bottomCornerRadius: frameConfig ? frameConfig.trayNotchBottomCornerRadius : 15
  readonly property real itemSize: 26
  readonly property real itemRadius: 7
  readonly property real itemSpacing: 6
  readonly property real sidePadding: 12

  readonly property string iconFont: "JetBrainsMono Nerd Font, Font Awesome 7 Free, sans-serif"

  property alias maskItem: activeRegionItem
  property alias wakeItem: edgeTriggerItem

  readonly property var sessionActions: [
    { id: "lock", glyph: "\uf023", label: "Lock", hoverBg: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10) },
    { id: "logout", glyph: "\uF08B", label: "Log out", hoverBg: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10) },
    { id: "suspend", glyph: "\uF186", label: "Suspend", hoverBg: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10) }
  ]

  readonly property var powerActions: [
    { id: "reboot", glyph: "\uF021", label: "Restart", hoverBg: Qt.rgba(245, 175, 45, 0.28) },
    { id: "shutdown", glyph: "\uF011", label: "Power off", hoverBg: Qt.rgba(235, 75, 75, 0.32) }
  ]

  function runPowerAction(action) {
    if (!action) return
    SessionActions.run(action)
  }

  readonly property int sessionCount: sessionActions.length
  readonly property int powerCount: powerActions.length
  readonly property real sessionSectionWidth: sessionCount * itemSize + Math.max(0, sessionCount - 1) * itemSpacing
  readonly property real powerSectionWidth: powerCount * itemSize + Math.max(0, powerCount - 1) * itemSpacing
  readonly property real dividerWidth: 8

  readonly property real targetNotchWidth: (sidePadding * 2)
    + (topCurveRadius * 2)
    + sessionSectionWidth
    + dividerWidth
    + powerSectionWidth

  property real animatedWidth: targetNotchWidth
  Behavior on animatedWidth {
    NumberAnimation {
      duration: 260
      easing.type: Easing.OutCubic
    }
  }

  readonly property bool isPointerOver: notchHover.hovered || edgeTriggerHover.hovered

  readonly property real targetReveal: (!root.hasOpenApps || root.isPointerOver) ? 1.0 : 0.0
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
    anchors.left: parent.left
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
      spacing: root.itemSpacing
      opacity: Math.max(0.0, (root.revealProgress - 0.35) / 0.65)
      visible: opacity > 0

      Repeater {
        model: root.sessionActions

        delegate: Item {
          id: sessionBtn
          width: root.itemSize
          height: root.itemSize
          anchors.verticalCenter: parent.verticalCenter

          property bool isHovered: sessionHover.hovered
          property bool isPressed: sessionTap.pressed

          scale: isPressed ? 0.92 : 1.0
          Behavior on scale {
            NumberAnimation {
              duration: sessionBtn.isPressed ? 110 : 220
              easing.type: sessionBtn.isPressed ? Easing.OutQuad : Easing.OutBack
              easing.overshoot: 1.15
            }
          }

          Rectangle {
            anchors.fill: parent
            radius: root.itemRadius
            color: sessionBtn.isHovered ? modelData.hoverBg : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }
          }

          Text {
            anchors.centerIn: parent
            text: modelData.glyph
            font.family: root.iconFont
            font.pixelSize: 14
            color: sessionBtn.isHovered ? root.textColor : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.88)
            renderType: Text.NativeRendering
          }

          HoverHandler {
            id: sessionHover
            cursorShape: Qt.PointingHandCursor
          }

          TapHandler {
            id: sessionTap
            onTapped: root.runPowerAction(modelData.id)
          }
        }
      }

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 1
        height: 12
        radius: 0.5
        color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.20)
      }

      Repeater {
        model: root.powerActions

        delegate: Item {
          id: powerBtn
          width: root.itemSize
          height: root.itemSize
          anchors.verticalCenter: parent.verticalCenter

          property bool isHovered: powerHover.hovered
          property bool isPressed: powerTap.pressed

          scale: isPressed ? 0.92 : 1.0
          Behavior on scale {
            NumberAnimation {
              duration: powerBtn.isPressed ? 110 : 220
              easing.type: powerBtn.isPressed ? Easing.OutQuad : Easing.OutBack
              easing.overshoot: 1.15
            }
          }

          Rectangle {
            anchors.fill: parent
            radius: root.itemRadius
            color: powerBtn.isHovered ? modelData.hoverBg : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }
          }

          Text {
            anchors.centerIn: parent
            text: modelData.glyph
            font.family: root.iconFont
            font.pixelSize: 14
            color: powerBtn.isHovered ? root.textColor : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.88)
            renderType: Text.NativeRendering
          }

          HoverHandler {
            id: powerHover
            cursorShape: Qt.PointingHandCursor
          }

          TapHandler {
            id: powerTap
            onTapped: root.runPowerAction(modelData.id)
          }
        }
      }
    }
  }
}
