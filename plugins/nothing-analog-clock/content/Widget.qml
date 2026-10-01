import QtQuick

Item {
    id: root
    property var pluginApi
    property var screen
    property bool active: false
    property string density: "compact"
    property real s: 1
    property real widthBudget: 0

    // Two cells on the Nothing Interface desktop grid (120px cells, 16px gap).
    implicitWidth: 256 * s
    implicitHeight: 256 * s
    width: implicitWidth
    height: implicitHeight

    Canvas {
        id: dial
        width: 236 * root.s
        height: 236 * root.s
        anchors.centerIn: parent
        antialiasing: true
        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.save()
            ctx.scale(root.s, root.s)
            const cx = 118, cy = 118
            ctx.beginPath()
            ctx.arc(cx, cy, 115, 0, Math.PI * 2)
            ctx.fillStyle = "#1C1D21"
            ctx.fill()

            for (let i = 0; i < 60; i++) {
                const a = i * Math.PI / 30 - Math.PI / 2
                const major = i % 5 === 0
                const inner = major ? 91 : 99
                const outer = 108
                ctx.beginPath()
                ctx.moveTo(cx + Math.cos(a) * inner, cy + Math.sin(a) * inner)
                ctx.lineTo(cx + Math.cos(a) * outer, cy + Math.sin(a) * outer)
                ctx.strokeStyle = major ? "#F5F5F5" : "#DCD7D2"
                ctx.lineWidth = major ? 3 : 1.4
                ctx.lineCap = "round"
                ctx.stroke()
            }

            const now = new Date()
            const second = now.getSeconds() + now.getMilliseconds() / 1000
            const minute = now.getMinutes() + second / 60
            const hour = (now.getHours() % 12) + minute / 60
            function hand(value, divisions, length, width, color, tail) {
                const a = value * Math.PI * 2 / divisions - Math.PI / 2
                ctx.beginPath()
                ctx.moveTo(cx - Math.cos(a) * tail, cy - Math.sin(a) * tail)
                ctx.lineTo(cx + Math.cos(a) * length, cy + Math.sin(a) * length)
                ctx.strokeStyle = color
                ctx.lineWidth = width
                ctx.lineCap = "round"
                ctx.stroke()
                return a
            }
            hand(hour, 12, 56, 5, "#F5F5F5", 8)
            hand(minute, 60, 78, 4, "#F5F5F5", 10)
            const secondAngle = hand(second, 60, 91, 2, "#C8102E", 16)
            ctx.beginPath()
            ctx.arc(cx + Math.cos(secondAngle) * 82,
                    cy + Math.sin(secondAngle) * 82, 6, 0, Math.PI * 2)
            ctx.fillStyle = "#C8102E"
            ctx.fill()
            ctx.beginPath()
            ctx.arc(cx, cy, 5.5, 0, Math.PI * 2)
            ctx.fillStyle = "#F5F5F5"
            ctx.fill()
            ctx.beginPath()
            ctx.arc(cx, cy, 2.6, 0, Math.PI * 2)
            ctx.fillStyle = "#C8102E"
            ctx.fill()
            ctx.restore()
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: dial.requestPaint()
    }
}
