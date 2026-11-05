import QtQuick
import QtQuick.Shapes
import Quickshell

Item {
  id: root

  required property var frameConfig
  property int borderThickness: frameConfig.borderThickness
  property color notchColor: frameConfig.activeBorderColor
  property bool hasOpenApps: false
  property bool active: false

  readonly property real collapsedWidth: frameConfig.searchCollapsedWidth
  readonly property real collapsedHeight: borderThickness
    + Math.max(frameConfig.searchCollapsedHeight, frameConfig.searchLeftTabHeight)

  // Slides the lip under the frame while a window is open, and lifts it back
  // when the corner is touched.
  property real retractOffset: (root.hasOpenApps && !root.active)
    ? -(root.collapsedHeight - root.borderThickness) : 0

  Behavior on retractOffset {
    NumberAnimation {
      duration: root.retractOffset < 0 ? 280 : 380
      easing.type: root.retractOffset < 0 ? Easing.OutCubic : Easing.OutBack
      easing.overshoot: 1.08
    }
  }

  property alias maskItem: shapeHost
  property alias wakeItem: edgeTrigger

  signal activateRequested()
  signal settingsRequested()

  width: root.collapsedWidth
  height: root.collapsedHeight

  Item {
    id: shapeHost
    width: root.width
    height: root.height
    y: -root.retractOffset

    HoverHandler {
      cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
      onTapped: root.activateRequested()
    }

    TapHandler {
      acceptedButtons: Qt.RightButton
      onTapped: root.settingsRequested()
    }

    Shape {
      id: gusset
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer

      readonly property real w: gusset.width
      readonly property real h: gusset.height
      readonly property real b: root.borderThickness
      readonly property real stripTop: h - b - root.frameConfig.searchCollapsedHeight
      readonly property real tabW: Math.max(2, Math.min(root.frameConfig.searchLeftTabWidth,
        w * root.frameConfig.searchTabWidthMaxRatio))
      readonly property real tabTop: Math.max(0, h - b - root.frameConfig.searchLeftTabHeight)
      readonly property real rTab: Math.max(0, Math.min(root.frameConfig.searchTabCapRadius,
        tabW * 0.5, (stripTop - tabTop) * 0.45))
      readonly property real fillet: Math.max(0, Math.min(root.frameConfig.searchInnerRadius,
        stripTop - tabTop))
      readonly property real rCorner: Math.max(0, Math.min(root.frameConfig.searchCornerRadius,
        (h - stripTop) * root.frameConfig.searchLipCornerRatio))
      readonly property real stripEnd: Math.max(tabW + fillet + 1, w - rCorner)
      readonly property real slack: 1.0 - root.frameConfig.searchCurveTension

      ShapePath {
        strokeWidth: 0
        strokeColor: "transparent"
        fillColor: root.notchColor
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin

        startX: 0
        startY: gusset.h + 2.0

        PathLine {
          x: 0
          y: gusset.tabTop + gusset.rTab
        }

        PathCubic {
          x: gusset.tabW
          y: gusset.tabTop + gusset.rTab
          control1X: 0
          control1Y: gusset.tabTop
          control2X: gusset.tabW
          control2Y: gusset.tabTop
        }

        PathLine {
          x: gusset.tabW
          y: gusset.stripTop - gusset.fillet
        }

        PathCubic {
          x: gusset.tabW + gusset.fillet
          y: gusset.stripTop
          control1X: gusset.tabW
          control1Y: gusset.stripTop - gusset.fillet * gusset.slack
          control2X: gusset.tabW + gusset.fillet * gusset.slack
          control2Y: gusset.stripTop
        }

        PathLine {
          x: gusset.stripEnd
          y: gusset.stripTop
        }

        PathArc {
          x: gusset.w
          y: gusset.stripTop + gusset.rCorner
          radiusX: gusset.rCorner
          radiusY: gusset.rCorner
          direction: PathArc.Clockwise
        }

        PathLine {
          x: gusset.w
          y: gusset.h + 2.0
        }

        PathLine {
          x: 0
          y: gusset.h + 2.0
        }
      }
    }
  }

  Item {
    id: edgeTrigger
    x: 0
    y: root.height - height + root.retractOffset
    width: Math.max(64, root.collapsedWidth)
    height: root.borderThickness + 14

    HoverHandler {
      cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
      onTapped: root.activateRequested()
    }
  }
}
