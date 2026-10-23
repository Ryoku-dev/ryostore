import QtQuick
import "material-shapes.js" as Shapes
import "shapes/morph.js" as Morph

// A Material 3 shape that morphs from one shape to the next, in QML: the plugin's
// MaterialShapeItem drawn on a Canvas with the shape library of the imi bar style.
// Setting `shape` animates the morph; fromShape, toShape and morphProgress drive it by hand.
Canvas {
    id: root

    enum Shape {
        Custom = -1,
        Circle,
        Square,
        Slanted,
        Arch,
        Fan,
        Arrow,
        SemiCircle,
        Oval,
        Pill,
        Triangle,
        Diamond,
        ClamShell,
        Pentagon,
        Gem,
        Sunny,
        VerySunny,
        Cookie4Sided,
        Cookie6Sided,
        Cookie7Sided,
        Cookie9Sided,
        Cookie12Sided,
        Ghostish,
        Clover4Leaf,
        Clover8Leaf,
        Burst,
        SoftBurst,
        Boom,
        SoftBoom,
        Flower,
        Puffy,
        PuffyDiamond,
        PixelCircle,
        PixelTriangle,
        Bun,
        Heart
    }

    readonly property list<string> names: ["Circle", "Square", "Slanted", "Arch", "Fan", "Arrow", "SemiCircle", "Oval", "Pill", "Triangle", "Diamond", "ClamShell", "Pentagon", "Gem", "Sunny", "VerySunny", "Cookie4Sided", "Cookie6Sided", "Cookie7Sided", "Cookie9Sided", "Cookie12Sided", "Ghostish", "Clover4Leaf", "Clover8Leaf", "Burst", "SoftBurst", "Boom", "SoftBoom", "Flower", "Puffy", "PuffyDiamond", "PixelCircle", "PixelTriangle", "Bun", "Heart"]

    property int shape: MaterialShape.Circle
    property int fromShape: shape
    property int toShape: shape
    property real morphProgress: 1
    property color color: "black"
    property real implicitSize: 0
    property int animationDuration: 350
    // M3 expressive fast spatial
    property var animationEasing: ({ type: Easing.BezierSpline, bezierCurve: [0.42, 1.67, 0.21, 0.9, 1, 1] })

    property var _morph: null
    property var _points: []
    property int _batchDepth: 0
    property bool _pendingRebuild: false
    property bool _complete: false

    implicitWidth: implicitSize
    implicitHeight: implicitSize

    function polygonFor(s: int): var {
        return Shapes["get" + names[s >= 0 && s < names.length ? s : 0]]();
    }

    function rebuildMorph(): void {
        if (_batchDepth > 0) {
            _pendingRebuild = true;
            return;
        }
        _morph = new Morph.Morph(polygonFor(fromShape), polygonFor(toShape));
        refresh();
    }

    function beginBatchUpdate(): void {
        _batchDepth++;
    }

    function endBatchUpdate(): void {
        if (_batchDepth <= 0)
            return;
        if (--_batchDepth === 0 && _pendingRebuild) {
            _pendingRebuild = false;
            rebuildMorph();
        }
    }

    // the morph's cubics in item coordinates, centred on the item and scaled to its shorter side
    function cubics(): var {
        if (!_morph)
            return [];
        const size = Math.min(width, height), cx = width / 2, cy = height / 2;
        const tx = v => cx + (v - 0.5) * size, ty = v => cy + (v - 0.5) * size;
        return _morph.asCubics(morphProgress).map(c => [tx(c.anchor0X), ty(c.anchor0Y), tx(c.control0X), ty(c.control0Y), tx(c.control1X), ty(c.control1Y), tx(c.anchor1X), ty(c.anchor1Y)]);
    }

    // the outline flattened to points, for the hit and bounds queries
    function refresh(): void {
        const pts = [];
        for (const c of cubics()) {
            for (let i = 0; i <= 8; i++) {
                const t = i / 8, u = 1 - t;
                const a = u * u * u, b = 3 * u * u * t, d = 3 * u * t * t, e = t * t * t;
                pts.push([a * c[0] + b * c[2] + d * c[4] + e * c[6], a * c[1] + b * c[3] + d * c[5] + e * c[7]]);
            }
        }
        _points = pts;
        requestPaint();
    }

    function pathBounds(): rect {
        if (_points.length === 0)
            return Qt.rect(0, 0, 0, 0);
        const xs = _points.map(p => p[0]), ys = _points.map(p => p[1]);
        const x = Math.min(...xs), y = Math.min(...ys);
        return Qt.rect(x, y, Math.max(...xs) - x, Math.max(...ys) - y);
    }

    // distance from the centre to the farthest edge crossing along a ray at the angle
    // (degrees, 0 = up, clockwise), measured in the shape's own unrotated frame
    function distanceAtAngle(angleDegrees: real): real {
        const r = (angleDegrees - rotation) * Math.PI / 180;
        const dx = Math.sin(r), dy = -Math.cos(r), cx = width / 2, cy = height / 2;
        let best = -1;
        for (let i = 0; i + 1 < _points.length; i++) {
            const a = _points[i], b = _points[i + 1];
            const ex = b[0] - a[0], ey = b[1] - a[1];
            const denom = ex * dy - ey * dx;
            if (Math.abs(denom) < 1e-9)
                continue;
            const rx = a[0] - cx, ry = a[1] - cy;
            const t = (ex * ry - ey * rx) / denom, s = (dx * ry - dy * rx) / denom;
            if (t >= 0 && s >= 0 && s <= 1 && t > best)
                best = t;
        }
        return Math.max(0, best);
    }

    onShapeChanged: {
        if (!_complete)
            return;
        anim.stop();
        beginBatchUpdate();
        fromShape = toShape;
        toShape = shape;
        morphProgress = 0;
        endBatchUpdate();
        anim.start();
    }
    onFromShapeChanged: rebuildMorph()
    onToShapeChanged: rebuildMorph()
    onMorphProgressChanged: refresh()
    onWidthChanged: refresh()
    onHeightChanged: refresh()
    onColorChanged: requestPaint()
    Component.onCompleted: {
        _complete = true;
        rebuildMorph();
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const cs = cubics();
        if (cs.length === 0)
            return;
        ctx.fillStyle = color;
        ctx.beginPath();
        ctx.moveTo(cs[0][0], cs[0][1]);
        for (const c of cs)
            ctx.bezierCurveTo(c[2], c[3], c[4], c[5], c[6], c[7]);
        ctx.closePath();
        ctx.fill();
    }

    NumberAnimation {
        id: anim

        target: root
        property: "morphProgress"
        from: 0
        to: 1
        duration: root.animationDuration
        easing: root.animationEasing
    }
}
