import QtQuick
import QtQuick.Window

Rectangle {
    id: root

    // ── surface ─────────────────────────────────────────────────────────────
    // Parent-relative, not Screen: under the lock this item has a parent surface
    // sized to its own output, and under a real SDDM greeter it has none and
    // Screen is the only answer. Sizing from Screen alone gets the wrong box on
    // one of the two hosts.
    width: parent ? parent.width : Screen.width
    height: parent ? parent.height : Screen.height
    color: pal.bg
    focus: true

    // Escape wipes the field. TextInput ignores Escape, so it bubbles up to here.
    Keys.onEscapePressed: (e) => { pw.text = ""; pw.forceActiveFocus(); e.accepted = true }

    // the lock surface carries no cursor of its own
    MouseArea { anchors.fill: parent; cursorShape: Qt.ArrowCursor; z: -1 }

    // Design baseline is a 768px-tall screen. Guarded against the frame or two
    // where a parent-relative root still measures 0 — a font.pixelSize of 0 is a
    // warning, and warnings are bugs.
    readonly property real s: (height > 0 ? height : 768) / 768
    // one physical device pixel. The rule is specified in device pixels rather
    // than layout units so it stays a hairline on a fractionally-scaled output.
    readonly property real dp: Screen.devicePixelRatio > 0 ? 1 / Screen.devicePixelRatio : 1

    // ── host ────────────────────────────────────────────────────────────────
    readonly property bool hasSddm: typeof sddm !== "undefined"
    // fingerprintHint exists only on the qylock shim; under a real greeter it is
    // undefined, so this is the documented "am I under the lock?" probe.
    readonly property bool underQylock: root.hasSddm && sddm.fingerprintHint === true

    // ── config: every value arrives as a string ─────────────────────────────
    function cfg(key, def) {
        return (typeof config !== "undefined" && config[key] !== undefined && config[key] !== "")
            ? String(config[key]) : def
    }
    readonly property bool clock24h: cfg("clock24h", "true") !== "false"
    readonly property bool showSeconds: cfg("showSeconds", "true") !== "false"
    readonly property real marginUnit: parseFloat(cfg("marginUnit", "44")) || 44
    readonly property real hairline: parseFloat(cfg("hairline", "1")) || 1
    readonly property string accentKey: cfg("accent", "primary")

    // ── the grid ────────────────────────────────────────────────────────────
    // One module, rounded to a whole pixel so nothing on the page lands on a
    // half. Every margin and every gap below is m or a whole multiple of it.
    readonly property real m: Math.round(root.marginUnit * root.s)
    readonly property real colW: Math.max(1, root.width - 2 * root.m)
    // The rule is not placed at a fraction of the height. The air above the
    // numerals is held at 0.80 of the air below the input line, which is what
    // reads as centred once the eye has weighed the numeral mass — and it holds
    // that ratio on a 16:10 panel as well as on a 16:9 one, where a fixed
    // fraction would not. Clamped so a very wide screen cannot push it off.
    readonly property real balance: 0.80
    readonly property real ruleY: Math.round(Math.max(root.capH + 2 * root.m, Math.min(root.height - 3 * root.m,
        (root.capH + root.m + root.balance * (root.height - 2 * root.m)) / (1 + root.balance))))
    readonly property real fieldY: root.ruleY + root.m               // input baseline
    readonly property real statusY: root.ruleY + 2 * root.m
    readonly property int gapSecU: 3      // modules between the minutes and the seconds
    readonly property int tailU: 3        // modules of rule left running past the type

    // ── palette (colors.json, with the Rose Pine fallback baked in) ──────────
    QtObject {
        id: pal
        property color bg:     "#191724"
        property color fg:     "#e0def4"
        property color dim:    "#908caa"   // onSurfaceVariant
        property color line:   "#6e6a86"   // outline
        property color accent: "#c4a7e7"
        property color error:  "#eb6f92"
    }
    // rule.color is animated on failure, which destroys its binding; keep the
    // idle colour here so the flash has something to animate back to.
    readonly property color ruleColor: pal.line

    readonly property string homeDir:
        "/home/" + ((typeof userModel !== "undefined" && userModel.lastUser) ? userModel.lastUser : "")

    function readJson(path, onOk) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            // a file:// read reports status 0 on success and on failure alike;
            // an empty body is the only reliable "not there" signal
            if ((xhr.status === 200 || xhr.status === 0) && xhr.responseText) {
                try { onOk(JSON.parse(xhr.responseText)) } catch (e) { }
            }
            // no else: the fallback palette is simply left standing
        }
        try { xhr.open("GET", "file://" + path, true); xhr.send() } catch (e) { }
    }

    Component.onCompleted: {
        if (typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0)
            root.sessionIndex = sessionModel.lastIndex
        // a literal accent needs no file at all
        if (root.accentKey.charAt(0) === "#") pal.accent = root.accentKey
        readJson(root.homeDir + "/.cache/ryoku/colors.json", function(o) {
            if (o.background)       pal.bg = o.background
            if (o.onSurface)        pal.fg = o.onSurface
            if (o.onSurfaceVariant) pal.dim = o.onSurfaceVariant
            if (o.outline)          pal.line = o.outline
            if (o.error)            pal.error = o.error
            if (root.accentKey.charAt(0) !== "#" && o[root.accentKey]) pal.accent = o[root.accentKey]
        })
        introFallback.start()
    }

    // ── the clock ───────────────────────────────────────────────────────────
    property var now: new Date()
    Timer {
        id: tick
        interval: 1000
        repeat: true
        // a 1s wall clock, awake only while this surface can be seen
        running: root.underQylock || Window.active
        onTriggered: {
            root.now = new Date()
            // re-phase onto the next whole second: a ticking numeral that drifts
            // off the second boundary visibly skips
            tick.interval = 1000 - root.now.getMilliseconds() + 8
        }
    }

    // Zero-padded, always two digits: a one-digit hour would drag the colon and
    // the minutes left and take the whole line off the grid twice a day. The
    // 12-hour case is counted out by hand because Qt only reads "hh" as a
    // 12-hour field when the same format string also carries an AM/PM field.
    readonly property string hourText: {
        if (root.clock24h) return Qt.formatDateTime(root.now, "HH")
        var h = root.now.getHours() % 12
        if (h === 0) h = 12
        return (h < 10 ? "0" : "") + h
    }
    readonly property string minText:  Qt.formatDateTime(root.now, "mm")
    readonly property string secText:  Qt.formatDateTime(root.now, "ss")
    readonly property string apText:   Qt.formatDateTime(root.now, "AP")
    readonly property string dayText:  Qt.formatDate(root.now, "dddd").toUpperCase()
    readonly property string dateText: Qt.formatDate(root.now, "dd.MM.yyyy")
    readonly property string hostText: (root.hasSddm && sddm.hostName) ? String(sddm.hostName).toUpperCase() : ""

    // ── type ────────────────────────────────────────────────────────────────
    readonly property string displayFamily: "Inter Display"
    readonly property string metaFamily: "Inter"
    readonly property real track: -0.038                 // clock tracking, in em

    // The line is set from the INK of the numerals, not from their advances:
    // what the eye measures against the margin is the printed shape. Everything
    // is gauged once at a fixed 200px and expressed as a ratio, so the live size
    // is derived from constants and can never feed back into itself.
    readonly property real gaugeSize: 200
    TextMetrics {
        id: pairGauge                       // a two-digit group
        text: "00"
        font.family: root.displayFamily
        font.weight: Font.Thin
        font.pixelSize: root.gaugeSize
        font.letterSpacing: root.gaugeSize * root.track
    }
    TextMetrics {
        id: colonGauge
        text: ":"
        font.family: root.displayFamily
        font.weight: Font.Thin
        font.pixelSize: root.gaugeSize
    }
    // ink width of a digit pair, and its left side bearing, per em
    readonly property real emPair: pairGauge.tightBoundingRect.width / root.gaugeSize
    // cap centre of the numerals, measured from the baseline (negative = up)
    readonly property real emCapMid: (pairGauge.tightBoundingRect.y + pairGauge.tightBoundingRect.height / 2) / root.gaugeSize
    readonly property real emCapTop: pairGauge.tightBoundingRect.y / root.gaugeSize
    readonly property real emColon: colonGauge.tightBoundingRect.width / root.gaugeSize
    readonly property real emColonL: colonGauge.tightBoundingRect.x / root.gaugeSize
    readonly property real emColonMid: (colonGauge.tightBoundingRect.y + colonGauge.tightBoundingRect.height / 2) / root.gaugeSize

    // Set at full size the colon's dots are five times the weight of a Thin
    // numeral stroke and swallow the middle of the line. Cut to a little over
    // half, they read as punctuation again.
    readonly property real colonRatio: 0.72
    readonly property real secRatio: 0.13          // the seconds, in clock ems
    readonly property real gapColon: 0.09          // air either side of the colon, in clock ems

    readonly property real groupEm: 2 * root.emPair + 2 * root.gapColon + root.emColon * root.colonRatio
    readonly property real lineEm: root.groupEm + (root.showSeconds ? root.emPair * root.secRatio : 0)
    readonly property real lineW: Math.max(1, root.colW - root.tailU * root.m
                                             - (root.showSeconds ? root.gapSecU * root.m : 0))
    readonly property real clockSize: root.lineEm > 0 ? Math.max(8, root.lineW / root.lineEm) : 100 * root.s
    readonly property real colonSize: root.clockSize * root.colonRatio
    readonly property real secSize: root.clockSize * root.secRatio

    readonly property real capH: -root.emCapTop * root.clockSize

    // The rhythm of the line is fixed — each group's ink starts on a position
    // derived from the "00" gauge, so nothing shuffles as the digits change.
    readonly property real xHour:  root.m
    readonly property real xMin:   root.m + (root.emPair + 2 * root.gapColon + root.emColon * root.colonRatio) * root.clockSize
    readonly property real xSec:   root.m + root.groupEm * root.clockSize + root.gapSecU * root.m

    // …but the digits themselves are not equally inked. "1" is a stem inside a
    // full advance, so a colon set at a fixed distance from the hour's advance
    // sits a quarter of an em off centre at 21:05 and dead centre at 20:05.
    // These read the live strings so each group's ink lands on its position and
    // the colon can hang in the middle of the gap that actually exists.
    TextMetrics { id: hourInk; text: root.hourText; font: pairGauge.font }
    TextMetrics { id: minInk;  text: root.minText;  font: pairGauge.font }
    TextMetrics { id: secInk;  text: root.secText;  font: pairGauge.font }
    readonly property real clockScale: root.clockSize / root.gaugeSize
    readonly property real hourRight: root.xHour + hourInk.tightBoundingRect.width * root.clockScale
    readonly property real colonMid: (root.hourRight + root.xMin) / 2      // the colon's ink centre
    // the colon hangs off the numerals' cap centre, not off their baseline: set
    // on the baseline its dots sit at x-height and the line looks broken-backed
    readonly property real colonBase: root.ruleY + root.emCapMid * root.clockSize - root.emColonMid * root.colonSize

    readonly property real metaSize: Math.round(11 * root.s)
    readonly property real metaTrack: Math.round(0.30 * root.metaSize)
    FontMetrics { id: metaFM; font.family: root.metaFamily; font.pixelSize: root.metaSize }
    TextMetrics {
        id: metaGauge
        text: "H"
        font.family: root.metaFamily
        font.weight: Font.Medium
        font.pixelSize: root.metaSize
    }
    // cap height, read off the ink of a capital: FontMetrics has no such number
    readonly property real metaCap: -metaGauge.tightBoundingRect.y

    readonly property real dotSize: Math.round(30 * root.s)
    readonly property real dotTrack: Math.round(0.50 * root.dotSize)

    // ── auth state ──────────────────────────────────────────────────────────
    property int sessionIndex: 0
    property bool busy: false
    property bool capsOn: false
    property bool failing: false
    property string notice: ""
    property string displayName: ""

    Repeater {
        id: userScan
        model: (typeof userModel !== "undefined") ? userModel : null
        delegate: Item {
            property string uLogin: model.name || ""
            property string uName: model.realName || model.name || ""
        }
    }
    readonly property string loginName: (userScan.count > 0 && userScan.itemAt(0) && userScan.itemAt(0).uLogin)
        ? userScan.itemAt(0).uLogin
        : ((typeof userModel !== "undefined" && userModel.lastUser) ? userModel.lastUser : "user")
    // the model rows are empty at onCompleted and fill in later; read them late
    Timer {
        interval: 400; running: true
        onTriggered: {
            if (userScan.count > 0 && userScan.itemAt(0) && userScan.itemAt(0).uName)
                root.displayName = userScan.itemAt(0).uName
            else if (typeof userModel !== "undefined" && userModel.lastUser)
                root.displayName = userModel.lastUser
        }
    }

    function submit() {
        if (root.busy) return
        // PAM is never started for an empty key and answers nothing at all, so a
        // bare Return must not put the screen into a state it cannot leave
        if (pw.text.length === 0) { pw.forceActiveFocus(); return }
        root.busy = true
        root.failing = false
        root.notice = ""
        failReset.stop()
        if (root.hasSddm) sddm.login(root.loginName, pw.text, root.sessionIndex)
        watchdog.restart()
    }
    // second line of defence for the answers that never come
    Timer {
        id: watchdog
        interval: 8000
        onTriggered: { root.busy = false; pw.text = ""; pw.forceActiveFocus() }
    }

    Connections {
        target: (typeof sddm !== "undefined") ? sddm : null
        // informationMessage/errorMessage exist on a real greeter and not on the
        // shim; without this the whole Connections object errors out there
        ignoreUnknownSignals: true
        function onSurfaceRevealed() { root.playIntro() }
        function onLoginFailed() {
            watchdog.stop()
            root.busy = false
            root.notice = ""
            root.ghostCount = Math.min(pw.text.length, 48)
            root.failing = true
            root.hintGate = 0            // hold the invitation back until the dots are gone
            pw.text = ""
            pw.forceActiveFocus()
            dissolve.restart()
            ruleFlash.restart()
            failReset.restart()
            hintRelease.restart()
        }
        function onLoginSucceeded() {
            watchdog.stop()
            root.busy = false
            outro.start()
        }
        function onInformationMessage(msg) { root.notice = (msg || "").toUpperCase() }
        function onErrorMessage(msg) { root.notice = (msg || "").toUpperCase() }
    }
    Timer { id: failReset;   interval: 2600; onTriggered: root.failing = false }
    Timer { id: hintRelease; interval: 700;  onTriggered: root.hintGate = 1 }

    // ── reveal ──────────────────────────────────────────────────────────────
    // The rule draws itself across the page, the numerals rise onto it, the small
    // type arrives last. Nothing fades in as a lump.
    property real ruleT: 0
    property real clockT: 0
    property real metaT: 0
    property real blockOpacity: 1
    property bool introPlayed: false

    ParallelAnimation {
        id: introAnim
        NumberAnimation { target: root; property: "ruleT";  to: 1; duration: 640; easing.type: Easing.OutCubic }
        SequentialAnimation {
            PauseAnimation { duration: 150 }
            NumberAnimation { target: root; property: "clockT"; to: 1; duration: 620; easing.type: Easing.OutCubic }
        }
        SequentialAnimation {
            PauseAnimation { duration: 400 }
            NumberAnimation { target: root; property: "metaT"; to: 1; duration: 480; easing.type: Easing.OutCubic }
        }
    }
    function playIntro() {
        if (root.introPlayed) return     // onSecureChanged can fire more than once
        root.introPlayed = true
        introAnim.start()
    }
    // surfaceRevealed does not exist under a real greeter and is not guaranteed
    // on X11; the screen must never sit blank waiting for it
    Timer { id: introFallback; interval: 900; onTriggered: root.playIntro() }

    // The host quits ~100ms after loginSucceeded, and only "clockwork" gets more.
    // So the exit is one short fall of the whole block, not a curtain.
    NumberAnimation { id: outro; target: root; property: "blockOpacity"; to: 0; duration: 95; easing.type: Easing.InCubic }

    // ── the field's two states ──────────────────────────────────────────────
    // 0 = the invitation, 1 = caret and dots. One driver, so the two can never
    // both be on the screen.
    property real fieldReveal: 0
    Behavior on fieldReveal { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    property real hintGate: 1
    Behavior on hintGate { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

    // the dots already typed, dissolving after a refusal
    property int ghostCount: 0
    property real ghostFade: 0
    property real ghostSpread: 0
    readonly property string ghostText: root.ghostCount > 0 ? "•".repeat(root.ghostCount) : ""
    ParallelAnimation {
        id: dissolve
        NumberAnimation { target: root; property: "ghostFade";   from: 1; to: 0; duration: 640; easing.type: Easing.InCubic }
        NumberAnimation { target: root; property: "ghostSpread"; from: 0; to: 1; duration: 640; easing.type: Easing.OutCubic }
    }

    // ── composition ─────────────────────────────────────────────────────────
    Item {
        id: stage
        anchors.fill: parent
        opacity: root.blockOpacity

        // The lines the page hangs off. Anchoring type by its baseline rather
        // than by its box is what puts it on the grid instead of near it.
        Item { id: topRef;    x: 0; y: root.m + root.metaCap; width: 1; height: 0 }
        Item { id: ruleRef;   x: 0; y: root.ruleY;            width: 1; height: 0 }
        Item { id: colonRef;  x: 0; y: root.colonBase;        width: 1; height: 0 }
        Item { id: fieldRef;  x: 0; y: root.fieldY;           width: 1; height: 0 }
        Item { id: statusRef; x: 0; y: root.statusY;          width: 1; height: 0 }
        Item { id: botRef;    x: 0; y: root.height - root.m;  width: 1; height: 0 }

        // ── the rule ────────────────────────────────────────────────────────
        Rectangle {
            id: rule
            x: root.m
            y: root.ruleY
            width: Math.max(0, root.colW * root.ruleT)
            height: Math.max(root.dp, root.hairline * root.dp)
            color: root.ruleColor
            antialiasing: false
        }
        SequentialAnimation {
            id: ruleFlash
            ColorAnimation { target: rule; property: "color"; to: pal.error; duration: 80 }
            PauseAnimation { duration: 460 }
            ColorAnimation { target: rule; property: "color"; to: root.ruleColor; duration: 900; easing.type: Easing.OutCubic }
        }

        // ── the hour ────────────────────────────────────────────────────────
        // Four items on one line rather than one string, so the colon can be cut
        // down and optically centred and the seconds can sit in the same line.
        // The side bearings are taken from the "00" gauge and never re-measured:
        // a per-digit correction would shuffle the whole line every minute.
        // They stay siblings of the baseline references rather than living in a
        // wrapper: an anchor may only reach a parent or a sibling.
        Numeral {
            x: root.xHour - hourInk.tightBoundingRect.x * root.clockScale
            anchors.baseline: ruleRef.baseline
            text: root.hourText
        }
        Numeral {
            x: root.colonMid - (root.emColonL + root.emColon / 2) * root.colonSize
            anchors.baseline: colonRef.baseline
            text: ":"
            font.pixelSize: root.colonSize
            font.letterSpacing: 0
        }
        Numeral {
            x: root.xMin - minInk.tightBoundingRect.x * root.clockScale
            anchors.baseline: ruleRef.baseline
            text: root.minText
        }
        Numeral {
            id: secs
            visible: root.showSeconds
            x: root.xSec - secInk.tightBoundingRect.x * root.secSize / root.gaugeSize
            anchors.baseline: ruleRef.baseline
            text: root.secText
            // the same face, small: a satellite of the hour, not a label
            font.weight: Font.Light
            font.pixelSize: root.secSize
            font.letterSpacing: root.secSize * root.track
            color: pal.dim
        }

        // ── the corners ─────────────────────────────────────────────────────
        Meta { x: root.m;  anchors.baseline: topRef.baseline; text: root.dayText }
        Meta {
            anchors.right: parent.right
            // Qt puts letterSpacing after the last glyph too, so a tracked line
            // set flush right stops short of the margin unless you give it back
            anchors.rightMargin: root.m - root.metaTrack
            anchors.baseline: topRef.baseline
            text: root.dateText
        }
        Meta { x: root.m; anchors.baseline: botRef.baseline; text: root.displayName.toUpperCase() }
        Meta {
            anchors.right: parent.right
            anchors.rightMargin: root.m - root.metaTrack
            anchors.baseline: botRef.baseline
            text: root.hostText
        }

        // ── the invitation ──────────────────────────────────────────────────
        Meta {
            id: hint
            x: root.m
            anchors.baseline: fieldRef.baseline
            text: "TYPE TO UNLOCK"
            opacity: root.metaT * (1 - root.fieldReveal) * root.hintGate
        }

        Meta {
            id: meridiem
            visible: !root.clock24h
            anchors.right: parent.right
            anchors.rightMargin: root.m - root.metaTrack
            anchors.baseline: fieldRef.baseline
            text: root.apText
            color: pal.line
        }

        // ── the field ───────────────────────────────────────────────────────
        // Present from the first frame — it is what takes the keystrokes — but it
        // has no box, no rule of its own and no opacity until something is typed.
        Text {
            id: ghost
            x: root.m
            anchors.baseline: fieldRef.baseline
            visible: root.ghostFade > 0.004
            text: root.ghostText
            color: pal.fg
            font.family: root.metaFamily
            font.pixelSize: root.dotSize
            font.letterSpacing: root.dotTrack + root.ghostSpread * 16 * root.s
            opacity: root.ghostFade
        }

        TextInput {
            id: pw
            x: root.m
            width: root.colW
            anchors.baseline: fieldRef.baseline
            echoMode: TextInput.Password
            passwordCharacter: "•"
            passwordMaskDelay: 0
            readOnly: root.busy          // `enabled: false` would drop active focus
            focus: true
            activeFocusOnTab: false
            selectByMouse: false
            font.family: root.metaFamily
            font.pixelSize: root.dotSize
            font.letterSpacing: root.dotTrack
            color: root.busy ? pal.dim : pal.fg
            opacity: root.fieldReveal
            transform: Translate { y: (1 - root.fieldReveal) * 10 * root.s }
            cursorDelegate: Item { width: 0; height: 0 }   // the stock caret is not ours
            Behavior on color { ColorAnimation { duration: 200 } }

            // onAccepted, not Keys.onReturnPressed: it covers the numpad Enter,
            // and wiring both would authenticate twice on one keypress
            onAccepted: root.submit()
            onTextChanged: {
                root.fieldReveal = (pw.text.length > 0) ? 1 : 0
                if (pw.text.length > 0) {
                    root.notice = ""
                    if (root.failing) { root.failing = false; failReset.stop() }
                }
            }

            // keyboard.capsLock is inert under the lock — nothing ever writes it.
            // Infer it instead: a letter arriving uppercase without Shift (or the
            // other way round) means caps is on. Cosmetic only; never blocks.
            Keys.onPressed: (e) => {
                if (e.text.length === 1 && e.text.toLowerCase() !== e.text.toUpperCase()) {
                    var upper = (e.text === e.text.toUpperCase())
                    var shift = (e.modifiers & Qt.ShiftModifier) !== 0
                    root.capsOn = (upper && !shift) || (!upper && shift)
                }
                // never accept the event: the TextInput still has to insert it
            }

            Rectangle {
                id: caret
                x: pw.cursorRectangle.x
                y: pw.cursorRectangle.y + pw.cursorRectangle.height * 0.18
                width: Math.max(root.dp, 2 * root.dp)
                height: pw.cursorRectangle.height * 0.68
                color: pal.accent
                visible: pw.activeFocus
                SequentialAnimation {
                    running: caret.visible
                    loops: Animation.Infinite
                    NumberAnimation { target: caret; property: "opacity"; to: 0.15; duration: 620; easing.type: Easing.InOutSine }
                    NumberAnimation { target: caret; property: "opacity"; to: 1.0;  duration: 620; easing.type: Easing.InOutSine }
                }
            }
        }

        // ── the one line that answers back ──────────────────────────────────
        Meta {
            id: status
            x: root.m
            anchors.baseline: statusRef.baseline
            text: root.notice !== "" ? root.notice
                : (root.failing ? "INCORRECT" : (root.capsOn ? "CAPS LOCK" : ""))
            color: root.failing ? pal.error : pal.line
        }

        // ── greeter-only controls ───────────────────────────────────────────
        // The lock screen belongs to a session that is already running and needs
        // none of this; a real greeter has no other way to power the machine off.
        Row {
            visible: !root.underQylock
            anchors.right: parent.right
            anchors.rightMargin: root.m - root.metaTrack
            y: root.statusY - metaFM.ascent
            spacing: root.m
            opacity: root.metaT
            PowerAction { label: "Suspend";   confirms: false; onTriggered: if (root.hasSddm) sddm.suspend() }
            PowerAction { label: "Restart";   onTriggered: if (root.hasSddm) sddm.reboot() }
            PowerAction { label: "Shut Down"; onTriggered: if (root.hasSddm) sddm.powerOff() }
        }
    }

    // ── focus, taken late and taken back ────────────────────────────────────
    // The host focuses the loaded item, not the input inside it, and the surface
    // can appear after this tree is built.
    Timer { interval: 250; running: true; onTriggered: pw.forceActiveFocus() }
    Connections {
        target: pw
        function onActiveFocusChanged() { if (!pw.activeFocus) refocus.restart() }
    }
    Timer { id: refocus; interval: 60; onTriggered: pw.forceActiveFocus() }

    // ── the two styles on the page ──────────────────────────────────────────
    component Numeral: Text {
        color: pal.fg
        font.family: root.displayFamily
        font.weight: Font.Thin
        font.pixelSize: root.clockSize
        font.letterSpacing: root.clockSize * root.track
        opacity: root.clockT
        transform: Translate { y: (1 - root.clockT) * 20 * root.s }
    }

    component Meta: Text {
        font.family: root.metaFamily
        font.weight: Font.Medium
        font.pixelSize: root.metaSize
        font.letterSpacing: root.metaTrack
        color: pal.dim
        opacity: root.metaT
        renderType: Text.NativeRendering
    }

    component PowerAction: Item {
        id: act
        property string label: ""
        property bool confirms: true
        property bool armed: false
        signal triggered()
        width: t.implicitWidth
        height: metaFM.height
        Meta {
            id: t
            anchors.top: parent.top
            opacity: 1
            text: (act.armed ? "confirm" : act.label).toUpperCase()
            color: act.armed ? pal.error : (ma.containsMouse ? pal.fg : pal.line)
            Behavior on color { ColorAnimation { duration: 160 } }
        }
        Timer { id: disarm; interval: 3000; onTriggered: act.armed = false }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            // powering the machine off is otherwise one stray click away, with no undo
            onClicked: {
                if (act.confirms && !act.armed) { act.armed = true; disarm.restart(); return }
                act.armed = false
                act.triggered()
            }
        }
    }
}
