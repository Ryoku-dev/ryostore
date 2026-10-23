import QtQuick

QtObject {
    id: root

    property real progress: 0
    property real completeEndProgress: 0
    property int gap: 4

    readonly property real duration: 1800
    readonly property real completeEndDuration: 1800

    readonly property list<LinearIndicatorSegment> activeIndicators: [
        LinearIndicatorSegment {
            gapSize: root.gap
            startFraction: root._evalEnd(0, root.progress)
            endFraction: root._evalEnd(1, root.progress)
        },
        LinearIndicatorSegment {
            gapSize: root.gap
            startFraction: root._evalEnd(2, root.progress)
            endFraction: root._evalEnd(3, root.progress)
        }
    ]

    signal updated()

    function _cubicBezier(x1: real, y1: real, x2: real, y2: real, x: real): real {
        if (x <= 0)
            return 0;
        if (x >= 1)
            return 1;

        const ax = 1 - 3 * x2 + 3 * x1;
        const bx = 3 * x2 - 6 * x1;
        const cx = 3 * x1;
        const ay = 1 - 3 * y2 + 3 * y1;
        const by = 3 * y2 - 6 * y1;
        const cy = 3 * y1;

        let lo = 0;
        let hi = 1;
        let t = x;

        for (let i = 0; i < 12; ++i) {
            const err = ((ax * t + bx) * t + cx) * t - x;
            if (Math.abs(err) < 1e-7)
                break;
            if (err < 0)
                lo = t;
            else
                hi = t;
            const dx = (3 * ax * t + 2 * bx) * t + cx;
            const next = Math.abs(dx) > 1e-6 ? t - err / dx : 0.5 * (lo + hi);
            t = next > lo && next < hi ? next : 0.5 * (lo + hi);
        }

        return ((ay * t + by) * t + cy) * t;
    }

    function _evalEnd(idx: int, prog: real): real {
        const delays = [1267, 1000, 333, 0];
        const durations = [533, 567, 850, 750];
        const curves = [
            [0.2, 0.0, 0.8, 1.0],
            [0.4, 0.0, 1.0, 1.0],
            [0.0, 0.0, 0.65, 1.0],
            [0.1, 0.0, 0.45, 1.0]
        ];
        const playtime = prog * 1800;
        const frac = Math.max(0, Math.min(1, (playtime - delays[idx]) / durations[idx]));
        const c = curves[idx];
        return Math.max(0, Math.min(1, _cubicBezier(c[0], c[1], c[2], c[3], frac)));
    }

    function _notifyUpdated(): void {
        activeIndicators[0].updated();
        activeIndicators[1].updated();
        updated();
    }

    onProgressChanged: _notifyUpdated()
    onCompleteEndProgressChanged: _notifyUpdated()
    onGapChanged: _notifyUpdated()
}
