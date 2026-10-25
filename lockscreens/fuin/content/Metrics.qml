pragma Singleton

import QtQuick

// Scale as a discrete step set, not a free value: density values scale with
// the step, hairlines do not. The base figures are Jurai's, at `normal`.
QtObject {
    id: root

    readonly property real apsaraHeight: 40
    readonly property real rowHeight: 30
    readonly property real fieldHeight: 40
    readonly property real cellHeight: 30

    readonly property real marginEdge: 12
    readonly property real gapShape: 24
    readonly property real marginNiche: 2

    readonly property real radiusPanel: 20
    readonly property real radiusWell: 10
    readonly property real pillCeiling: 110

    // How round the shell is, as a percentage (theme.conf: radiusPercent).
    readonly property real radiusPercent: Math.max(0, Math.min(100, Config.get("appearance.radius", 100)))

    function shaped(radius) {
        return radius * root.radiusPercent / 100;
    }

    readonly property real blurRadius: 32

    // Hairlines do not take the scale step: a thread is 1.3 px because that
    // is the weight at which it reads as a connection rather than an edge.
    readonly property real thread: 1.3
    readonly property real nodeSize: 2.5
    readonly property real rimWidth: 1
    readonly property int rimMinPhysical: 2

    readonly property var factors: ({
        "compact": 0.85,
        "normal": 1.0,
        "comfortable": 1.15
    })

    function factor(name) {
        return root.factors[name] !== undefined ? root.factors[name] : 1.0;
    }

    // Everything a surface needs at one step.
    function step(name) {
        const f = root.factor(name);
        return {
            "name": root.factors[name] !== undefined ? name : "normal",
            "factor": f,

            "apsaraHeight": root.apsaraHeight * f,
            "rowHeight": root.rowHeight * f,
            "fieldHeight": root.fieldHeight * f,

            "marginEdge": root.marginEdge * f,
            "nichePadding": root.marginNiche * f,
            "gap": root.gapShape * f,

            "radiusPanel": root.shaped(root.radiusPanel * f),
            "radiusWell": root.shaped(root.radiusWell * f),
            "pillCeiling": root.pillCeiling * f,

            "thread": root.thread,
            "nodeSize": root.nodeSize,
            "rimWidth": root.rimWidth,
            "blurRadius": root.blurRadius * f,
            "presenceUnit": root.apsaraHeight * f,

            "fontValue": Math.round(20 * f),
            "fontLabel": Math.round(15 * f),
            "fontSecondary": Math.round(13 * f),
            "fontMeta": Math.round(11 * f),
            "fontTitle": Math.round(14.5 * f)
        };
    }

    // A pill up to the ceiling, the panel radius above it.
    function radiusFor(height, metrics) {
        const m = metrics || root.step("normal");
        return height <= m.pillCeiling ? root.shaped(height / 2) : m.radiusPanel;
    }

    // Concentric by construction.
    function innerRadius(outer, inset) {
        return Math.max(0, outer - inset);
    }

    function snap(logical, devicePixelRatio) {
        const ratio = devicePixelRatio > 0 ? devicePixelRatio : 1;
        return Math.round(logical * ratio) / ratio;
    }

    // Hairlines must land on whole physical pixels, or they blur or vanish.
    function crisp(logical, devicePixelRatio) {
        const ratio = devicePixelRatio > 0 ? devicePixelRatio : 1;
        return Math.max(1, Math.round(logical * ratio)) / ratio;
    }

    // The rim's width at this ratio: never below `rimMinPhysical` pixels.
    function rim(devicePixelRatio) {
        const ratio = devicePixelRatio > 0 ? devicePixelRatio : 1;
        return Math.max(root.rimMinPhysical, Math.round(root.rimWidth * ratio)) / ratio;
    }
}
