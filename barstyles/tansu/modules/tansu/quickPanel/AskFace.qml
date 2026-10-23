import QtQuick
import Quickshell
import Quickshell.Io
import shell.services as Ryoku
import "../../../modules/common"
import "../../../modules/common/widgets"

// Rashin as a phone screen: the transcript Needle keeps for the shell's Agent
// surfaces, in a message thread over Ryoku's wallpaper, with the phone's own
// composer under it.
Item {
    id: face

    readonly property bool classicPanel: true

    width: 654
    height: 1214

    property real renderScale: 1
    property real screenInset: 19
    property bool active: false
    property bool registered: false

    // ready is the quick-ask lane's readiness; the agent lane answers even when
    // no quick provider resolves, so only the bridge being down blocks.
    readonly property bool blocked: !Ryoku.Needle.available
    readonly property int count: Ryoku.Needle.convo.count

    readonly property string statusText: {
        if (!Ryoku.Needle.available)
            return "Rashin is off · switch it on in Ryoku Hub"
        if (Ryoku.Needle.busy)
            return Ryoku.Needle.activity !== "" ? Ryoku.Needle.activity : "working"
        return Ryoku.Needle.currentModel !== "" ? Ryoku.Needle.currentModel : "ready"
    }

    // The screen sits on the wallpaper, so its own ink is light whatever the
    // theme is doing; the palette only decides the two bubble colours.
    readonly property color wallInk: "#f8f5fa"
    readonly property color wallSub: Qt.rgba(1, 1, 1, 0.68)
    readonly property color glass: Qt.rgba(0.04, 0.03, 0.06, 0.46)
    readonly property color glassLine: Qt.rgba(1, 1, 1, 0.20)
    readonly property color agentFill: Qt.rgba(Theme.accentMint.r, Theme.accentMint.g,
                                               Theme.accentMint.b, 0.30)
    readonly property color agentLine: Qt.rgba(Theme.accentMint.r, Theme.accentMint.g,
                                               Theme.accentMint.b, 0.62)

    // A still of the wallpaper for the thread to sit on. Ryoku publishes one
    // for a video (Session.livePoster), but a daemon restart can leave it
    // missing, so the phone keeps its own copy beside the cache.
    property int stillRev: 0
    property string stillFor: ""
    property string stillWant: ""
    readonly property string stillPath: (Quickshell.env("XDG_CACHE_HOME")
        || (Quickshell.env("HOME") + "/.cache")) + "/tansu-rashin-wall.png"
    readonly property url wallSource: {
        if (Ryoku.Session.wallpaper === "")
            return ""
        if (!Ryoku.Session.wallIsVideo)
            return "file://" + Ryoku.Session.wallpaper
        return stillFor === Ryoku.Session.wallpaper
            ? "file://" + stillPath + "?v=" + stillRev : ""
    }

    // Keep the last picture up while a new one is being extracted, so changing
    // the wallpaper never blanks the thread.
    property url shownWall: ""
    onWallSourceChanged: if (wallSource !== "") shownWall = wallSource

    function ensureStill() {
        if (!Ryoku.Session.wallIsVideo || Ryoku.Session.wallpaper === "")
            return
        if (stillFor === Ryoku.Session.wallpaper || stillWant !== "")
            return
        stillWant = Ryoku.Session.wallpaper
        stillProc.running = true
    }

    Process {
        id: stillProc
        command: ["ffmpeg", "-y", "-loglevel", "error", "-ss", "1",
                  "-i", face.stillWant,
                  "-frames:v", "1", "-update", "1", face.stillPath]
        onExited: {
            if (exitCode === 0)
                face.stillFor = face.stillWant
            face.stillWant = ""
            face.stillRev++
        }
    }

    function sendDraft() {
        const text = draft.text.trim()
        if (text.length === 0 || Ryoku.Needle.busy || blocked)
            return
        // The daemon hands a user message to every client but the one that
        // wrote it, so the phone puts its own line in the thread.
        if (Ryoku.Needle.available)
            Ryoku.Needle._frame(JSON.stringify({ type: "user", text: text }))
        Ryoku.Needle.send(text)
        draft.text = ""
    }

    function focusDraft() {
        draft.forceActiveFocus()
        draft.cursorPosition = draft.text.length
    }

    // The picture is prepared as soon as the phone exists, not when Rashin is
    // first pulled in: ffmpeg needs a moment, and the swipe should land on it.
    Component.onCompleted: {
        ensureStill()
        if (wallSource !== "")
            shownWall = wallSource
    }

    onActiveChanged: {
        if (active) {
            ensureStill()
            if (!registered) {
                Ryoku.Needle.agentSurfaceOpened()
                registered = true
            }
            Ryoku.Needle.noteOpened()
            Qt.callLater(chat.positionViewAtEnd)
            Qt.callLater(face.focusDraft)
        } else if (registered) {
            Ryoku.Needle.agentSurfaceClosed()
            registered = false
        }
    }

    Component.onDestruction: {
        if (registered)
            Ryoku.Needle.agentSurfaceClosed()
    }

    Connections {
        target: Ryoku.Needle
        enabled: face.active
        function onTouched() { chat.positionViewAtEnd() }
    }

    Connections {
        target: Ryoku.Session
        function onWallpaperChanged() { face.ensureStill() }
        function onWallIsVideoChanged() { face.ensureStill() }
    }

    // The picture and its scrim. The phone cuts them to its screen shape, so
    // both run the full face and still stop at the bezel.
    Item {
        id: wallArea

        x: face.screenInset
        y: face.screenInset
        width: face.width - 2 * face.screenInset
        height: face.height - 2 * face.screenInset

        Image {
            x: -face.screenInset
            y: -face.screenInset
            width: face.width
            height: face.height
            source: face.shownWall
            // Wallpapers are often far bigger than the phone (this one is
            // 5000x6243): decode at the size it is drawn, or the first swipe
            // waits on tens of megapixels.
            sourceSize: Qt.size(Math.ceil(face.width * face.renderScale * 2),
                                Math.ceil(face.height * face.renderScale * 2))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            visible: status === Image.Ready
        }

        // Dark glass over the wallpaper: heavy at the header and under the
        // composer, light where the thread is so the picture still reads.
        Rectangle {
            x: -face.screenInset
            y: -face.screenInset
            width: face.width
            height: face.height
            gradient: Gradient {
                GradientStop { position: 0.00; color: Qt.rgba(0, 0, 0, 0.60) }
                GradientStop { position: 0.14; color: Qt.rgba(0, 0, 0, 0.38) }
                GradientStop { position: 0.70; color: Qt.rgba(0, 0, 0, 0.48) }
                GradientStop { position: 1.00; color: Qt.rgba(0, 0, 0, 0.72) }
            }
        }
    }

    Text {
        x: 68
        y: 44
        text: "Rashin"
        color: face.wallInk
        font.family: Theme.fontFamily
        font.pixelSize: 26
        font.weight: Font.ExtraBold
        font.styleName: Theme.fontStyleBold
    }

    Text {
        x: 68
        y: 80
        width: 440
        elide: Text.ElideRight
        text: face.statusText
        color: face.wallSub
        font.family: Theme.fontFamily
        font.pixelSize: 17
    }

    Rectangle {
        id: newChat

        x: 518
        y: 38
        width: 52
        height: 52
        radius: 26
        color: newChatArea.pressed ? Qt.rgba(1, 1, 1, 0.28) : face.glass
        border.width: 2
        border.color: face.glassLine

        MaterialIcon {
            anchors.centerIn: parent
            name: "add-circle"
            size: 26
            color: face.wallInk
        }

        MouseArea {
            id: newChatArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Ryoku.Needle.newChat()
        }
    }

    ListView {
        id: chat

        x: 34
        y: 128
        width: 586
        height: 750
        clip: true
        spacing: 12
        boundsBehavior: Flickable.StopAtBounds
        model: Ryoku.Needle.convo

        onCountChanged: Qt.callLater(chat.positionViewAtEnd)
        onContentHeightChanged: if (chat.atYEnd || chat.contentHeight < chat.height)
            Qt.callLater(chat.positionViewAtEnd)

        delegate: Column {
            id: row

            required property string kind
            required property string role
            required property string body
            required property string title
            required property string status

            width: chat.width
            spacing: 6

            Row {
                visible: row.kind !== "msg"
                spacing: 8

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: row.kind === "handoff" ? "transfer-horizontal" : "sledgehammer"
                    size: 20
                    color: face.agentLine
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.kind === "handoff" ? "handed to chat"
                        : row.title + (row.status !== "" ? " · " + row.status : "")
                    color: face.wallSub
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                }
            }

            Text {
                visible: row.kind === "msg" && row.role !== "user"
                x: 18
                text: "Rashin"
                color: Qt.lighter(Theme.accentMint, 1.25)
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            Rectangle {
                id: bubble

                visible: row.kind === "msg"
                x: row.role === "user" ? row.width - width : 0
                width: Math.min(bodyText.implicitWidth, row.width * 0.76) + 36
                height: bodyText.implicitHeight + 26
                radius: 24
                color: row.role === "user" ? Theme.accentCyan : face.agentFill
                border.width: 2
                border.color: row.role === "user" ? Qt.rgba(1, 1, 1, 0.22) : face.agentLine
                antialiasing: true

                Text {
                    id: bodyText

                    x: 18
                    y: 13
                    width: Math.min(implicitWidth, row.width * 0.76)
                    text: row.body
                    wrapMode: Text.Wrap
                    color: row.role === "user" ? Theme.inkOnAccent : face.wallInk
                    font.family: Theme.fontFamily
                    font.pixelSize: 19
                    lineHeight: 25
                    lineHeightMode: Text.FixedHeight
                }
            }
        }
    }

    Column {
        x: 34
        y: 128
        width: 586
        height: 750
        spacing: 16
        visible: chat.count === 0

        Item { width: 1; height: 250 }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: face.blocked ? face.statusText
                : Ryoku.Needle.busy ? face.statusText : "Ask Rashin anything"
            color: face.wallInk
            font.family: Theme.fontFamily
            font.pixelSize: 22
            font.weight: Font.DemiBold
        }

        Flow {
            width: parent.width
            visible: !face.blocked && !Ryoku.Needle.busy
            spacing: 10

            Repeater {
                model: ["Summarise this desktop", "What is running?", "Tidy my downloads"]

                delegate: Rectangle {
                    required property string modelData

                    width: chipText.implicitWidth + 34
                    height: 44
                    radius: 22
                    color: chipArea.pressed ? Qt.rgba(1, 1, 1, 0.26) : face.glass
                    border.width: 2
                    border.color: face.glassLine

                    Text {
                        id: chipText
                        anchors.centerIn: parent
                        text: parent.modelData
                        color: face.wallInk
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                    }

                    MouseArea {
                        id: chipArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            draft.text = parent.modelData
                            face.focusDraft()
                        }
                    }
                }
            }
        }
    }

    // What the agent is doing, under the thread while it works.
    Text {
        x: 34
        y: 886
        width: 586
        horizontalAlignment: Text.AlignHCenter
        visible: chat.count > 0 && Ryoku.Needle.busy
        text: face.statusText
        color: face.wallSub
        font.family: Theme.fontFamily
        font.pixelSize: 15
    }

    Rectangle {
        id: field

        x: 34
        y: 944
        width: 586
        height: 88
        radius: 44
        color: face.glass
        border.width: 2
        border.color: draft.activeFocus ? Theme.accentCyan : face.glassLine

        TextInput {
            id: draft

            x: 30
            width: parent.width - 118
            anchors.verticalCenter: parent.verticalCenter
            color: face.wallInk
            selectionColor: Theme.accentCyan
            selectedTextColor: Theme.inkOnAccent
            font.family: Theme.fontFamily
            font.pixelSize: 21
            clip: true
            selectByMouse: true
            // Stay typable while a turn runs: only a missing model disables it,
            // and a turn that took the field away lost the focus with it.
            enabled: !face.blocked

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    face.sendDraft()
                } else {
                    return
                }
                event.accepted = true
            }
        }

        Text {
            x: 30
            anchors.verticalCenter: parent.verticalCenter
            visible: draft.text.length === 0
            text: face.blocked ? "Connect a model in Ryoku Hub"
                : Ryoku.Needle.busy ? "Rashin is working" : "Message Rashin"
            color: face.wallSub
            font.family: Theme.fontFamily
            font.pixelSize: 21
        }

        Rectangle {
            id: send

            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 60
            height: 60
            radius: 30
            color: Ryoku.Needle.busy ? Theme.accentMint : Theme.accentCyan
            opacity: face.blocked ? 0.4 : 1

            MaterialIcon {
                anchors.centerIn: parent
                name: Ryoku.Needle.busy ? "stop" : "arrow-up"
                size: 28
                color: Theme.inkOnAccent
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Ryoku.Needle.busy ? Ryoku.Needle.cancel() : face.sendDraft()
            }
        }
    }
}
