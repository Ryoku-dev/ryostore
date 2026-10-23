// Adapted from the imi bar style (RyoStore), GPL-3.0.
import QtQuick

Canvas {
    id: root

    enum PathType {
        Linear = 0,
        Arc = 1
    }

    property real lineWidth: 4
    property real amplitudeMultiplier: 0.5
    property real frequency: 6
    property real startX: 0
    property real fullLength: 0
    property color color: "#ffffff"
    property real waveProgress: 0
    property int pathType: WavyLine.Linear
    property real startAngle: 0
    property real fullAngle: 360
    property real radius: -1
    property real value: 1

    onLineWidthChanged: requestPaint()
    onAmplitudeMultiplierChanged: requestPaint()
    onFrequencyChanged: requestPaint()
    onStartXChanged: requestPaint()
    onFullLengthChanged: requestPaint()
    onColorChanged: requestPaint()
    onWaveProgressChanged: requestPaint()
    onPathTypeChanged: requestPaint()
    onStartAngleChanged: requestPaint()
    onFullAngleChanged: requestPaint()
    onRadiusChanged: requestPaint()
    onValueChanged: requestPaint()

    function paintLinear(ctx): void {
        const amplitude = root.lineWidth * root.amplitudeMultiplier;
        const phase = root.waveProgress * 2 * Math.PI;
        const centerY = root.height / 2;
        const len = root.fullLength > 0 ? root.fullLength : 1;
        const start = root.lineWidth / 2;
        const fullEnd = root.width - root.lineWidth / 2;
        const drawEnd = start + (fullEnd - start) * root.value;

        if (drawEnd < start)
            return;

        ctx.beginPath();
        let first = true;
        let lastX = start;
        for (let x = start; x <= drawEnd; x += 1) {
            const theta = root.frequency * 2 * Math.PI * (x + root.startX) / len + phase;
            const waveY = centerY + amplitude * Math.sin(theta);
            if (first) {
                ctx.moveTo(x, waveY);
                first = false;
            } else {
                ctx.lineTo(x, waveY);
            }
            lastX = x;
        }
        if (!first && lastX < drawEnd) {
            const theta = root.frequency * 2 * Math.PI * (drawEnd + root.startX) / len + phase;
            ctx.lineTo(drawEnd, centerY + amplitude * Math.sin(theta));
        }
        if (!first)
            ctx.stroke();
    }

    function paintArc(ctx): void {
        const fullAngleRad = root.fullAngle * Math.PI / 180;
        if (fullAngleRad <= 0)
            return;

        const amplitude = root.lineWidth * root.amplitudeMultiplier;
        const cx = root.width / 2;
        const cy = root.height / 2;
        const rBase = root.radius > 0 ? root.radius : (Math.min(root.width, root.height) - root.lineWidth - 2 * amplitude) / 2;
        if (rBase <= 0)
            return;

        const drawAngleRad = fullAngleRad * root.value;
        if (drawAngleRad <= 0)
            return;

        const startAngleRad = root.startAngle * Math.PI / 180;
        const phase = root.waveProgress * 2 * Math.PI;
        const arcLen = rBase * fullAngleRad;
        const len = root.fullLength > 0 ? root.fullLength : arcLen;
        const steps = Math.max(64, Math.ceil(rBase * drawAngleRad));
        const dTheta = drawAngleRad / steps;

        ctx.beginPath();
        for (let i = 0; i <= steps; ++i) {
            const theta = startAngleRad + i * dTheta;
            const s = i * dTheta * rBase;
            const phi = root.frequency * 2 * Math.PI * (s + root.startX) / len + phase;
            const r = rBase + amplitude * Math.sin(phi);
            const px = cx + r * Math.cos(theta);
            const py = cy + r * Math.sin(theta);
            if (i === 0)
                ctx.moveTo(px, py);
            else
                ctx.lineTo(px, py);
        }
        ctx.stroke();
    }

    onPaint: {
        if (width <= 0 || height <= 0)
            return;

        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);

        // Canvas 2D ignores non-positive lineWidth and keeps the previous stroke width.
        if (root.lineWidth <= 0)
            return;

        ctx.strokeStyle = root.color;
        ctx.lineWidth = root.lineWidth;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";

        if (root.pathType === WavyLine.Arc)
            paintArc(ctx);
        else
            paintLinear(ctx);
    }
}
