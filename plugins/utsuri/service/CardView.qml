pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects

// One result card: Utsuri's toasts.py ToastCard in QML. 380 x 104, glass
// from shaders/card.frag over Hyprland's blur; a spinner while working, then a
// thumbnail (or a ✓ ! ↺ badge), the title with its green figure chip, the
// detail, a close ✕ and Open / Show in folder / Undo.
Item {
    id: card

    property string state_: "working"   // working | done | error | info
    property string title: ""
    property string detail: ""
    property string good: ""
    property string thumb: ""           // image output to preview, or ""
    property bool hasOuts: false
    property bool hovered: hover.hovered
    property var look: ({ themed: false })   // themes.js resolve()

    // text and line colour: white, or the theme's ink (dark on a light theme)
    readonly property color fg: look.themed ? Qt.color(look.ink) : "white"
    readonly property bool lightCard: look.themed && (0.2126 * fg.r + 0.7152 * fg.g + 0.0722 * fg.b) < 0.5
    function ink(a) {
        return Qt.rgba(card.fg.r, card.fg.g, card.fg.b, a);
    }
    function _v4(c, a) {
        const q = Qt.color(c);
        return Qt.vector4d(q.r, q.g, q.b, a);
    }

    signal act(string name)             // "open" | "show" | "undo" | "close" | "body"

    readonly property real cw: 380
    readonly property real ch: 104
    readonly property string family: "Inter"
    width: cw
    height: ch

    ShaderEffect {
        anchors.fill: parent
        property vector2d size: Qt.vector2d(card.cw, card.ch)
        property real radius: 20
        property real err: card.state_ === "error" ? 1 : 0
        property vector4d tint: card.look.themed ? card._v4(card.look.tint, 0.88) : Qt.vector4d(0, 0, 0, 0)
        property vector4d accent: card.look.themed ? card._v4(card.look.accent, 1) : Qt.vector4d(0, 0, 0, 0)
        fragmentShader: Qt.resolvedUrl("shaders/card.frag.qsb")
    }

    HoverHandler { id: hover }
    // the card body (lowest): a click outside the buttons reveals the file
    MouseArea {
        anchors.fill: parent
        onClicked: card.act("body")
    }

    // ---- leading visual (14, 16, 56 x 56) ----------------------------------
    Item {
        id: lead
        x: 14
        y: (card.ch - 56) / 2 - 8
        width: 56
        height: 56

        // spinner: a faint ring and an iridescent 100° arc turning at ~420°/s
        Canvas {
            id: spin
            anchors.fill: parent
            visible: card.state_ === "working"
            property real a: 0
            NumberAnimation on a {
                running: spin.visible
                from: 0; to: 360; duration: 860; loops: Animation.Infinite
            }
            onAChanged: requestPaint()
            onPaint: {
                const g = getContext("2d");
                g.reset();
                g.lineWidth = 4;
                g.strokeStyle = "rgba(255,255,255,0.2)";
                g.beginPath();
                g.arc(28, 28, 16, 0, Math.PI * 2);
                g.stroke();
                const grad = g.createConicalGradient(28, 28, -a * Math.PI / 180);
                grad.addColorStop(0.0, "#ff6ad5");
                grad.addColorStop(0.33, "#7ad7ff");
                grad.addColorStop(0.66, "#b8ff8a");
                grad.addColorStop(1.0, "#ff6ad5");
                g.strokeStyle = grad;
                g.lineCap = "round";
                g.beginPath();
                const s = -a * Math.PI / 180;
                g.arc(28, 28, 16, s, s + 100 * Math.PI / 180);
                g.stroke();
            }
        }

        Image {
            id: thumbImg
            anchors.fill: parent
            visible: false
            source: card.thumb ? "file://" + card.thumb : ""
            sourceSize: Qt.size(128, 128)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        Rectangle {
            id: thumbMask
            anchors.fill: parent
            radius: 12
            visible: false
            layer.enabled: true
        }
        MultiEffect {
            anchors.fill: parent
            visible: card.state_ === "done" && card.thumb !== "" && thumbImg.status === Image.Ready
            source: thumbImg
            maskEnabled: true
            maskSource: thumbMask
        }
        Rectangle {
            anchors.fill: parent
            visible: card.state_ === "done" && card.thumb !== "" && thumbImg.status === Image.Ready
            radius: 12
            color: "transparent"
            border.width: 1
            border.color: card.ink(110 / 255)
        }

        // badge when there is no thumbnail
        Rectangle {
            readonly property bool show: card.state_ !== "working"
                && !(card.state_ === "done" && card.thumb !== "" && thumbImg.status === Image.Ready)
            visible: show
            anchors.centerIn: parent
            width: 44
            height: 44
            radius: 22
            color: card.ink(34 / 255)
            Text {
                anchors.centerIn: parent
                text: card.state_ === "error" ? "!" : card.state_ === "info" ? "↺" : "✓"
                color: card.state_ === "done" ? (card.lightCard ? "#0f7a43" : "#8dffb8")
                     : card.state_ === "error" ? (card.lightCard ? "#a15c00" : "#ffd36b") : card.fg
                font.family: card.family
                font.bold: true
                font.pixelSize: 22
            }
        }
    }

    // ---- text ---------------------------------------------------------------
    readonly property real tx: 82
    readonly property real tw: cw - tx - 34

    Row {
        x: card.tx
        y: 13
        height: 20
        spacing: 8
        Text {
            id: titleText
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, card.tw - (chip.visible ? chip.width + 8 : 0))
            text: card.title
            elide: Text.ElideRight
            color: card.fg
            font.family: card.family
            font.bold: true
            font.pixelSize: 15
        }
        Rectangle {
            id: chip
            visible: card.good !== "" && titleText.implicitWidth + 8 + width < card.tw
            anchors.verticalCenter: parent.verticalCenter
            width: chipText.implicitWidth + 14
            height: 18
            radius: 9
            color: Qt.rgba(80 / 255, 220 / 255, 140 / 255, 70 / 255)
            Text {
                id: chipText
                anchors.centerIn: parent
                text: card.good
                color: card.lightCard ? "#0f7a43" : "#a8ffc9"
                font.family: card.family
                font.bold: true
                font.pixelSize: 11
            }
        }
    }

    Text {
        x: card.tx
        y: 35
        width: card.tw + 18
        height: 34
        text: card.detail
        wrapMode: Text.WrapAnywhere
        maximumLineCount: 2
        elide: Text.ElideMiddle
        color: card.ink(200 / 255)
        font.family: card.family
        font.pixelSize: 12
    }

    // close ✕
    Text {
        x: card.cw - 30
        y: 6
        width: 24
        height: 24
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: "✕"
        color: closeArea.containsMouse ? card.fg : card.ink(150 / 255)
        font.family: card.family
        font.pixelSize: 13
        MouseArea { id: closeArea; anchors.fill: parent; hoverEnabled: true; onClicked: card.act("close") }
    }

    // Open / Show in folder / Undo
    Row {
        visible: card.state_ === "done" && card.hasOuts
        x: card.tx
        y: card.ch - 32
        spacing: 6
        Repeater {
            model: [["open", "Open"], ["show", "Show in folder"], ["undo", "Undo"]]
            delegate: Rectangle {
                id: btn
                required property var modelData
                width: btnText.implicitWidth + 22
                height: 22
                radius: 11
                color: card.ink((btnArea.containsMouse ? 60 : 26) / 255)
                border.width: 1
                border.color: card.ink((btnArea.containsMouse ? 120 : 60) / 255)
                Text {
                    id: btnText
                    anchors.centerIn: parent
                    text: btn.modelData[1]
                    color: card.fg
                    font.family: card.family
                    font.bold: true
                    font.pixelSize: 12
                }
                MouseArea {
                    id: btnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.act(btn.modelData[0])
                }
            }
        }
    }
}
