import QtQuick
import QtQuick.Shapes

// Progress ring (Activity-ring style).
Item {
    id: root
    property real value: 0
    property color color: Theme.accent
    property real thickness: 8
    property color trackColor: Theme.alpha(color, 0.22)
    property real shown: value
    Behavior on shown { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }

    readonly property real rad: Math.min(width, height) / 2 - thickness / 2

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.trackColor
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: root.width / 2; centerY: root.height / 2; radiusX: root.rad; radiusY: root.rad; startAngle: 0; sweepAngle: 360 }
        }
        ShapePath {
            strokeColor: root.color
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2; centerY: root.height / 2; radiusX: root.rad; radiusY: root.rad
                startAngle: -90
                sweepAngle: 360 * Math.max(0.002, Math.min(1, root.shown))
            }
        }
    }
}
