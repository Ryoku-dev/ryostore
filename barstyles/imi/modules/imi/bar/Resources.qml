pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import shell.services
import shell.barkit as Pill
import "../../../shared" as Shared
import "../../../popouts" as Popouts
import "../../.."
import "../../common"

Item {
    id: root

    property bool vertical: Config.options.bar.vertical
    property bool isMaterial: Config.options.bar.cornerStyle === 3

    implicitWidth: rings.implicitWidth + (isMaterial ? 16 : 10)
    implicitHeight: vertical ? (rings.implicitHeight + 8) : Appearance.sizes.baseBarHeight
    width: implicitWidth
    height: implicitHeight

    Component.onCompleted: Sysinfo.setActive(root, true)
    Component.onDestruction: Sysinfo.setActive(root, false)

    HoverHandler { id: hh }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: 11
        color: hh.hovered ? Qt.rgba(0, 0, 0, 0.18) : "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    Shared.Popout {
        target: root
        targetHovered: hh.hovered
        preferredWidth: 280
        preferredHeight: 200
        namespace: "ryoku-bar-popout"
        content: Component {
            Popouts.ResourcesPopout {}
        }
    }

    component RingGauge: Item {
        id: gauge

        property real value: 0
        property string glyph: ""

        readonly property real dim: 22
        readonly property real sw: 2.5

        property real anim: 0
        onValueChanged: gauge.anim = Math.max(0, Math.min(1, gauge.value))
        Component.onCompleted: gauge.anim = Math.max(0, Math.min(1, gauge.value))
        Behavior on anim {
            enabled: !Motion.reduce
            NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard }
        }

        implicitWidth: gauge.dim
        implicitHeight: gauge.dim

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.15)
                strokeWidth: gauge.sw
                fillColor: "transparent"
                PathAngleArc {
                    centerX: gauge.dim / 2
                    centerY: gauge.dim / 2
                    radiusX: gauge.dim / 2 - gauge.sw / 2
                    radiusY: gauge.dim / 2 - gauge.sw / 2
                    startAngle: -90
                    sweepAngle: 360
                }
            }

            ShapePath {
                strokeColor: Theme.primary
                strokeWidth: gauge.sw
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: gauge.dim / 2
                    centerY: gauge.dim / 2
                    radiusX: gauge.dim / 2 - gauge.sw / 2
                    radiusY: gauge.dim / 2 - gauge.sw / 2
                    startAngle: -90
                    sweepAngle: Math.max(1, gauge.anim * 360)
                }
            }
        }

        Pill.MaterialIcon {
            anchors.centerIn: parent
            text: gauge.glyph
            color: Theme.onSurfaceVariant
            font.pixelSize: 11
        }
    }

    Row {
        id: rings
        anchors.centerIn: parent
        spacing: 8

        RingGauge { value: Sysinfo.cpu; glyph: "memory" }
        RingGauge { value: Sysinfo.mem; glyph: "memory_alt" }
    }
}
