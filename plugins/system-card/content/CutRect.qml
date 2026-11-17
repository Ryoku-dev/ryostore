pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

// content/CutRect.qml — the card's shape language: a rectangle with every
// corner cut at `cut`, filled, optionally stroked, children on top. The
// plugin's port of Lithic's CutRect, octagon path only (the card is always
// drawn in the cut language).
Item {
    id: root

    property color fill: "transparent"
    property color strokeColor: "transparent"
    property real strokeWidth: 0
    property real cut: 0
    default property alias content: contentItem.data

    function _bounded(value) {
        return Math.max(0, Math.min(value, Math.min(width, height) / 2));
    }
    function _innerCut(value) {
        return Math.max(0, _bounded(value) - strokeWidth * (2 - Math.SQRT2));
    }

    readonly property var _outer: {
        const tl = _bounded(cut), br = tl, bl = tl, tr = tl;
        return [Qt.point(tl, 0), Qt.point(width - tr, 0), Qt.point(width, tr), Qt.point(width, height - br),
                Qt.point(width - br, height), Qt.point(bl, height), Qt.point(0, height - bl), Qt.point(0, tl),
                Qt.point(tl, 0)];
    }
    readonly property var _inner: {
        const s = strokeWidth;
        const tl = _innerCut(cut);
        return [Qt.point(s + tl, s), Qt.point(width - s - tl, s), Qt.point(width - s, s + tl),
                Qt.point(width - s, height - s - tl), Qt.point(width - s - tl, height - s),
                Qt.point(s + tl, height - s), Qt.point(s, height - s - tl), Qt.point(s, s + tl),
                Qt.point(s + tl, s)];
    }

    Shape {
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.fill
            strokeColor: "transparent"
            PathPolyline { path: root.width > 0 ? root._outer : [] }
        }
        ShapePath {
            fillColor: root.strokeWidth > 0 ? root.strokeColor : "transparent"
            strokeColor: "transparent"
            fillRule: ShapePath.OddEvenFill
            PathMultiline { paths: [root._outer, root._inner] }
        }
    }

    Item {
        id: contentItem
        anchors.fill: parent
    }
}
