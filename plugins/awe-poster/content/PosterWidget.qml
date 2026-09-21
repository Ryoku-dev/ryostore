import QtQuick
import QtQuick.Effects
import "."

Item {
    id: root
    implicitWidth: 210
    implicitHeight: 210

    // User customized image/GIF path and shape index
    property string imagePath: ""
    property int shapeIndex: 1

    // ─── Material 3 Organic Shape Profiles ───
    property var shapeNames: [
        "squircle", "arch", "scallop_12", "flower_4",
        "pebble", "pill_v", "circle",
        "pillow", "heart", "stadium_h"
    ]

    function drawShapePath(ctx, shapeType, w, h) {
        var cx = w / 2
        var cy = h / 2
        var r = Math.min(w, h) / 2 - 4

        ctx.beginPath()

        if (shapeType === "circle") {
            ctx.arc(cx, cy, r, 0, Math.PI * 2)
        } else if (shapeType === "squircle") {
            var radius = r * 0.45
            ctx.moveTo(cx - r + radius, cy - r)
            ctx.lineTo(cx + r - radius, cy - r)
            ctx.quadraticCurveTo(cx + r, cy - r, cx + r, cy - r + radius)
            ctx.lineTo(cx + r, cy + r - radius)
            ctx.quadraticCurveTo(cx + r, cy + r, cx + r - radius, cy + r)
            ctx.lineTo(cx - r + radius, cy + r)
            ctx.quadraticCurveTo(cx - r, cy + r, cx - r, cy + r - radius)
            ctx.lineTo(cx - r, cy - r + radius)
            ctx.quadraticCurveTo(cx - r, cy - r, cx - r + radius, cy - r)
        } else if (shapeType === "arch") {
            ctx.moveTo(cx - r, cy + r * 0.9)
            ctx.lineTo(cx + r, cy + r * 0.9)
            ctx.lineTo(cx + r, cy - r * 0.1)
            ctx.arc(cx, cy - r * 0.1, r, 0, Math.PI, true)
            ctx.lineTo(cx - r, cy + r * 0.9)
        } else if (shapeType === "scallop_12") {
            var teeth = 12
            var rInner = r * 0.85
            for (var a = 0; a <= 360; a += 2) {
                var rad = a * Math.PI / 180
                var wave = (Math.cos(teeth * rad) + 1.0) / 2.0
                var radiusVal = rInner + (r - rInner) * wave
                var x = cx + radiusVal * Math.sin(rad)
                var y = cy - radiusVal * Math.cos(rad)
                if (a === 0) ctx.moveTo(x, y)
                else ctx.lineTo(x, y)
            }
        } else if (shapeType === "flower_4") {
            var rIn = r * 0.68
            for (var fl = 0; fl <= 360; fl += 2) {
                var flRad = fl * Math.PI / 180
                var flR = rIn + (r - rIn) * (Math.cos(4 * flRad) + 1.0) / 2.0
                var fx = cx + flR * Math.sin(flRad)
                var fy = cy - flR * Math.cos(flRad)
                if (fl === 0) ctx.moveTo(fx, fy)
                else ctx.lineTo(fx, fy)
            }
        } else if (shapeType === "pebble") {
            ctx.moveTo(cx - r * 0.8, cy - r * 0.5)
            ctx.bezierCurveTo(cx - r, cy - r, cx + r * 0.2, cy - r, cx + r * 0.9, cy - r * 0.4)
            ctx.bezierCurveTo(cx + r * 1.1, cy, cx + r * 0.8, cy + r * 0.9, cx, cy + r)
            ctx.bezierCurveTo(cx - r * 0.9, cy + r * 0.9, cx - r * 1.1, cy, cx - r * 0.8, cy - r * 0.5)
        } else if (shapeType === "pillow") {
            ctx.moveTo(cx, cy - r)
            ctx.quadraticCurveTo(cx + r * 0.8, cy - r * 0.8, cx + r, cy)
            ctx.quadraticCurveTo(cx + r * 0.8, cy + r * 0.8, cx, cy + r)
            ctx.quadraticCurveTo(cx - r * 0.8, cy + r * 0.8, cx - r, cy)
            ctx.quadraticCurveTo(cx - r * 0.8, cy - r * 0.8, cx, cy - r)
        } else if (shapeType === "pill_v") {
            var pvy = r
            var pvx = r * 0.65
            ctx.moveTo(cx - pvx, cy - pvy + pvx)
            ctx.arc(cx, cy - pvy + pvx, pvx, Math.PI, 0, false)
            ctx.lineTo(cx + pvx, cy + pvy - pvx)
            ctx.arc(cx, cy + pvy - pvx, pvx, 0, Math.PI, false)
            ctx.lineTo(cx - pvx, cy - pvy + pvx)
        } else if (shapeType === "stadium_h") {
            var rx = r
            var ry = r * 0.65
            ctx.moveTo(cx - rx + ry, cy - ry)
            ctx.lineTo(cx + rx - ry, cy - ry)
            ctx.arc(cx + rx - ry, cy, ry, -Math.PI / 2, Math.PI / 2)
            ctx.lineTo(cx - rx + ry, cy + ry)
            ctx.arc(cx - rx + ry, cy, ry, Math.PI / 2, 3 * Math.PI / 2)
        } else if (shapeType === "heart") {
            ctx.moveTo(cx, cy + r * 0.75)
            ctx.bezierCurveTo(cx - r * 1.1, cy + r * 0.2, cx - r * 1.1, cy - r * 0.7, cx, cy - r * 0.35)
            ctx.bezierCurveTo(cx + r * 1.1, cy - r * 0.7, cx + r * 1.1, cy + r * 0.2, cx, cy + r * 0.75)
        } else {
            ctx.arc(cx, cy, r, 0, Math.PI * 2)
        }

        ctx.closePath()
    }

    // ─── Scaled Visual Content (PURE ORGANIC SHAPE, ZERO TEXT, GIF SUPPORT) ───
    Item {
        id: scaledContent
        width: 210
        height: 210
        transformOrigin: Item.TopLeft

        // 1. Soft Ambient Drop Shadow Canvas
        Canvas {
            id: shadowCanvas
            anchors.fill: parent
            antialiasing: true

            Connections {
                target: root
                function onShapeIndexChanged() { shadowCanvas.requestPaint() }
            }

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var currentShape = root.shapeNames[root.shapeIndex % root.shapeNames.length]

                ctx.shadowColor = "rgba(0, 0, 0, 0.45)"
                ctx.shadowBlur = 14
                ctx.shadowOffsetX = 0
                ctx.shadowOffsetY = 5
                root.drawShapePath(ctx, currentShape, width, height)
                ctx.fillStyle = "#1E262B"
                ctx.fill()
            }
        }

        // 2. Animated Image / Static Image Element (Supports animated GIFs & static images)
        AnimatedImage {
            id: animImage
            anchors.fill: parent
            source: root.imagePath
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            playing: true
            visible: false
            onStatusChanged: {
                maskCanvas.requestPaint()
            }
        }

        // 3. Shape Mask Canvas for MultiEffect
        Canvas {
            id: maskCanvas
            anchors.fill: parent
            visible: false
            antialiasing: true

            Connections {
                target: root
                function onShapeIndexChanged() {
                    maskCanvas.requestPaint()
                    outlineCanvas.requestPaint()
                    placeholderCanvas.requestPaint()
                }
            }

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var currentShape = root.shapeNames[root.shapeIndex % root.shapeNames.length]
                root.drawShapePath(ctx, currentShape, width, height)
                ctx.fillStyle = "#FFFFFF"
                ctx.fill()
            }
        }

        // 4. MultiEffect: Clips the animated GIF / image to the exact organic shape
        MultiEffect {
            id: maskedEffect
            anchors.fill: parent
            source: animImage
            maskSource: maskCanvas
            maskEnabled: true
            visible: root.imagePath.length > 0 && animImage.status === Image.Ready
            antialiasing: true
        }

        // 5. Material 3 Fallback Placeholder (when no image is loaded)
        Canvas {
            id: placeholderCanvas
            anchors.fill: parent
            visible: root.imagePath.length === 0 || animImage.status !== Image.Ready
            antialiasing: true

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var currentShape = root.shapeNames[root.shapeIndex % root.shapeNames.length]

                // Clip to shape
                ctx.save()
                root.drawShapePath(ctx, currentShape, width, height)
                ctx.clip()

                // Gradient background
                var grad = ctx.createLinearGradient(0, 0, width, height)
                grad.addColorStop(0, Theme.colBgTile)
                grad.addColorStop(1, Theme.colBg)
                ctx.fillStyle = grad
                ctx.fill()

                // Minimalist vector camera / frame graphic (zero text)
                var cx = width / 2
                var cy = height / 2
                ctx.strokeStyle = Theme.colAccentGreen
                ctx.lineWidth = 2
                ctx.strokeRect(cx - 24, cy - 20, 48, 36)

                ctx.beginPath()
                ctx.arc(cx - 10, cy - 10, 4, 0, Math.PI * 2)
                ctx.fillStyle = Theme.colAccentGreen
                ctx.fill()

                ctx.beginPath()
                ctx.moveTo(cx - 20, cy + 12)
                ctx.lineTo(cx - 6, cy - 2)
                ctx.lineTo(cx + 6, cy + 6)
                ctx.lineTo(cx + 20, cy + 12)
                ctx.closePath()
                ctx.fillStyle = Theme.colAccentGreen
                ctx.fill()
                ctx.restore()
            }
        }

        // 6. Smooth Contour Outline on Shape Edge
        Canvas {
            id: outlineCanvas
            anchors.fill: parent
            antialiasing: true

            Connections {
                target: Theme
                function onCurrentThemeChanged() {
                    outlineCanvas.requestPaint()
                    placeholderCanvas.requestPaint()
                }
            }

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var currentShape = root.shapeNames[root.shapeIndex % root.shapeNames.length]
                root.drawShapePath(ctx, currentShape, width, height)
                ctx.strokeStyle = Theme.borderColor
                ctx.lineWidth = Theme.borderWidth
                ctx.stroke()
            }
        }
    }

    // Double-click cycles the display shape (in-memory only); press still falls through for host drag.
    MouseArea {
        anchors.fill: parent
        propagateComposedEvents: true
        onDoubleClicked: (mouse) => {
            root.shapeIndex = (root.shapeIndex + 1) % root.shapeNames.length
            mouse.accepted = false
        }
    }
}
