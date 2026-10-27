/* Yatagarasu — Card.qml (v1.4.0)
 *
 * The Kasugai scroll, seated as a Ryoku notification card.
 *
 * One scroll per message: a dark glass plate, the sender's
 * seal, the message in mono, a prism ribbon framing the foot
 * and the right edge, and the burn along the foot — the
 * scroll's remaining life, spent while it waits. The scroll
 * unrolls as it lands. A CRITICAL scroll does not burn; it waits,
 * ember-lit, for the captain's hand. The ✕ is the
 * acknowledgment. The crow perches at the card's foot, on
 * the burn wire; the scroll rides above her head and her
 * eye wears this scroll's priority.
 *
 * Priorities are hers, from the Form Eighty: LOW cyan,
 * MEDIUM emerald, HIGH amber, CRITICAL rose. The freedesktop
 * urgency maps low→LOW, normal→MEDIUM, critical→CRITICAL.
 * HIGH rides the suite dialect: a sender may set the hint
 * "x-jurai-priority" (LOW|MEDIUM|HIGH|CRITICAL) and the
 * scroll obeys it; pair CRITICAL with expire-timeout 0 so
 * the scroll truly waits.
 *
 * The host owns the window, the column, the timers of
 * record, the sounds and the history. This card owns only
 * its face — and follows the house: Tokens for measure,
 * Motion for tempo and calm, the user's own time label.
 */
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Ryoku.Ui.Singletons
import shell.services

Item {
    id: root

    required property var notification
    property real us: 1
    property int lifespanMs: 0
    property string position: "Right"
    property bool showImages: true

    // ── Priority: the hint dialect first, then urgency ──────
    readonly property string _hintPrio: {
        const h = (root.notification && root.notification.hints)
                ? root.notification.hints : {}
        const v = String(h["x-jurai-priority"] || "").toUpperCase()
        return (v === "LOW" || v === "MEDIUM" || v === "HIGH" || v === "CRITICAL")
             ? v : ""
    }
    readonly property int _urg: {
        const u = root.notification ? root.notification.urgency : 1
        return (u !== undefined && u !== null) ? u : 1
    }
    readonly property string _prio: _hintPrio !== "" ? _hintPrio
                                  : _urg >= 2 ? "CRITICAL"
                                  : _urg <= 0 ? "LOW" : "MEDIUM"
    readonly property color _theme: _prio === "CRITICAL" ? "#F43F5E"
                                  : _prio === "HIGH"     ? "#F5B300"
                                  : _prio === "LOW"      ? "#22D3EE"
                                                         : "#10D9A3"

    // ── Seat: mirror for the left column, crown for centre ──
    readonly property bool _mirrored: root.position === "Left"
    readonly property bool _centered: root.position === "Center"

    // ── The seal and the picture ────────────────────────────
    // On this stack the sender's icon rides in `image` as an
    // image://icon/<name> URL, and a real picture as the same
    // URL wrapping a path (or a plain path on other stacks).
    // A bare name is the seal; a path is the picture.
    readonly property string _rawImage: root.notification
        ? String(root.notification.image || "") : ""
    readonly property string _iconSource: {
        const a = root.notification ? String(root.notification.appIcon || "") : ""
        if (a.length > 0) return String(Icons.path(a, true))
        if (root._rawImage.indexOf("image://icon/") === 0) {
            const rest = root._rawImage.substring("image://icon/".length)
            if (rest.length > 0 && rest.indexOf("/") < 0)
                return root._rawImage
        }
        return ""
    }
    readonly property string _imageSource: {
        if (!root.showImages || root._rawImage.length === 0) return ""
        if (root._rawImage.indexOf("image://icon/") === 0) {
            const rest = root._rawImage.substring("image://icon/".length)
            if (rest.length > 0 && rest.indexOf("/") < 0)
                return ""   // an icon, not a picture
        }
        return root._rawImage
    }

    // ── Life: the burn, spent honestly ──────────────────────
    property real _bornAt: 0
    property real _elapsed: 0
    readonly property string _stamp: {
        const t = root.notification ? String(Notifs.timeLabel(root.notification) || "") : ""
        return t.length > 0 ? t : new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
    }
    readonly property bool _burns: root._prio !== "CRITICAL" && root.lifespanMs > 0
    readonly property real _life: {
        if (!root._burns) return 1.0
        const f = 1.0 - (root._elapsed / root.lifespanMs)
        return f < 0 ? 0 : f
    }
    // The flare: a triangle pulse in the burn's final stretch,
    // derived from the tick — no extra animation to pay for.
    readonly property real _flare: {
        if (Motion.reduce || !root._burns || root._life <= 0 || root._life > 0.15)
            return 0
        const ph = (root._elapsed % 900) / 900
        return ph < 0.5 ? ph * 2 : (1 - ph) * 2
    }

    property bool _expanded: false

    // The perch zone at the card's foot, where the crow sits.
    readonly property real _crowScale: 0.54

    // The unroll: 0 as the scroll lands, 1 once it hangs
    // open. Instant when the user asks for calm.
    property real _open: 0
    NumberAnimation {
        id: _openAnim
        target: root; property: "_open"
        from: 0; to: 1; duration: 620
        easing.type: Easing.OutQuint
    }

    // The prism drift — the frame's slow colour travel,
    // stilled when the user asks for calm.
    property real _prism: 0
    NumberAnimation on _prism {
        running: !Motion.reduce
        loops: Animation.Infinite
        from: 0; to: 1; duration: 7000
    }

    // The frame's ribbon: one band hugging the foot and
    // the right edge, bending with the corners.
    readonly property string _framePath: {
        const u = root.us, r = 12 * u, ri = r - 2 * u, T = 34 * u;
        const W = _plate.width, H = _plate.height;
        if (W < 3 * r + T || H < r + T + 12 * u)
            return "";
        return "M 0 " + (H - r - T) +
               " L 0 " + (H - r) +
               " A " + r + " " + r + " 0 0 0 " + r + " " + H +
               " L " + (W - r) + " " + H +
               " A " + r + " " + r + " 0 0 0 " + W + " " + (H - r) +
               " L " + W + " " + r +
               " A " + r + " " + r + " 0 0 0 " + (W - r) + " 0" +
               " L " + (W - r - T) + " 0" +
               " L " + (W - r) + " " + (2 * u) +
               " A " + ri + " " + ri + " 0 0 1 " + (W - 2 * u) + " " + r +
               " L " + (W - 2 * u) + " " + (H - r) +
               " A " + ri + " " + ri + " 0 0 1 " + (W - r) + " " + (H - 2 * u) +
               " L " + r + " " + (H - 2 * u) +
               " A " + ri + " " + ri + " 0 0 1 " + (2 * u) + " " + (H - r) +
               " Z";
    }

    Component.onCompleted: {
        root._bornAt = Date.now();
        if (Motion.reduce)
            root._open = 1;
        else
            _openAnim.start();
    }
    Component.onDestruction: _burnTimer.stop()

    Timer {
        id: _burnTimer
        interval: 100
        repeat: true
        running: root._burns
        onTriggered: root._elapsed = Date.now() - root._bornAt
    }

    readonly property var visibleActions: {
        const source = root.notification?.actions || []
        const result = []
        for (let i = 0; i < source.length; ++i) {
            const candidate = source[i]
            if (candidate && candidate.identifier !== "default"
                    && String(candidate.text || "").length > 0)
                result.push(candidate)
        }
        return result
    }
    readonly property var defaultAction: {
        const source = root.notification?.actions || []
        for (let i = 0; i < source.length; ++i) {
            if (source[i] && source[i].identifier === "default")
                return source[i]
        }
        return null
    }

    function invokeAndDismiss(action): void {
        if (action && typeof action.invoke === "function")
            action.invoke()
        Notifs.dismiss(root.notification)
    }

    implicitHeight: _plate.height

    // The critical glitch — a 1px shiver, her intel-shake.
    // Calm when the user asks for calm.
    property real _glitchX: 0
    SequentialAnimation on _glitchX {
        running: root._prio === "CRITICAL" && !Motion.reduce
        loops: Animation.Infinite
        NumberAnimation { to: -1; duration: 90 }
        NumberAnimation { to: 1;  duration: 90 }
        NumberAnimation { to: 0;  duration: 220 }
        PauseAnimation { duration: 1600 }
    }

    Rectangle {
        id: _plate
        x: root._glitchX
        width: parent.width
        height: (_col.implicitHeight + Tokens.s3 * root.us) * (0.10 + 0.90 * root._open)
        clip: true
        radius: 12 * root.us
        color: Qt.rgba(0.02, 0.04, 0.07, 0.88)

        LayoutMirroring.enabled: root._mirrored
        LayoutMirroring.childrenInherit: true

        HoverHandler { id: _plateHover }

        MouseArea {
            anchors.fill: parent
            enabled: root.defaultAction !== null
            onClicked: root.invokeAndDismiss(root.defaultAction)
        }

        // The frame — one prism ribbon along the foot and
        // the right edge, bending with the corners.
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            opacity: _plateHover.hovered ? 1.0 : 0.9
            ShapePath {
                fillGradient: LinearGradient {
                    x1: 0; y1: _plate.height
                    x2: _plate.width; y2: 0
                    GradientStop { position: 0.0; color: Qt.hsla(0.78, 0.85, 0.62, 0.35) }
                    GradientStop { position: 0.3; color: Qt.hsla((root._prism + 0.15) % 1, 0.85, 0.62, 0.9) }
                    GradientStop { position: 0.55; color: Qt.hsla((root._prism + 0.45) % 1, 0.85, 0.62, 0.9) }
                    GradientStop { position: 0.8; color: Qt.hsla((root._prism + 0.75) % 1, 0.85, 0.62, 0.9) }
                    GradientStop { position: 1.0; color: Qt.hsla(0.52, 0.85, 0.62, 0.35) }
                }
                PathSvg { path: root._framePath }
            }
        }

        Column {
            id: _col
            opacity: 0.3 + 0.7 * root._open
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.leftMargin: Tokens.s3 * root.us
            anchors.rightMargin: Tokens.s3 * root.us
            anchors.topMargin: Tokens.s3 * root.us
            spacing: Tokens.s2 * root.us

            Row {
                width: parent.width
                spacing: Tokens.s2 * root.us

                // The seal: the sender's icon in a tinted
                // medallion; her diamond when none rides.
                Rectangle {
                    width: 24 * root.us
                    height: 24 * root.us
                    radius: 6 * root.us
                    color: Qt.alpha(root._theme, 0.13)
                    border.width: 1
                    border.color: Qt.alpha(root._theme, 0.4)
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        id: _sealImg
                        anchors.centerIn: parent
                        width: 16 * root.us
                        height: 16 * root.us
                        source: root._iconSource
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        visible: status === Image.Ready
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !_sealImg.visible
                        text: "◈"
                        color: root._theme
                        font.pixelSize: Tokens.fRow * root.us
                    }
                }
                Text {
                    width: parent.width - 148 * root.us
                    text: root.notification ? (root.notification.summary || "") : ""
                    color: Qt.rgba(1, 1, 1, 0.94)
                    font.family: Tokens.mono
                    font.pixelSize: Tokens.fRow * root.us
                    font.bold: true
                    font.letterSpacing: 0.6
                    elide: Text.ElideRight
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: root._prio
                    color: root._theme
                    font.family: Tokens.mono
                    font.pixelSize: Tokens.fMicro * root.us
                    font.letterSpacing: 1.2
                    anchors.verticalCenter: parent.verticalCenter
                }
                // The acknowledgment — a full-size target,
                // a small glyph. Dismisses; never invokes.
                Item {
                    width: 26 * root.us
                    height: 26 * root.us
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: _ackHover.hovered ? "#ffffff" : Qt.rgba(1, 1, 1, 0.45)
                        font.pixelSize: Tokens.fSmall * root.us
                    }
                    HoverHandler { id: _ackHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: Notifs.dismiss(root.notification)
                    }
                }
            }

            Text {
                id: _bodyText
                width: parent.width
                visible: text.length > 0
                text: root.notification ? (root.notification.body || "") : ""
                color: Qt.rgba(1, 1, 1, 0.82)
                font.family: Tokens.mono
                font.pixelSize: Tokens.fBody * root.us
                lineHeight: 1.25
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                maximumLineCount: root._expanded ? 100 : 3
                elide: root._expanded ? Text.ElideNone : Text.ElideRight
            }

            // The picture, when one rides and the user
            // allows pictures: framed in her colour, and
            // no hole in the scroll when it is absent.
            Rectangle {
                // The frame is reserved the moment a picture
                // is known to ride — the scroll never grows
                // after it lands; the picture fades in inside
                // its frame when it is ready.
                width: parent.width
                height: root._expanded ? 220 * root.us : 92 * root.us
                visible: root._imageSource.length > 0 && _pic.status !== Image.Error
                radius: 4 * root.us
                color: Qt.alpha(root._theme, 0.06)
                border.width: 1
                border.color: Qt.alpha(root._theme, 0.35)
                clip: true

                Image {
                    id: _pic
                    anchors.fill: parent
                    anchors.margins: 1
                    source: root._imageSource
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    opacity: status === Image.Ready ? 1 : 0
                }
            }

            // The unfold — offered only when the scroll is
            // truly clipped; state lives and dies here.
            Row {
                width: parent.width
                visible: (_bodyText.truncated && !root._expanded) || root._expanded
                Text {
                    text: root._expanded ? "▾  FOLD" : "▸  UNFOLD THE SCROLL"
                    color: _foldHover.hovered ? root._theme : Qt.alpha(root._theme, 0.75)
                    font.family: Tokens.mono
                    font.pixelSize: Tokens.fMicro * root.us
                    font.letterSpacing: 1
                    HoverHandler { id: _foldHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: root._expanded = !root._expanded
                    }
                }
            }

            Row {
                spacing: Tokens.s2 * root.us
                visible: root.visibleActions.length > 0
                Repeater {
                    model: root.visibleActions
                    delegate: Rectangle {
                        required property var modelData
                        width: _actText.implicitWidth + 14 * root.us
                        height: 20 * root.us
                        radius: 4
                        color: _actHover.hovered ? Qt.alpha(root._theme, 0.25)
                                                 : Qt.alpha(root._theme, 0.12)
                        border.width: 1
                        border.color: Qt.alpha(root._theme, 0.45)
                        Text {
                            id: _actText
                            anchors.centerIn: parent
                            text: parent.modelData.text || ""
                            color: Qt.rgba(1, 1, 1, 0.9)
                            font.family: Tokens.mono
                            font.pixelSize: Tokens.fSmall * root.us
                        }
                        HoverHandler { id: _actHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: root.invokeAndDismiss(parent.modelData)
                        }
                    }
                }
            }
            // The foot — one shared line: the stamp at the
            // left, the crow at the right with her feet on
            // the burn wire, the stamp riding her eye-line.
            Row {
                width: parent.width
                spacing: Tokens.s2 * root.us

                Row {
                    id: _footStamp
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.s2 * root.us
                    Text {
                        text: root._stamp
                        color: Qt.rgba(1, 1, 1, 0.35)
                        font.family: Tokens.mono
                        font.pixelSize: Tokens.fMicro * root.us
                    }
                    Text {
                        text: root.notification ? String(root.notification.appName || "").toUpperCase() : ""
                        color: Qt.alpha(root._theme, 0.75)
                        font.family: Tokens.mono
                        font.pixelSize: Tokens.fMicro * root.us
                        font.letterSpacing: 1
                    }
                    Text {
                        visible: root._prio === "CRITICAL"
                        text: "ACK REQUIRED"
                        color: "#F43F5E"
                        font.family: Tokens.mono
                        font.pixelSize: Tokens.fMicro * root.us
                        font.letterSpacing: 1
                    }
                }

                Item {
                    width: parent.width - _footStamp.implicitWidth - _perch.width - 2 * Tokens.s2 * root.us
                    height: 1
                }

                // Her perch slot — exactly her footprint:
                // feet at its bottom edge, on the wire.
                Item {
                    id: _perch
                    opacity: root._open < 0.72 ? 0 : (root._open - 0.72) * 3.6
                    width: 128 * root._crowScale * root.us
                    height: 100 * root._crowScale * root.us

                    KasugaiCrow {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: -16 * root._crowScale * root.us
                        scale: root._crowScale * root.us
                        transformOrigin: Item.BottomRight
                        mood: root._prio
                        calm: Motion.reduce
                    }
                }
            }
        }

        // Her wire — the card's bottom border, prism-lit in
        // the priority's colour. It rests full when the
        // scroll does not burn; while it burns, the spend
        // point glows and flares once near the end.
        Rectangle {
            id: _burnWire
            anchors { left: parent.left; bottom: parent.bottom }
            anchors.leftMargin: 6 * root.us
            height: 2
            width: (parent.width - 12 * root.us) * root._life
            color: root._theme
            opacity: root._prio === "CRITICAL" ? 0.8 : 0.55

            // The ember breath of a waiting critical.
            SequentialAnimation on opacity {
                running: root._prio === "CRITICAL" && !Motion.reduce
                loops: Animation.Infinite
                NumberAnimation { to: 1.0; duration: 1200; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.65; duration: 1200; easing.type: Easing.InOutSine }
            }
        }
        // The spend point — the bright head where the burn
        // is being spent, flaring in the final seconds.
        Rectangle {
            visible: root._burns && root._life > 0
            anchors.bottom: parent.bottom
            x: 6 * root.us + Math.max(0, (_plate.width - 12 * root.us) * root._life - width)
            width: 7 * root.us
            height: 2
            color: root._theme
            opacity: 0.55 + 0.45 * root._flare
        }

    }
}
