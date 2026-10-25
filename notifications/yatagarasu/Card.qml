/* Yatagarasu — Card.qml (v1.3.0)
 *
 * The Kasugai scroll, seated as a Ryoku notification card.
 *
 * One scroll per message, as she always carried them: a dark
 * glass plate, a lit priority edge, the sender's seal, the
 * message in mono, and the burn along the foot — the scroll's
 * remaining life, spent while it waits. A CRITICAL scroll
 * does not burn; it waits, ember-lit, for the captain's hand.
 * The ✕ is the acknowledgment. No bird stands on the card —
 * she roosts at the corner of the desktop, and the scrolls
 * rise above her head; her eye wears the last word.
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

    Component.onCompleted: root._bornAt = Date.now()
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
        height: _col.implicitHeight + Tokens.s3 * 2 * root.us
        radius: Tokens.radius * root.us
        color: Qt.rgba(0.02, 0.04, 0.07, 0.88)
        border.color: _plateHover.hovered ? Qt.alpha(root._theme, 0.85)
                                          : Qt.alpha(root._theme, 0.55)
        border.width: Math.max(1, Tokens.border * root.us)

        LayoutMirroring.enabled: root._mirrored
        LayoutMirroring.childrenInherit: true

        HoverHandler { id: _plateHover }

        // Priority edge — a lit spine of her own. Left by
        // default, right on a left seat (mirrored above),
        // a crown across the top for the centre column.
        Rectangle {
            visible: !root._centered
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: 2
            radius: 1
            color: root._theme
            opacity: 0.85
        }
        Rectangle {
            visible: root._centered
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 2
            radius: 1
            color: root._theme
            opacity: 0.85
        }

        Column {
            id: _col
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
        }

        // Her wire — the card's bottom border, prism-lit in
        // the priority's colour. It rests full when the
        // scroll does not burn; while it burns, the spend
        // point glows and flares once near the end.
        Rectangle {
            anchors { left: parent.left; bottom: parent.bottom }
            height: 1
            width: parent.width
            color: root._theme
            opacity: 0.35
        }
        Rectangle {
            id: _burnWire
            anchors { left: parent.left; bottom: parent.bottom }
            height: 2
            width: parent.width * root._life
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
            x: Math.max(0, _plate.width * root._life - width)
            width: 7 * root.us
            height: 2
            color: root._theme
            opacity: 0.55 + 0.45 * root._flare
        }

        // Clicking the plate runs the sender's default action.
        TapHandler {
            onTapped: if (root.defaultAction) root.invokeAndDismiss(root.defaultAction)
        }
    }
}
