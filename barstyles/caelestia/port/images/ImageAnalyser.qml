import QtQuick

// The dominant colour (most common 5-bit-per-channel colour of the opaque pixels)
// and mean luminance of an image file or an item, read through a Canvas.
Item {
    id: root

    property string source
    property Item sourceItem
    property int rescaleSize: 128
    property color dominantColour: "black"
    property real luminance: 0

    function requestUpdate(): void {
        if (sourceItem) {
            if (sourceItem.width > 0 && sourceItem.height > 0 && sourceItem.visible)
                sourceItem.grabToImage(result => canvas.analyse(result.url), Qt.size(rescaleSize, rescaleSize));
        } else if (source) {
            canvas.analyse(source.startsWith("/") ? "file://" + source : source);
        }
    }

    onSourceChanged: requestUpdate()
    onSourceItemChanged: requestUpdate()

    width: 0
    height: 0

    Canvas {
        id: canvas

        property string pending

        function analyse(url: string): void {
            if (pending)
                unloadImage(pending);
            pending = url;
            if (isImageLoaded(url))
                requestPaint();
            else
                loadImage(url);
        }

        // drawn off-screen: the canvas must stay in the scene to paint
        width: root.rescaleSize
        height: root.rescaleSize
        opacity: 0
        renderTarget: Canvas.Image

        onImageLoaded: requestPaint()
        onPaint: {
            if (!pending || !isImageLoaded(pending))
                return;
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.drawImage(pending, 0, 0, width, height);
            const px = ctx.getImageData(0, 0, width, height).data;
            const counts = {};
            let best = 0, bestCount = 0, lum = 0, n = 0;
            for (let i = 0; i < px.length; i += 4) {
                if (px[i + 3] === 0)
                    continue;
                const key = ((px[i] & 0xF8) << 16) | ((px[i + 1] & 0xF8) << 8) | (px[i + 2] & 0xF8);
                const c = (counts[key] ?? 0) + 1;
                counts[key] = c;
                if (c > bestCount) {
                    best = key;
                    bestCount = c;
                }
                const r = px[i] / 255, g = px[i + 1] / 255, b = px[i + 2] / 255;
                lum += Math.sqrt(0.299 * r * r + 0.587 * g * g + 0.114 * b * b);
                n++;
            }
            root.dominantColour = Qt.rgba((best >> 16 & 0xFF) / 255, (best >> 8 & 0xFF) / 255, (best & 0xFF) / 255, 1);
            root.luminance = n ? lum / n : 0;
        }
    }
}
