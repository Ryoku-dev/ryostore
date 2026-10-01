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
    readonly property var frame: service ? service.lyricFrame : ({})
    readonly property bool available: state.available === true
    readonly property bool playing: state.playing === true
    readonly property string titleText: available ? (state.title || "Музыка") : "Ничего не играет"
    readonly property string artistText: available ? (state.artist || " ") : " "
    readonly property string artUrl: available ? String(state.artUrl || "") : ""
    readonly property real position: Number(state.position || 0)
    readonly property real length: Number(state.length || 0)
    readonly property bool lyricsMatch: available && String(frame.title || "")
        .toLocaleLowerCase().startsWith(String(state.title || "").toLocaleLowerCase())
    readonly property string lyricsStatus: lyricsMatch ? String(frame.lyricsStatus || "idle") : "loading"
    readonly property var syncedLines: lyricsStatus === "ok" && Array.isArray(frame.lyrics)
        ? frame.lyrics : []
    readonly property var plainLines: lyricsStatus === "plain" && Array.isArray(frame.plain)
        ? frame.plain : []
    readonly property int activeLine: {
        let found = 0
        for (let i = 0; i < syncedLines.length; i++) {
            if (Number(syncedLines[i].t) <= position) found = i
            else break
        }
        return found
    }

    function lineAt(index) {
        if (index < 0 || index >= syncedLines.length) return ""
        return String(syncedLines[index].text || "♪")
    }
    function stamp(seconds) {
        const n = Math.max(0, Math.floor(seconds))
        return String(Math.floor(n / 60)) + ":" + String(n % 60).padStart(2, "0")
    }

    // Three columns by two rows of the desktop grid.
    implicitWidth: 392 * s
    implicitHeight: 256 * s
    width: implicitWidth
    height: implicitHeight
    radius: 28 * s
    color: "#1C1D21"

    Canvas {
        x: 18 * root.s
        y: 18 * root.s
        width: 108 * root.s
        height: 108 * root.s
        antialiasing: true
        onPaint: {
            const c = getContext("2d")
            c.clearRect(0, 0, width, height)
            c.save()
            c.scale(root.s, root.s)
            c.beginPath(); c.arc(54, 54, 52, 0, Math.PI * 2)
            c.fillStyle = "#303136"; c.fill()
            c.strokeStyle = "#515258"; c.lineWidth = 1.5
            for (const r of [40, 29, 18]) {
                c.beginPath(); c.arc(54, 54, r, 0, Math.PI * 2); c.stroke()
            }
            c.beginPath(); c.arc(54, 54, 6, 0, Math.PI * 2)
            c.fillStyle = "#DCD7D2"; c.fill()
            c.restore()
        }
    }

    // Album artwork fills the cover slot; the record remains as a fallback.
    Image {
        id: albumArt
        x: 18 * root.s
        y: 18 * root.s
        width: 108 * root.s
        height: 108 * root.s
        source: root.artUrl
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        visible: root.available && status === Image.Ready
    }

    Text {
        x: 142 * root.s; y: 19 * root.s
        width: 230 * root.s; height: 52 * root.s
        text: root.titleText
        color: "#F5F5F5"
        font.family: "Noto Sans"
        font.pixelSize: 16 * root.s
        font.weight: Font.Medium
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
    }
    Text {
        x: 142 * root.s; y: 74 * root.s
        width: 183 * root.s
        text: root.artistText
        color: "#B1B3B3"
        font.family: "Noto Sans"
        font.pixelSize: 12 * root.s
        elide: Text.ElideRight
    }
    Text {
        x: 142 * root.s; y: 105 * root.s
        text: root.available ? root.stamp(root.position) + " / " + root.stamp(root.length) : ""
        color: "#B1B3B3"
        font.family: "Noto Sans"
        font.pixelSize: 11 * root.s
    }
    Rectangle {
        id: playButton
        x: 338 * root.s; y: 91 * root.s
        width: 36 * root.s; height: 36 * root.s
        radius: width / 2
        color: "#303136"
        opacity: root.available ? 1 : 0.5
        Canvas {
            id: playMark
            anchors.fill: parent
            onPaint: {
                const c = getContext("2d")
                c.clearRect(0, 0, width, height)
                c.save(); c.scale(root.s, root.s)
                c.fillStyle = "#F5F5F5"
                if (root.playing) {
                    c.fillRect(12, 10, 4, 16)
                    c.fillRect(20, 10, 4, 16)
                } else {
                    c.beginPath(); c.moveTo(13, 9)
                    c.lineTo(26, 18); c.lineTo(13, 27)
                    c.closePath(); c.fill()
                }
                c.restore()
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: if (root.service) root.service.togglePlayback()
        }
    }
    onPlayingChanged: playMark.requestPaint()

    Rectangle {
        id: lyricPlate
        x: 18 * root.s; y: 143 * root.s
        width: 356 * root.s; height: 76 * root.s
        radius: 18 * root.s
        color: "#303136"
        clip: true

        Column {
            visible: root.syncedLines.length > 0
            x: 14 * root.s; y: 7 * root.s
            width: parent.width - 28 * root.s
            spacing: 2 * root.s
            Text {
                width: parent.width
                visible: text.length > 0
                text: root.lineAt(root.activeLine - 1)
                color: "#B1B3B3"; opacity: 0.55
                font.family: "Noto Sans"; font.pixelSize: 11 * root.s
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: root.lineAt(root.activeLine)
                color: "#F5F5F5"
                font.family: "Noto Sans"; font.pixelSize: 14 * root.s
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                visible: text.length > 0
                text: root.lineAt(root.activeLine + 1)
                color: "#B1B3B3"; opacity: 0.7
                font.family: "Noto Sans"; font.pixelSize: 11 * root.s
                elide: Text.ElideRight
            }
        }
        Text {
            visible: root.plainLines.length > 0 && root.syncedLines.length === 0
            x: 14 * root.s; y: 8 * root.s
            width: parent.width - 28 * root.s
            height: parent.height - 16 * root.s
            text: root.plainLines.slice(0, 3).join("\n")
            color: "#F5F5F5"
            font.family: "Noto Sans"; font.pixelSize: 12 * root.s
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
        }
        Text {
            anchors.centerIn: parent
            visible: root.plainLines.length === 0 && root.syncedLines.length === 0
            width: parent.width - 24 * root.s
            horizontalAlignment: Text.AlignHCenter
            text: !root.available ? "Включите музыку"
                : root.lyricsStatus === "loading" ? "Ищем текст песни…"
                : root.lyricsStatus === "error" ? "Текст недоступен"
                : "Текст песни не найден"
            color: "#B1B3B3"
            font.family: "Noto Sans"; font.pixelSize: 13 * root.s
        }
    }

    Rectangle {
        x: 18 * root.s; y: 238 * root.s
        width: 356 * root.s; height: 3 * root.s
        radius: height / 2
        color: "#4B4C52"
        Rectangle {
            width: parent.width * (root.length > 0
                ? Math.max(0, Math.min(1, root.position / root.length)) : 0)
            height: parent.height
            radius: parent.radius
            color: "#DCD7D2"
        }
    }
}
