import QtQuick

Rectangle {
    id: root
    property var pluginApi
    property var screen
    property bool active: false
    property string density: "compact"
    property real s: 1
    property real widthBudget: 0
    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property var state: service ? service.data : ({})
    readonly property int level: Number(state.level ?? -1)
    readonly property bool charging: state.charging === true
    readonly property bool plugged: state.plugged === true

    implicitWidth: 256 * s
    implicitHeight: 256 * s
    width: implicitWidth
    height: implicitHeight
    radius: 32 * s
    color: "#1C1D21"
    onLevelChanged: ring.requestPaint()

    Canvas {
        id: ring
        x: 17 * root.s
        y: 17 * root.s
        width: 112 * root.s
        height: 112 * root.s
        antialiasing: true
        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.save()
            ctx.scale(root.s, root.s)
            ctx.beginPath()
            ctx.arc(56, 56, 55, 0, Math.PI * 2)
            ctx.fillStyle = "#303136"
            ctx.fill()
            ctx.beginPath()
            ctx.arc(56, 56, 48, 0, Math.PI * 2)
            ctx.strokeStyle = "#44454A"
            ctx.lineWidth = 5
            ctx.stroke()
            if (root.level >= 0) {
                ctx.beginPath()
                ctx.arc(56, 56, 48, -Math.PI / 2,
                        -Math.PI / 2 + Math.PI * 2 * root.level / 100)
                ctx.strokeStyle = root.level <= 15 ? "#C8102E" : "#DCD7D2"
                ctx.lineWidth = 5
                ctx.lineCap = "round"
                ctx.stroke()
            }
            ctx.strokeStyle = "#F5F5F5"
            ctx.lineWidth = 3
            ctx.lineJoin = "round"
            ctx.beginPath()
            ctx.rect(37, 38, 38, 28)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(33, 72)
            ctx.lineTo(79, 72)
            ctx.stroke()
            ctx.restore()
        }
    }

    Canvas {
        visible: root.plugged
        x: 139 * root.s
        y: 42 * root.s
        width: 24 * root.s
        height: 32 * root.s
        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.save()
            ctx.scale(root.s, root.s)
            ctx.fillStyle = "#F5F5F5"
            ctx.beginPath()
            ctx.moveTo(13, 1); ctx.lineTo(5, 17); ctx.lineTo(12, 15)
            ctx.lineTo(10, 31); ctx.lineTo(21, 13); ctx.lineTo(14, 15)
            ctx.closePath(); ctx.fill()
            ctx.restore()
        }
    }

    Text {
        visible: root.plugged
        x: 19 * root.s
        y: 137 * root.s
        text: root.charging ? "Заряжается" : "Питание от сети"
        color: "#B1B3B3"
        font.family: "Noto Sans"
        font.pixelSize: 12 * root.s
    }

    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 18 * root.s
        anchors.bottomMargin: 15 * root.s
        text: root.level >= 0 ? String(root.level) + "%" : "--"
        color: root.level >= 0 && root.level <= 15 ? "#C8102E" : "#F5F5F5"
        font.family: "Ndot77JPExtended"
        font.pixelSize: 42 * root.s
    }
}
