import QtQuick
import QtQuick.Shapes

Item {
  id: root

  property string corner: "topLeft"

  property real thickness: 5
  property real radius: 16
  property color color: "#ba5f58"
  property string style: "squircle"
  property real squircleFactor: 0.52

  visible: radius > 0

  implicitWidth: Math.max(1.0, radius)
  implicitHeight: thickness + Math.max(1.0, radius)

  readonly property real t: thickness
  readonly property real r: Math.max(1.0, radius)
  readonly property real w: width
  readonly property real h: height
  readonly property real k: Math.min(0.65, Math.max(0.35, squircleFactor))

  Shape {
    id: tlShape
    anchors.fill: parent
    visible: root.corner === "topLeft"
    preferredRendererType: Shape.CurveRenderer
    asynchronous: false

    ShapePath {
      strokeWidth: 0
      strokeColor: "transparent"
      fillColor: root.color
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin

      startX: 0
      startY: 0

      PathLine { x: 0; y: root.h }

      PathCubic {
        x: root.w
        y: root.t
        control1X: 0
        control1Y: root.t + root.r * (1.0 - root.k)
        control2X: root.r * (1.0 - root.k)
        control2Y: root.t
      }

      PathLine { x: root.w; y: 0 }

      PathLine { x: 0; y: 0 }
    }
  }

  Shape {
    id: trShape
    anchors.fill: parent
    visible: root.corner === "topRight"
    preferredRendererType: Shape.CurveRenderer
    asynchronous: false

    ShapePath {
      strokeWidth: 0
      strokeColor: "transparent"
      fillColor: root.color
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin

      startX: root.w
      startY: 0

      PathLine { x: root.w; y: root.h }

      PathCubic {
        x: 0
        y: root.t
        control1X: root.w
        control1Y: root.t + root.r * (1.0 - root.k)
        control2X: root.r * root.k
        control2Y: root.t
      }

      PathLine { x: 0; y: 0 }

      PathLine { x: root.w; y: 0 }
    }
  }

  Shape {
    id: blShape
    anchors.fill: parent
    visible: root.corner === "bottomLeft"
    preferredRendererType: Shape.CurveRenderer
    asynchronous: false

    ShapePath {
      strokeWidth: 0
      strokeColor: "transparent"
      fillColor: root.color
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin

      startX: 0
      startY: root.h

      PathLine { x: 0; y: 0 }

      PathCubic {
        x: root.w
        y: root.r
        control1X: 0
        control1Y: root.r * root.k
        control2X: root.r * (1.0 - root.k)
        control2Y: root.r
      }

      PathLine { x: root.w; y: root.h }

      PathLine { x: 0; y: root.h }
    }
  }

  Shape {
    id: brShape
    anchors.fill: parent
    visible: root.corner === "bottomRight"
    preferredRendererType: Shape.CurveRenderer
    asynchronous: false

    ShapePath {
      strokeWidth: 0
      strokeColor: "transparent"
      fillColor: root.color
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin

      startX: root.w
      startY: root.h

      PathLine { x: root.w; y: 0 }

      PathCubic {
        x: 0
        y: root.r
        control1X: root.w
        control1Y: root.r * root.k
        control2X: root.r * root.k
        control2Y: root.r
      }

      PathLine { x: 0; y: root.h }

      PathLine { x: root.w; y: root.h }
    }
  }
}
