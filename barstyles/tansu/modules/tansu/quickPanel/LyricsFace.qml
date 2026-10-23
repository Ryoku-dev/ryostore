import QtQuick
import QtQuick.Effects
import "../../common"
import "../../common/widgets"
import "../../common/functions/LyricsMath.js" as LM
import "../phone"

// The phone's lyrics tab, opened by the now-playing card: the song's words in
// the middle, the line being sung in full ink and the rest fading away above
// and below, like Spotify's lyric page.
//
// Pure UI (no Quickshell imports): QuickPanel.qml asks LyricsService.qml for
// the words and feeds them in, together with the playback clock. The words
// carry word-level timings when the provider had them, so the line being sung
// lights up a word at a time.
//
// The push-pin in the corner asks QuickPanel to turn the phone into the corner
// player; this screen only draws the pin's state.
Item {
    id: face

    width: 654
    height: 1214

    property real renderScale: 1
    // Design y of the monitor's bottom edge on this screen (the phone shows
    // only part of itself); the footer sits just above it.
    property real visibleBottom: 880

    property string title: ""
    property string artist: ""
    property url art: ""
    property bool playing: false

    // LyricsService: the parsed lines ({ t, text, marks?, end?, bg? }), what it
    // is doing, and which service answered.
    property var lines: []
    property string status: "idle"
    property string sourceKind: ""
    property string sourceName: ""

    // Playback, in seconds.
    property real time: 0
    property real duration: 0

    property bool pinned: false
    // On screen and wanted: what may keep a timer running.
    property bool live: false

    // The glow under the line being sung: the palette's accent, lifted so it
    // reads against the cover in either theme.
    readonly property color glow: Qt.lighter(Theme.accentCyan, 1.45)

    signal closeRequested()
    signal pinToggled()
    signal toggleRequested()
    signal seekRequested(real seconds)
    signal retryRequested()

    readonly property real foot: Math.min(visibleBottom, 1214) - 44
    readonly property real slot: 94

    // The stack follows the singing, a little ahead of each new line so the
    // words are already in the middle when they start (LyricsMath.cursor).
    readonly property real cursorValue: face.lines.length > 0 ? LM.cursor(face.lines, face.time, 0.32, 0) : 0
    readonly property int activeIndex: face.lines.length > 0 ? LM.lineIndexAt(face.lines, face.time) : -1

    // Tokens and their timings for the line being sung: recomputed only when
    // the line changes (not on every clock tick).
    property var activeTokens: []
    property var activeSpans: []
    onActiveIndexChanged: face.refreshLine()
    onLinesChanged: face.refreshLine()

    function refreshLine() {
        const line = face.lines[face.activeIndex]
        if (!line) {
            face.activeTokens = []
            face.activeSpans = []
            return
        }
        const toks = LM.tokens(line.text)
        const next = face.lines[face.activeIndex + 1]
        const t0 = line.t
        const t1 = line.end !== undefined ? line.end : (next ? next.t : t0 + 4)
        face.activeTokens = toks
        face.activeSpans = LM.spansFor(toks, t0, Math.max(0.4, t1 - t0), line.marks)
    }

    readonly property bool wordMode: face.sourceKind === "word" && face.activeSpans.length > 0

    // The screen's own colour, see-through.
    function veil(alpha) {
        return Qt.rgba(Theme.pSurface.r, Theme.pSurface.g, Theme.pSurface.b, alpha)
    }

    function stamp(seconds) {
        const total = Math.max(0, Math.floor(seconds))
        const m = Math.floor(total / 60)
        const s = total % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.pSurface
    }

    // ===== the ground =====
    // The song's own cover, blown up and blurred, so the words sit on the
    // record instead of on a flat screen. The blur is a layer effect: it is
    // rendered once per track and kept as a texture, so nothing here is
    // repainted while the words move.
    Image {
        id: backdrop

        anchors.fill: parent
        source: face.art
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize: Qt.size(320, 320)
        visible: status === Image.Ready

        layer.enabled: visible
        layer.smooth: true
        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 64
            blur: 1
            saturation: 0.55
            brightness: -0.3
        }
    }

    // A scrim over the cover: heaviest under the keys and the progress bar,
    // lightest over the words, so the ink never has to fight the artwork.
    Rectangle {
        anchors.fill: parent
        visible: backdrop.visible

        gradient: Gradient {
            GradientStop { position: 0.0; color: face.veil(0.62) }
            GradientStop { position: 0.26; color: face.veil(0.42) }
            GradientStop { position: 0.70; color: face.veil(0.5) }
            GradientStop { position: 1.0; color: face.veil(0.8) }
        }
    }

    // The screen behind is still live under this one; a click on the words (or
    // on nothing at all) must not reach the Quick Panel's tiles.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onWheel: wheel => wheel.accepted = true
    }

    // ===== header =====
    TansuKey {
        id: backKey
        x: 46
        y: 56
        capW: 54
        capH: 54
        radius: 27
        flatShadow: Theme.quickFlat
        hovered: backArea.containsMouse
        pressed: backArea.pressed

        MaterialIcon {
            anchors.centerIn: parent
            name: "arrow_back"
            size: 24
            color: Theme.pInk
        }

        MouseArea {
            id: backArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: face.closeRequested()
        }
    }

    // Under the notch, level with the keys beside it.
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 69
        text: "Lyrics"
        color: Theme.pInk
        font.family: Theme.fontFamily
        font.pixelSize: 23
        font.weight: Font.ExtraBold
        font.styleName: Theme.fontStyleBold
    }

    TansuKey {
        id: pinKey
        x: face.width - 46 - capW
        y: 56
        capW: 54
        capH: 54
        radius: 27
        lit: face.pinned
        flatShadow: Theme.quickFlat
        hovered: pinArea.containsMouse
        pressed: pinArea.pressed

        MaterialIcon {
            anchors.centerIn: parent
            name: "push_pin"
            size: 24
            fill: face.pinned ? 1 : 0
            color: face.pinned ? Theme.inkOnAccent : Theme.pInk
        }

        MouseArea {
            id: pinArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: face.pinToggled()
        }
    }

    // Where the push-pin is on the screen. The panel puts its click mask on
    // this while the phone is pinned (see the mask in QuickPanel.qml).
    readonly property rect pinRect: Qt.rect(pinKey.x, pinKey.y, pinKey.capW, pinKey.capH)

    // ===== the track =====
    Item {
        id: artBox
        x: 40
        y: 132
        width: 70
        height: 70

        Rectangle {
            anchors.fill: parent
            radius: 18
            color: Theme.pSurfaceHover
            antialiasing: true
        }

        MaterialIcon {
            anchors.centerIn: parent
            visible: cover.status !== Image.Ready
            name: "music_note"
            size: 28
            color: Theme.pInkSub
        }

        Image {
            id: cover
            anchors.fill: parent
            source: face.art
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            sourceSize: Qt.size(140, 140)
            visible: false
        }

        Item {
            id: artMask
            anchors.fill: parent
            visible: false
            layer.enabled: true
            layer.smooth: true
            layer.textureSize: Qt.size(Math.ceil(width * face.renderScale * 2),
                                       Math.ceil(height * face.renderScale * 2))

            Rectangle {
                anchors.fill: parent
                radius: 18
                color: "black"
                antialiasing: true
            }
        }

        MultiEffect {
            anchors.fill: parent
            source: cover
            maskEnabled: true
            maskSource: artMask
            visible: cover.status === Image.Ready
        }
    }

    Column {
        x: 128
        width: 350
        anchors.verticalCenter: artBox.verticalCenter
        spacing: 2

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: face.title
            color: Theme.pInk
            font.family: Theme.fontFamily
            font.pixelSize: 21
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: face.artist
            color: Theme.pInkSub
            font.family: Theme.fontFamily
            font.pixelSize: 15
        }

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: {
                if (face.status !== "ready" || face.sourceName === "")
                    return ""
                return (face.sourceKind === "word" ? "Word by word · " : "Synced · ")
                       + face.sourceName
            }
            color: Theme.accentCyan
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }
    }

    TansuKey {
        id: playKey
        x: face.width - 40 - capW
        y: 142
        capW: 50
        capH: 50
        radius: 25
        lit: true
        flatShadow: Theme.quickFlat
        hovered: playArea.containsMouse
        pressed: playArea.pressed

        MaterialIcon {
            anchors.centerIn: parent
            name: face.playing ? "pause" : "play_arrow"
            size: 26
            fill: 1
            color: Theme.inkOnAccent
        }

        MouseArea {
            id: playArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: face.toggleRequested()
        }
    }

    // ===== the words =====
    Item {
        id: viewport

        x: 40
        y: 226
        width: face.width - 80
        height: face.foot - 74 - y
        clip: true

        Item {
            id: stack

            width: viewport.width
            height: 1
            y: viewport.height / 2 - (face.cursorValue + 0.5) * face.slot

            Repeater {
                model: face.lines

                delegate: Item {
                    id: row
                    required property int index
                    required property var modelData

                    readonly property bool on: index === face.activeIndex
                    readonly property real d: index - face.cursorValue

                    width: stack.width
                    height: face.slot
                    y: index * face.slot
                    opacity: Math.max(0, 1 - Math.abs(d) * 0.5)
                    scale: Math.max(0.72, 1 - Math.abs(d) * 0.14)
                    transformOrigin: Item.Left

                    // The line being sung carries a little of its own light.
                    // The layer is the row (which has room around the words),
                    // not the text: a halo on the text's own box is clipped.
                    layer.enabled: on
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: face.glow
                        shadowOpacity: 1
                        shadowBlur: 0.85
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 0
                    }

                    // The line being sung, word by word when the lyrics came
                    // with word timings.
                    Row {
                        id: wordRow
                        anchors.verticalCenter: parent.verticalCenter
                        visible: row.on && face.wordMode && face.activeTokens.length > 0
                        scale: Math.min(1, (viewport.width - 8) / Math.max(1, implicitWidth))
                        transformOrigin: Item.Left

                        Repeater {
                            model: face.activeTokens

                            delegate: Text {
                                required property int index
                                required property var modelData

                                readonly property var span: face.activeSpans[index]

                                text: (modelData.gap ? " " : "") + modelData.s
                                color: {
                                    if (!span)
                                        return Theme.pInkSub
                                    if (face.time >= span.to)
                                        return Theme.pInk
                                    if (face.time >= span.from)
                                        return Theme.accentCyan
                                    return Theme.pInkSub
                                }
                                font.family: Theme.fontFamily
                                font.pixelSize: 30
                                font.weight: Font.ExtraBold
                                font.styleName: Theme.fontStyleBold
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        visible: !wordRow.visible
                        text: row.modelData.text
                        color: row.on ? Theme.pInk : Theme.pInkSub
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: 30
                        font.weight: row.on ? Font.ExtraBold : Font.Bold
                        font.styleName: Theme.fontStyleBold
                    }
                }
            }
        }

        // Nothing to sing along to yet.
        Column {
            anchors.centerIn: parent
            width: parent.width - 40
            spacing: 14
            visible: face.status !== "ready"

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: {
                    if (face.status === "loading")
                        return "Finding the lyrics…"
                    if (face.status === "instrumental")
                        return "Instrumental"
                    if (face.status === "offline")
                        return "No lyrics service answered"
                    if (face.status === "none")
                        return "No lyrics for this song"
                    return ""
                }
                color: Theme.pInk
                font.family: Theme.fontFamily
                font.pixelSize: 20
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap

                // A slow breath while the words are being fetched.
                SequentialAnimation on opacity {
                    running: face.status === "loading" && face.live
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.4; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                }
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: face.status === "none" || face.status === "offline"
                text: "Tap to ask again"
                color: Theme.accentCyan
                font.family: Theme.fontFamily
                font.pixelSize: 15
                font.weight: Font.DemiBold

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -12
                    cursorShape: Qt.PointingHandCursor
                    onClicked: face.retryRequested()
                }
            }
        }
    }

    // ===== the footer =====
    // The progress is a wave: what has been sung runs in the accent colours
    // and rolls gently while the song plays, the rest of it is a flat line.
    // One small Canvas at 30fps (a few hundred pixels a frame) rather than a
    // hundred moving rectangles.
    Item {
        id: progressBar

        x: 40
        y: face.foot - 72
        width: face.width - 80
        height: 18

        readonly property real ratio: face.duration > 0
            ? Math.max(0, Math.min(1, face.time / face.duration)) : 0

        Canvas {
            id: wave

            anchors.fill: parent
            renderTarget: Canvas.FramebufferObject

            // The wave rolls with the song: the same clock the words use, so
            // it stops when the song does and costs nothing while the tab is
            // shut (the panel lets go of the clock then).
            readonly property real phase: face.time * 2.6
            onPhaseChanged: requestPaint()

            // Amplitude and length of the wave, in screen pixels.
            readonly property real amp: 3
            readonly property real len: 34

            onPaint: {
                const ctx = getContext("2d")
                const w = width, h = height, mid = h / 2
                ctx.clearRect(0, 0, w, h)
                ctx.lineWidth = 4
                ctx.lineCap = "round"
                ctx.lineJoin = "round"

                // The wave, tapered into a flat line at both ends so it
                // reads as a stroke and not as a cut sine.
                function path() {
                    ctx.beginPath()
                    for (let x = 0; x <= w; x += 3) {
                        const edge = Math.min(1, Math.min(x, w - x) / 36)
                        const y = mid + Math.sin(x / wave.len * Math.PI * 2 + wave.phase) * wave.amp * edge
                        if (x === 0)
                            ctx.moveTo(x, y)
                        else
                            ctx.lineTo(x, y)
                    }
                }

                path()
                ctx.strokeStyle = Qt.rgba(Theme.pInk.r, Theme.pInk.g, Theme.pInk.b, 0.16)
                ctx.stroke()

                const r = progressBar.ratio
                if (r <= 0)
                    return

                ctx.save()
                ctx.beginPath()
                ctx.rect(0, 0, w * r, h)
                ctx.clip()
                path()
                const grad = ctx.createLinearGradient(0, 0, w, 0)
                grad.addColorStop(0, Theme.accentMint)
                grad.addColorStop(1, Theme.accentCyan)
                ctx.strokeStyle = grad
                ctx.stroke()
                ctx.restore()

                // The head, with a little of its own light.
                const hx = w * r
                const edge = Math.min(1, Math.min(hx, w - hx) / 36)
                const hy = mid + Math.sin(hx / wave.len * Math.PI * 2 + wave.phase) * wave.amp * edge
                ctx.save()
                ctx.shadowColor = Theme.accentCyan
                ctx.shadowBlur = 12
                ctx.beginPath()
                ctx.arc(hx, hy, 3.4, 0, Math.PI * 2)
                ctx.fillStyle = Theme.accentCyan
                ctx.fill()
                ctx.restore()
            }
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -12
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (face.duration > 0)
                    face.seekRequested(Math.max(0, Math.min(1, mouse.x / progressBar.width)) * face.duration)
            }
        }
    }

    Text {
        x: 40
        y: face.foot - 48
        text: face.stamp(face.time)
        color: Theme.pInkSub
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }

    Text {
        x: face.width - 40 - width
        y: face.foot - 48
        text: face.duration > 0 ? "-" + face.stamp(face.duration - face.time) : ""
        color: Theme.pInkSub
        font.family: Theme.fontFamily
        font.pixelSize: 12
    }
}
