import QtQuick

Canvas {
    id: root

    property var line1: null
    property var line2: null
    property color line1Color: "transparent"
    property color line2Color: "transparent"
    property real line1FillAlpha: 0.15
    property real line2FillAlpha: 0.2
    property real maxValue: 1024.0
    property real slideProgress: 0.0
    property int historyLength: 30
    property real lineWidth: 2.0

    clip: true

    onLine1Changed: requestPaint()
    onLine2Changed: requestPaint()
    onLine1ColorChanged: requestPaint()
    onLine2ColorChanged: requestPaint()
    onLine1FillAlphaChanged: requestPaint()
    onLine2FillAlphaChanged: requestPaint()
    onMaxValueChanged: requestPaint()
    onSlideProgressChanged: requestPaint()
    onHistoryLengthChanged: requestPaint()
    onLineWidthChanged: requestPaint()

    Connections {
        target: root.line1 && !Array.isArray(root.line1) ? root.line1 : null
        ignoreUnknownSignals: true

        function onValuesChanged(): void {
            root.requestPaint();
        }
    }

    Connections {
        target: root.line2 && !Array.isArray(root.line2) ? root.line2 : null
        ignoreUnknownSignals: true

        function onValuesChanged(): void {
            root.requestPaint();
        }
    }

    function _readValues(buf): var {
        if (!buf)
            return [];
        if (Array.isArray(buf))
            return buf;
        if (typeof buf.at === "function" && typeof buf.count === "number") {
            const n = buf.count;
            const out = new Array(n);
            for (let i = 0; i < n; ++i)
                out[i] = buf.at(i);
            return out;
        }
        if (buf.values !== undefined && buf.values !== null)
            return buf.values;
        return [];
    }

    function _drawLine(ctx, vals, lineColor: color, fillAlpha: real): void {
        if (root.historyLength < 2 || vals.length < 2)
            return;

        const w = root.width;
        const h = root.height;
        const len = vals.length;
        const maxVal = root.maxValue > 0 ? root.maxValue : 1;
        const stepX = w / (root.historyLength - 1);
        const startX = w - (len - 1) * stepX - stepX * root.slideProgress + stepX;

        ctx.beginPath();
        ctx.moveTo(startX, h - (vals[0] / maxVal) * h);
        for (let i = 1; i < len; ++i) {
            const x = startX + i * stepX;
            const y = h - (vals[i] / maxVal) * h;
            ctx.lineTo(x, y);
        }

        if (root.lineWidth > 0) {
            ctx.strokeStyle = lineColor;
            ctx.lineWidth = root.lineWidth;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            ctx.stroke();
        }

        ctx.lineTo(startX + (len - 1) * stepX, h);
        ctx.lineTo(startX, h);
        ctx.closePath();
        ctx.fillStyle = Qt.alpha(lineColor, fillAlpha);
        ctx.fill();
    }

    onPaint: {
        if (width <= 0 || height <= 0)
            return;

        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);

        const vals1 = _readValues(root.line1);
        const vals2 = _readValues(root.line2);

        if (vals1.length >= 2)
            _drawLine(ctx, vals1, root.line1Color, root.line1FillAlpha);
        if (vals2.length >= 2)
            _drawLine(ctx, vals2, root.line2Color, root.line2FillAlpha);
    }
}
