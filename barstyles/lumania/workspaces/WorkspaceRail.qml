import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Ryoku.Ui.Singletons

Item {
  id: root

  required property var frameConfig
  property int borderThickness: frameConfig ? frameConfig.borderThickness : 5
  property color notchColor: frameConfig ? frameConfig.activeBorderColor : "#ba5f58"
  property color textColor: frameConfig ? frameConfig.activeTextColor : "#ffffff"
  property color mutedColor: frameConfig ? frameConfig.mutedColor : Qt.rgba(1, 1, 1, 0.6)
  property string fontFamily: "Adwaita Sans, Inter, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif"
  property bool hasOpenApps: false
  property string screenName: ""

  readonly property real topMargin: frameConfig ? frameConfig.workspaceTopMargin : 68
  readonly property int workspaceCount: getWorkspacesList().length
  readonly property real targetWidth: frameConfig ? frameConfig.workspaceWidth : 61

  readonly property real sidePadding: frameConfig ? frameConfig.workspaceSidePadding : 12

  readonly property real itemSize: frameConfig ? frameConfig.workspaceItemSize : 32
  readonly property real itemRadius: frameConfig ? frameConfig.workspaceItemRadius : 10
  readonly property real itemSpacing: frameConfig ? frameConfig.workspaceItemSpacing : 12
  readonly property real railPadding: frameConfig ? frameConfig.workspaceRailPadding : 14

  readonly property real baseHeight: frameConfig ? frameConfig.workspaceHeight : 216

  readonly property real railContentHeight: workspaceCount * itemSize
    + Math.max(0, workspaceCount - 1) * itemSpacing + railPadding * 2
  readonly property real targetHeight: Math.max(baseHeight, railContentHeight)

  readonly property real flareRadius: frameConfig ? frameConfig.workspaceFlareRadius : 8
  readonly property real cornerRadius: frameConfig ? frameConfig.workspaceCornerRadius : 16

  readonly property bool isHovered: Boolean(notchHover && notchHover.hovered) || Boolean(edgeTriggerHover && edgeTriggerHover.hovered)

  readonly property real targetReveal: (!root.hasOpenApps || root.isHovered) ? 1.0 : 0.0
  property real revealProgress: targetReveal

  Behavior on revealProgress {
    NumberAnimation {
      duration: (!root.hasOpenApps || root.isHovered)
        ? (root.frameConfig ? root.frameConfig.workspaceOpenDuration : 340)
        : (root.frameConfig ? root.frameConfig.workspaceCloseDuration : 280)
      easing.type: (!root.hasOpenApps || root.isHovered) ? Easing.OutBack : Easing.OutCubic
      easing.overshoot: (!root.hasOpenApps || root.isHovered)
        ? (root.frameConfig ? root.frameConfig.workspaceOpenOvershoot : 1.08)
        : 1.0
    }
  }

  readonly property real currentWidth: root.borderThickness
    + (revealProgress * (root.targetWidth - root.borderThickness))
    + (Math.sin(Math.min(1.0, Math.max(0.0, revealProgress)) * Math.PI) * 5.0)

  readonly property real currentHeight: root.targetHeight

  property alias maskItem: activeRegionItem

  readonly property var screenWorkspaces: {
    var out = []
    var all = Wm.workspaces || []
    for (var i = 0; i < all.length; i++) {
      var w = all[i]
      if (w.special) continue
      if (root.screenName && w.output && w.output !== root.screenName) continue
      out.push(w)
    }
    return out
  }

  readonly property int activeWorkspaceId: {
    var w = Wm.focusedWorkspace
    var n = w ? parseInt(String(w.name), 10) : 1
    return isNaN(n) ? 1 : n
  }

  function getWorkspacesList() {
    var list = [1, 2, 3, 4, 5]
    for (var i = 0; i < root.screenWorkspaces.length; i++) {
      var n = parseInt(String(root.screenWorkspaces[i].name), 10)
      if (n > 0 && n <= 10 && list.indexOf(n) === -1) list.push(n)
    }
    list.sort(function(a, b) { return a - b })
    return list
  }

  function isWorkspaceOccupied(id) {
    for (var i = 0; i < root.screenWorkspaces.length; i++) {
      var w = root.screenWorkspaces[i]
      if (parseInt(String(w.name), 10) === id) return w.occupied === true
    }
    return false
  }

  function switchToWorkspace(id) {
    for (var i = 0; i < root.screenWorkspaces.length; i++) {
      var w = root.screenWorkspaces[i]
      if (parseInt(String(w.name), 10) === id) {
        Wm.focusWorkspace(w.id)
        return
      }
    }
  }

  property real lastWheelTime: 0
  function handleWheelCycle(angleDeltaY) {
    var now = Date.now()
    if (now - lastWheelTime < 140) return
    lastWheelTime = now
    Wm.cycleWorkspace(angleDeltaY > 0 ? -1 : 1)
  }

  Item {
    id: activeRegionItem
    anchors.left: parent.left
    y: root.topMargin
    width: root.currentWidth + 12
    height: root.currentHeight + 6

    Item {
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: 28

      HoverHandler {
        id: edgeTriggerHover
      }
    }

    Item {
      id: notchContainer
      anchors.left: parent.left
      anchors.top: parent.top
      width: root.currentWidth
      height: root.currentHeight
      transformOrigin: Item.Left
      scale: notchTap.pressed ? 0.96 : 1.0

      Behavior on scale {
        NumberAnimation {
          duration: notchTap.pressed ? 120 : 280
          easing.type: notchTap.pressed ? Easing.OutQuad : Easing.OutBack
          easing.overshoot: 1.15
        }
      }

      HoverHandler {
        id: notchHover
        cursorShape: Qt.PointingHandCursor
      }

      TapHandler {
        id: notchTap
      }

      WheelHandler {
        id: notchWheel
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) {
          root.handleWheelCycle(event.angleDelta.y)
        }
      }

      Shape {
        id: notchShape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        readonly property real w: notchContainer.width
        readonly property real h: notchContainer.height
        readonly property real b: root.borderThickness
        readonly property real rf: root.flareRadius
        readonly property real rc: root.cornerRadius

        readonly property real effRf: Math.min(rf, Math.max(0, (w - b) * 0.35))
        readonly property real effRc: Math.min(rc, Math.max(0, (w - b) - effRf))

        ShapePath {
          strokeWidth: 0
          strokeColor: "transparent"
          fillColor: root.notchColor
          capStyle: ShapePath.RoundCap
          joinStyle: ShapePath.RoundJoin

          startX: -2.0
          startY: 0

          PathLine {
            x: notchShape.b
            y: 0
          }

          PathCubic {
            x: notchShape.b + notchShape.effRf
            y: notchShape.effRf
            control1X: notchShape.b
            control1Y: notchShape.effRf * 0.5
            control2X: notchShape.b + (notchShape.effRf * 0.5)
            control2Y: notchShape.effRf
          }

          PathLine {
            x: notchShape.w - notchShape.effRc
            y: notchShape.effRf
          }

          PathArc {
            x: notchShape.w
            y: notchShape.effRf + notchShape.effRc
            radiusX: Math.max(1, notchShape.effRc)
            radiusY: Math.max(1, notchShape.effRc)
            direction: PathArc.Clockwise
          }

          PathLine {
            x: notchShape.w
            y: Math.max(notchShape.effRf + notchShape.effRc, notchShape.h - notchShape.effRf - notchShape.effRc)
          }

          PathArc {
            x: notchShape.w - notchShape.effRc
            y: notchShape.h - notchShape.effRf
            radiusX: Math.max(1, notchShape.effRc)
            radiusY: Math.max(1, notchShape.effRc)
            direction: PathArc.Clockwise
          }

          PathLine {
            x: notchShape.b + notchShape.effRf
            y: notchShape.h - notchShape.effRf
          }

          PathCubic {
            x: notchShape.b
            y: notchShape.h
            control1X: notchShape.b + (notchShape.effRf * 0.5)
            control1Y: notchShape.h - notchShape.effRf
            control2X: notchShape.b
            control2Y: notchShape.h - (notchShape.effRf * 0.5)
          }

          PathLine {
            x: -2.0
            y: notchShape.h
          }
        }
      }

      Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: notchShape.w > (notchShape.b + 6)

        ShapePath {
          strokeWidth: 1.0
          strokeColor: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.18)
          fillColor: "transparent"
          capStyle: ShapePath.RoundCap
          joinStyle: ShapePath.RoundJoin

          startX: notchShape.b
          startY: 0

          PathCubic {
            x: notchShape.b + notchShape.effRf
            y: notchShape.effRf
            control1X: notchShape.b
            control1Y: notchShape.effRf * 0.5
            control2X: notchShape.b + (notchShape.effRf * 0.5)
            control2Y: notchShape.effRf
          }

          PathLine {
            x: notchShape.w - notchShape.effRc
            y: notchShape.effRf
          }

          PathArc {
            x: notchShape.w - 0.5
            y: notchShape.effRf + notchShape.effRc
            radiusX: Math.max(1, notchShape.effRc)
            radiusY: Math.max(1, notchShape.effRc)
            direction: PathArc.Clockwise
          }

          PathLine {
            x: notchShape.w - 0.5
            y: Math.max(notchShape.effRf + notchShape.effRc, notchShape.h - notchShape.effRf - notchShape.effRc)
          }

          PathArc {
            x: notchShape.w - notchShape.effRc
            y: notchShape.h - notchShape.effRf
            radiusX: Math.max(1, notchShape.effRc)
            radiusY: Math.max(1, notchShape.effRc)
            direction: PathArc.Clockwise
          }

          PathLine {
            x: notchShape.b + notchShape.effRf
            y: notchShape.h - notchShape.effRf
          }

          PathCubic {
            x: notchShape.b
            y: notchShape.h
            control1X: notchShape.b + (notchShape.effRf * 0.5)
            control1Y: notchShape.h - notchShape.effRf
            control2X: notchShape.b
            control2Y: notchShape.h - (notchShape.effRf * 0.5)
          }
        }
      }

      Column {
        id: workspacesColumn
        anchors.verticalCenter: parent.verticalCenter

        x: root.borderThickness + root.sidePadding
        spacing: root.itemSpacing
        opacity: Math.min(1.0, Math.max(0.0, (root.revealProgress - 0.25) * 1.33))
        visible: opacity > 0.01

        Repeater {
          model: root.getWorkspacesList()

          delegate: Item {
            id: wsItem
            required property int modelData

            readonly property bool isCurrent: root.activeWorkspaceId === modelData
            readonly property bool isOccupied: root.isWorkspaceOccupied(modelData)
            readonly property bool isBtnHovered: Boolean(itemHover && itemHover.hovered) && !wsItem.isCurrent
            readonly property bool isBtnPressed: Boolean(itemTap && itemTap.pressed)

            width: root.itemSize
            height: root.itemSize

            scale: isBtnPressed ? 0.94 : (isBtnHovered ? 1.06 : 1.0)
            transformOrigin: Item.Center

            Behavior on scale {
              NumberAnimation {
                duration: wsItem.isBtnPressed ? 110 : 260
                easing.type: wsItem.isBtnPressed ? Easing.OutQuad : Easing.OutBack
                easing.overshoot: 1.2
              }
            }

            Rectangle {
              anchors.fill: parent
              radius: root.itemRadius

              color: wsItem.isCurrent
                ? root.frameConfig.accentColor
                : (wsItem.isBtnHovered ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10) : "transparent")

              Behavior on color {
                ColorAnimation { duration: 160; easing.type: Easing.OutCubic }
              }

              Text {
                anchors.centerIn: parent

                text: String(wsItem.modelData)
                color: wsItem.isCurrent ? root.frameConfig.accentTextColor : root.textColor
                font.family: root.fontFamily
                font.pixelSize: 13
                font.weight: wsItem.isCurrent
                  ? Font.DemiBold
                  : (wsItem.isOccupied ? Font.Medium : Font.Normal)
                opacity: wsItem.isCurrent
                  ? 1.0
                  : (wsItem.isOccupied ? 0.92 : (wsItem.isBtnHovered ? 0.88 : 0.50))

                Behavior on opacity {
                  NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }
              }
            }

            HoverHandler {
              id: itemHover
              cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
              id: itemTap
              onTapped: {
                root.switchToWorkspace(wsItem.modelData)
              }
            }
          }
        }
      }
    }
  }
}
