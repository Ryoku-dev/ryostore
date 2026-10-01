import QtQuick

Canvas {
    id: icon
    property string kind: "network"
    property color ink: "#FFFFFF"
    property color accent: "#C8102E"
    property int level: 100
    property bool charging: false
    implicitWidth: 20
    implicitHeight: 20
    onKindChanged: requestPaint()
    onInkChanged: requestPaint()
    onAccentChanged: requestPaint()
    onLevelChanged: requestPaint()
    onChargingChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const c = getContext("2d")
        c.clearRect(0, 0, width, height)
        c.save()
        c.scale(width / 24, height / 24)
        c.strokeStyle = icon.ink
        c.fillStyle = icon.ink
        c.lineWidth = 1.7
        c.lineCap = "square"
        c.lineJoin = "miter"

        if (kind === "network") {
            c.beginPath(); c.arc(12, 16, 10, Math.PI * 1.2, Math.PI * 1.8); c.stroke()
            c.beginPath(); c.arc(12, 16, 6, Math.PI * 1.2, Math.PI * 1.8); c.stroke()
            c.beginPath(); c.arc(12, 16, 2, 0, 2 * Math.PI); c.fill()
        } else if (kind === "audio") {
            c.beginPath(); c.moveTo(3, 9); c.lineTo(7, 9); c.lineTo(11, 5)
            c.lineTo(11, 19); c.lineTo(7, 15); c.lineTo(3, 15); c.closePath(); c.stroke()
            c.beginPath(); c.arc(11, 12, 5, -0.75, 0.75); c.stroke()
            c.beginPath(); c.arc(11, 12, 9, -0.75, 0.75); c.stroke()
        } else if (kind === "battery") {
            c.strokeRect(2.5, 7, 17, 10)
            c.fillRect(20.5, 10, 1.5, 4)
            c.fillStyle = level <= 20 ? icon.accent : icon.ink
            c.fillRect(5, 9.5, Math.max(0, 12 * Math.min(100, level) / 100), 5)
        } else if (kind === "charge") {
            c.beginPath()
            c.moveTo(13, 2); c.lineTo(7, 13); c.lineTo(12, 12)
            c.lineTo(10, 22); c.lineTo(18, 10); c.lineTo(13, 11)
            c.closePath(); c.fill()
        } else if (kind === "cpu") {
            c.strokeRect(6, 6, 12, 12)
            for (let i = 8; i <= 16; i += 4) {
                c.beginPath(); c.moveTo(i, 2); c.lineTo(i, 6)
                c.moveTo(i, 18); c.lineTo(i, 22); c.stroke()
                c.beginPath(); c.moveTo(2, i); c.lineTo(6, i)
                c.moveTo(18, i); c.lineTo(22, i); c.stroke()
            }
            c.fillRect(10, 10, 4, 4)
        } else if (kind === "memory") {
            c.strokeRect(3, 7, 18, 11)
            c.fillRect(6, 10, 2, 5); c.fillRect(11, 10, 2, 5); c.fillRect(16, 10, 2, 5)
            for (let x = 6; x <= 18; x += 4) {
                c.beginPath(); c.moveTo(x, 18); c.lineTo(x, 21); c.stroke()
            }
        } else if (kind === "music") {
            c.beginPath(); c.moveTo(10, 17); c.lineTo(10, 5); c.lineTo(19, 3)
            c.lineTo(19, 15); c.stroke()
            c.beginPath(); c.arc(7, 18, 2.5, 0, 2 * Math.PI); c.fill()
            c.beginPath(); c.arc(16, 16, 2.5, 0, 2 * Math.PI); c.fill()
        } else if (kind === "calendar") {
            c.strokeRect(3, 5, 18, 16)
            c.beginPath(); c.moveTo(3, 10); c.lineTo(21, 10)
            c.moveTo(8, 2); c.lineTo(8, 7); c.moveTo(16, 2); c.lineTo(16, 7); c.stroke()
            c.fillRect(7, 13, 2, 2); c.fillRect(11, 13, 2, 2); c.fillRect(15, 13, 2, 2)
        }
        c.restore()
    }
}
