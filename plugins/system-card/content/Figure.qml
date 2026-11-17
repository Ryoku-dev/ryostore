pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Ryoku.PluginKit.Singletons

// content/Figure.qml — the card's hero figure, the plugin's port of the hub's
// CardFigure. The stock figure is the bundled photograph (Caracalla, see
// README); the owner's own picture from profile.json's `hero` is framed
// (zoom, focal point, fill or fit), adjusted, and shown as a photo, in mono,
// or as a 1-bit Bayer dither in the card's ink. Moving pictures (GIF/video)
// and gallery figures are left out: a plugin may not reach those surfaces, so
// they fall back to the stock figure here.
Item {
    id: fig

    property var config: ({})
    property string configDir: ""
    property color ink: Theme.bright
    // a figure drawn at another size than its dots asks for soft sampling
    property bool soft: false
    // the card's own art override (settings: Figure picture / Art style);
    // when set it replaces the profile hero entirely
    property string overrideFile: ""
    property string overrideStyle: "photo"

    readonly property bool hasOverride: overrideFile.length > 0
    readonly property string kind: hasOverride ? "custom" : (config.kind || "default")
    readonly property bool stock: !hasOverride && kind !== "custom"
    // the stock photograph is cut to its marble
    readonly property real stockAspect: 665 / 874
    readonly property string src: hasOverride ? overrideFile : (config.source || "")
    readonly property bool customFileOk: hasOverride
        ? true : (kind === "custom" && /^hero\.(png|jpg|jpeg|webp|bmp|avif)$/.test(src))
    readonly property string ownFile: customFileOk
        ? (hasOverride ? overrideFile : configDir + "/profile/" + src) : ""
    readonly property real zoom: hasOverride ? 1 : (config.zoom !== undefined ? config.zoom : 1)
    readonly property real focalX: hasOverride ? 0.5 : (config.focalX !== undefined ? config.focalX : 0.5)
    readonly property real focalY: hasOverride ? 0.4 : (config.focalY !== undefined ? config.focalY : 0.4)
    readonly property string style: hasOverride ? overrideStyle : (config.style || "dither")
    readonly property bool fit: hasOverride ? false : (config.fit === true)
    readonly property real brightness: config.brightness || 0
    readonly property real contrast: config.contrast || 0
    readonly property real saturation: config.saturation || 0
    readonly property bool invert: config.invert === true
    readonly property bool ready: stock ? stockImage.status === Image.Ready
        : customImage.status === Image.Ready || stockImage.status === Image.Ready
    // a picture that never loaded shows the stock figure instead
    readonly property bool showStock: stock || customImage.status === Image.Error

    clip: true

    function fileUrl(path) {
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }

    // the stock photograph, drawn as it is
    Image {
        id: stockImage
        anchors.fill: parent
        visible: fig.showStock
        source: fig.showStock ? Qt.resolvedUrl("../assets/caracalla.png") : ""
        fillMode: Image.PreserveAspectFit
        verticalAlignment: Image.AlignBottom
        smooth: true
        mipmap: true
        asynchronous: true
    }

    // the owner's picture, framed: zoomed about the focal point, filling or
    // fitting the figure
    Image {
        id: customImage
        visible: false
        width: fig.width * fig.zoom
        height: fig.height * fig.zoom
        x: (fig.width - width) * fig.focalX
        y: (fig.height - height) * fig.focalY
        source: fig.customFileOk ? fig.fileUrl(fig.ownFile) : ""
        fillMode: fig.fit ? Image.PreserveAspectFit : Image.PreserveAspectCrop
        sourceSize.width: 1600
        sourceSize.height: 1600
        smooth: true
        mipmap: fig.soft
        asynchronous: true
    }

    // photo and mono: the framed picture with brightness / contrast / colour
    MultiEffect {
        anchors.fill: parent
        visible: !fig.showStock && customImage.status === Image.Ready && fig.style !== "dither"
        source: customImage
        brightness: fig.brightness
        contrast: fig.contrast
        saturation: fig.style === "mono" ? -1 : fig.saturation
    }

    // dither: the picture reduced to ink dots on a 4x4 Bayer grid
    Canvas {
        id: dither
        anchors.fill: parent
        visible: !fig.showStock && fig.style === "dither"
        property int dotCell: 6
        property color ink: fig.ink
        property int frame: 0
        onInkChanged: requestPaint()
        onFrameChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            if (customImage.status !== Image.Ready || customImage.width < 2)
                return;
            ctx.drawImage(customImage, customImage.x, customImage.y,
                customImage.width, customImage.height);
            var d = ctx.getImageData(0, 0, width, height);
            var bayer = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]];
            var cell = dotCell;
            ctx.clearRect(0, 0, width, height);
            ctx.fillStyle = ink;
            for (var gy = 0; gy * cell < height; gy++) {
                for (var gx = 0; gx * cell < width; gx++) {
                    var px = gx * cell + (cell >> 1);
                    var py = gy * cell + (cell >> 1);
                    var i = (py * width + px) * 4;
                    var v = 0.2126 * d.data[i] + 0.7152 * d.data[i + 1]
                        + 0.0722 * d.data[i + 2];
                    v = v + 255 * fig.brightness;
                    v = (v - 128) * (1 + fig.contrast) + 128;
                    if (fig.invert)
                        v = 255 - v;
                    var thr = (bayer[gy % 4][gx % 4] + 0.5) / 16 * 255;
                    if (v > thr)
                        ctx.fillRect(gx * cell, gy * cell, cell - 1, cell - 1);
                }
            }
        }
        Connections {
            target: customImage
            function onStatusChanged() {
                dither.frame++;
            }
        }
    }
}
