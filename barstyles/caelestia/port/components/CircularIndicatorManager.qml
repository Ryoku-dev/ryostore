import QtQuick

QtObject {
    id: root

    enum IndeterminateAnimationType {
        Advance = 0,
        Retreat = 1
    }

    property int indeterminateAnimationType: CircularIndicatorManager.Advance
    property real progress: 0
    property real completeEndProgress: 0

    readonly property real duration: indeterminateAnimationType === CircularIndicatorManager.Advance ? 5400 : 6000
    readonly property real completeEndDuration: indeterminateAnimationType === CircularIndicatorManager.Advance ? 333 : 500

    readonly property real startFraction: _startFraction
    readonly property real endFraction: _endFraction
    readonly property real rotation: _rotation

    property real _startFraction: 0
    property real _endFraction: 0
    property real _rotation: 0

    function _fractionInRange(playtime: real, start: real, span: real): real {
        return Math.max(0, Math.min(1, (playtime - start) / span));
    }

    // Evaluates cubic-bezier(0.4, 0.0, 0.2, 1.0) with safeguarded Newton-bisection.
    function _ease(x: real): real {
        if (x <= 0)
            return 0;
        if (x >= 1)
            return 1;

        const ax = 1.6;
        const bx = -1.8;
        const cx = 1.2;
        let lo = 0;
        let hi = 1;
        let t = x;

        for (let i = 0; i < 10; ++i) {
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

        return ((-2 * t + 3) * t) * t;
    }

    function _recalculate(): void {
        if (root.indeterminateAnimationType === CircularIndicatorManager.Advance) {
            const playtime = root.progress * 5400;
            const expandDelays = [0, 1350, 2700, 4050];
            const collapseDelays = [667, 2017, 3367, 4717];

            let startDeg = 1520 * root.progress - 20;
            let endDeg = 1520 * root.progress;

            for (let i = 0; i < 4; ++i) {
                endDeg += _ease(_fractionInRange(playtime, expandDelays[i], 667)) * 250;
                startDeg += _ease(_fractionInRange(playtime, collapseDelays[i], 667)) * 250;
            }

            startDeg += (endDeg - startDeg) * root.completeEndProgress;

            root._rotation = 0;
            root._startFraction = startDeg / 360;
            root._endFraction = endDeg / 360;
        } else {
            const playtime = root.progress * 6000;
            const spinDelays = [0, 1500, 3000, 4500];

            let spinRotation = 0;
            for (let i = 0; i < 4; ++i)
                spinRotation += _ease(_fractionInRange(playtime, spinDelays[i], 500)) * 90;

            root._rotation = 1080 * root.progress + spinRotation;
            root._startFraction = 0;

            const frac = _ease(_fractionInRange(playtime, 0, 3000)) - _ease(_fractionInRange(playtime, 3000, 3000));
            let endFrac = 0.10 + (0.87 - 0.10) * frac;
            if (root.completeEndProgress > 0)
                endFrac *= 1 - root.completeEndProgress;

            root._endFraction = endFrac;
        }
    }

    onProgressChanged: _recalculate()
    onCompleteEndProgressChanged: _recalculate()
    onIndeterminateAnimationTypeChanged: _recalculate()
}
