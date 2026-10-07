import QtQuick

Item {
    id: root
    property var pluginApi
    property var screen
    property bool active: false
    property string density: "compact"
    property real s: 1
    property real widthBudget: 0
    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property bool muted: service ? service.data.muted === true : false
    readonly property int volume: service ? Number(service.data.volume ?? 0) : 0

    implicitWidth: 120 * s
    implicitHeight: 120 * s
    width: implicitWidth
    height: implicitHeight
    onMutedChanged: wave.requestPaint()

    Canvas {
        id: wave
        width: 108 * root.s
        height: 108 * root.s
        anchors.centerIn: parent
        antialiasing: true
        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.save()
            ctx.scale(root.s, root.s)
            ctx.beginPath()
            ctx.arc(54, 54, 54, 0, Math.PI * 2)
            ctx.fillStyle = "#1C1D21"
            ctx.fill()
            ctx.fillStyle = root.muted ? "#B1B3B3" : "#F5F5F5"
            const heights = [5, 13, 26, 40, 53, 40, 26, 13, 5]
            for (let i = 0; i < heights.length; i++) {
                const x = 26 + i * 7
                const h = heights[i]
                ctx.beginPath()
                ctx.rect(x, (108 - h) / 2, 3.6, h)
                ctx.fill()
            }
            if (root.muted) {
                ctx.beginPath()
                ctx.moveTo(29, 77)
                ctx.lineTo(79, 29)
                ctx.strokeStyle = "#B1B3B3"
                ctx.lineWidth = 3
                ctx.stroke()
            }
            ctx.restore()
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.service) root.service.toggleMute()
    }
}
