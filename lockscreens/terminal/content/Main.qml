import QtQuick
import QtQuick.Window

Rectangle {
    id: root

    // Parent-relative sizing: under the lock (and the offscreen harness) the
    // theme is parented to an item the size of the output; under a real SDDM
    // greeter the root has no parent and Screen is the only answer.
    width: parent ? parent.width : Screen.width
    height: parent ? parent.height : Screen.height
    readonly property real s: height / 768

    // A console is black. The palette tints the ink, never the ground.
    color: "#000000"

    focus: true
    // Escape is ignored by TextInput and bubbles up to here, so the clear lives
    // on the root rather than on the field.
    Keys.onEscapePressed: (e) => { root.clearInput(); e.accepted = true }
    Keys.onPressed: (e) => root.handleKey(e)

    // Wayland cursor fix (orbital's idiom)
    MouseArea { anchors.fill: parent; cursorShape: Qt.ArrowCursor; z: -1 }

    // ── host detection ──────────────────────────────────────────────────────
    readonly property bool hasSddm: typeof sddm !== "undefined"
    // fingerprintHint is the only member that exists under qylock and is
    // undefined under a real greeter, so it is the honest discriminator.
    readonly property bool underQylock: root.hasSddm && sddm.fingerprintHint === true
    // hostName starts at "localhost" and is replaced asynchronously from
    // /etc/hostname, so this is a binding and never a snapshot.
    readonly property string hostName: (root.hasSddm && sddm.hostName) ? sddm.hostName : "localhost"

    // ── config (every value arrives as a STRING) ────────────────────────────
    readonly property bool echoAsterisk: (typeof config !== "undefined") && config.echoMode === "asterisk"
    readonly property int typeSpeed: {
        var v = (typeof config !== "undefined") ? parseInt(config.typeSpeed) : NaN
        return (isNaN(v) || v < 1) ? 18 : v
    }
    readonly property bool showScanlines: (typeof config === "undefined") || config.showScanlines !== "false"
    readonly property bool paletteInk: (typeof config === "undefined") || config.accentFromPalette !== "false"

    // ── ink ─────────────────────────────────────────────────────────────────
    // Defaults are the Rose Pine-ish set the Ryoku palette normally carries, so
    // the first frames already look right if the colors.json read is slow or
    // absent (a real SDDM greeter does not set QML_XHR_ALLOW_FILE_READ).
    QtObject {
        id: pal
        property color fg:     "#d6d2e4"
        property color dim:    "#8a85a3"
        property color faint:  "#5d5878"
        property color accent: "#c4a7e7"
        property color foam:   "#9ccfd8"
        property color ok:     "#4fd08a"
        property color err:    "#eb6f92"
    }

    readonly property string homeDir:
        "/home/" + ((typeof userModel !== "undefined" && userModel.lastUser) ? userModel.lastUser : "")

    function readJson(path, onOk) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            // a file:// read reports status 0 on success AND on failure; an
            // empty responseText is the only reliable "missing file" signal
            if ((xhr.status === 200 || xhr.status === 0) && xhr.responseText) {
                try { onOk(JSON.parse(xhr.responseText)) } catch (e) { /* keep fallback */ }
            }
        }
        try { xhr.open("GET", "file://" + path, true); xhr.send() } catch (e) { /* keep fallback */ }
    }

    // ── fonts ───────────────────────────────────────────────────────────────
    // A missing family falls back silently and would wreck the character grid
    // this whole skin is built on, so pick the first family that actually
    // exists instead of naming one and hoping.
    readonly property string monoFamily: {
        var want = ["Adwaita Mono", "FiraCode Nerd Font Mono", "Hack Nerd Font Mono", "DejaVu Sans Mono"]
        var have = Qt.fontFamilies()
        for (var i = 0; i < want.length; i++)
            if (have.indexOf(want[i]) >= 0) return want[i]
        return "monospace"
    }

    readonly property int fontPx: Math.round(16 * root.s)
    readonly property int lineH: Math.round(root.fontPx * 1.5)
    readonly property int clockPx: Math.round(34 * root.s)

    TextMetrics { id: cellM; font.family: root.monoFamily; font.pixelSize: root.fontPx; text: "0" }
    readonly property real charW: cellM.advanceWidth

    // The half-block clock only tiles seamlessly if the text line height equals
    // the ink height of the block glyph itself; the font's natural line spacing
    // leaves a hairline gap between rows.
    TextMetrics { id: blockM; font.family: root.monoFamily; font.pixelSize: root.clockPx; text: "█" }
    // floor, not round: a fractional gap between the rows shows up as a seam
    // straight through the middle of a solid stroke, an overlap never does.
    readonly property int blockH: blockM.tightBoundingRect.height > 3
        ? Math.floor(blockM.tightBoundingRect.height) - 1 : Math.round(root.clockPx)

    // ── clock ───────────────────────────────────────────────────────────────
    property var now: new Date()
    Timer {
        interval: 1000; repeat: true
        running: root.underQylock || Window.active
        onTriggered: root.now = new Date()
    }

    // 4x6 block-pixel digits. Two block rows are packed into one text row with
    // the half-block glyphs, because a monospace cell is about twice as tall as
    // it is wide and a one-row-per-block-row banner comes out spindly.
    readonly property var glyphs: ({
        "0": ["1111", "1001", "1001", "1001", "1001", "1111"],
        "1": ["0110", "1110", "0110", "0110", "0110", "1111"],
        "2": ["1111", "0001", "0001", "1111", "1000", "1111"],
        "3": ["1111", "0001", "0111", "0001", "0001", "1111"],
        "4": ["1001", "1001", "1001", "1111", "0001", "0001"],
        "5": ["1111", "1000", "1111", "0001", "0001", "1111"],
        "6": ["1111", "1000", "1111", "1001", "1001", "1111"],
        "7": ["1111", "0001", "0011", "0110", "0110", "0110"],
        "8": ["1111", "1001", "1111", "1001", "1001", "1111"],
        "9": ["1111", "1001", "1111", "0001", "0001", "1111"],
        ":": ["0", "1", "0", "0", "1", "0"]
    })

    function blockRow(str, r) {
        var out = ""
        for (var i = 0; i < str.length; i++) {
            var g = root.glyphs[str.charAt(i)]
            if (!g) continue
            var top = g[2 * r], bot = g[2 * r + 1]
            for (var c = 0; c < top.length; c++) {
                var t = top.charAt(c) === "1", b = bot.charAt(c) === "1"
                out += t ? (b ? "█" : "▀") : (b ? "▄" : " ")
            }
            if (i < str.length - 1) out += " "
        }
        return out
    }
    readonly property string clockStr: Qt.formatDateTime(root.now, "HH:mm")
    readonly property string clockArt:
        blockRow(root.clockStr, 0) + "\n" + blockRow(root.clockStr, 1) + "\n" + blockRow(root.clockStr, 2)

    // ── user ────────────────────────────────────────────────────────────────
    // The model rows are empty at Component.onCompleted and fill in later;
    // lastUser is a plain property and is right immediately.
    Repeater {
        id: userScan
        model: (typeof userModel !== "undefined") ? userModel : null
        delegate: Item { property string login: model.name || "" }
    }
    readonly property string loginName: (userScan.count > 0 && userScan.itemAt(0) && userScan.itemAt(0).login)
        ? userScan.itemAt(0).login
        : ((typeof userModel !== "undefined" && userModel.lastUser) ? userModel.lastUser : "user")
    readonly property string promptPrefix: root.loginName + "@" + root.hostName

    // ── the log ─────────────────────────────────────────────────────────────
    // Four coloured segments per line covers everything this skin prints:
    // "[  " + "OK" + "  ] " + body, and "" + "user@host" + ":~$ " + "".
    ListModel { id: log }
    property var pending: []          // queued line factories, evaluated at print time
    property int typingRow: -1        // the one row that is partially revealed
    property int typedChars: 0
    property bool typing: false
    property int promptRow: -1        // the live prompt, -1 while none is armed
    property int attempts: 0

    function row(o) {
        return {
            s1: o.s1 || "", s2: o.s2 || "", s3: o.s3 || "", s4: o.s4 || "",
            kind: o.kind || "plain",
            isPrompt: o.isPrompt === true,
            echo: "",
            pause: (o.pause !== undefined) ? o.pause : 110
        }
    }
    function okLine(body, pause) { return root.row({ s1: "[  ", s2: "OK", s3: "  ] ", s4: body, kind: "ok", pause: pause }) }
    function rowLen(i) {
        var r = log.get(i)
        if (!r) return 0
        var head = r.isPrompt ? root.promptPrefix.length : r.s2.length
        return r.s1.length + head + r.s3.length + r.s4.length
    }

    // Print with no typewriter. Used for everything the machine says *back* to
    // you (auth results, power confirmations): a real login prints those at
    // once, and after loginSucceeded there is no time to animate anyway.
    function printNow(r) {
        log.append(r)
        if (r.isPrompt) root.promptRow = log.count - 1
    }
    function queue(factory) { root.pending.push(factory) }

    function pumpNext() {
        if (root.typing) return
        if (root.pending.length === 0) return
        var r = root.pending.shift()()
        log.append(r)
        if (r.isPrompt) root.promptRow = log.count - 1
        root.typingRow = log.count - 1
        root.typedChars = 0
        root.typing = true
        typer.interval = root.typeSpeed
        typer.start()
    }

    Timer {
        id: typer
        repeat: true
        onTriggered: {
            var i = root.typingRow
            if (i < 0) { stop(); return }
            root.typedChars += 1
            if (root.typedChars >= root.rowLen(i)) {
                stop()
                root.typing = false
                root.typingRow = -1
                root.armCaret()
                gap.interval = log.get(i).pause
                gap.start()
            } else {
                // Cadence, not a metronome: characters off a real console arrive
                // in bursts, with the odd stall between them.
                typer.interval = Math.max(4, Math.round(
                    root.typeSpeed * (Math.random() < 0.04 ? 2.8 : (0.55 + Math.random() * 0.85))))
            }
        }
    }
    Timer { id: gap; onTriggered: root.pumpNext() }

    // Any keystroke dumps the rest of the boot log: the point of the animation
    // is the moment you glance at the screen, and it must never stand between
    // the user and the prompt.
    function fastForward() {
        if (!root.typing && root.pending.length === 0) return
        typer.stop(); gap.stop()
        root.typing = false
        root.typingRow = -1
        while (root.pending.length > 0) {
            var r = root.pending.shift()()
            log.append(r)
            if (r.isPrompt) root.promptRow = log.count - 1
        }
    }

    function newPrompt() {
        root.printNow(root.row({ s2: root.promptPrefix, s3: ":~$ ", isPrompt: true }))
        root.armCaret()
    }

    // ── auth ────────────────────────────────────────────────────────────────
    property int sessionIndex: 0
    property bool busy: false
    property bool unlocked: false

    readonly property string echoText: root.echoAsterisk ? "*".repeat(pw.text.length) : ""

    function clearInput() {
        pw.text = ""
        pw.forceActiveFocus()
    }

    function submit() {
        if (root.busy || root.unlocked) return
        root.fastForward()
        // PAM is never asked for an empty key (SddmShim.login returns without
        // emitting anything), so a spinner here would wait forever. Swallow it.
        if (pw.text.length === 0) { pw.forceActiveFocus(); return }
        // Freeze what the prompt line showed, then stop treating it as live.
        if (root.promptRow >= 0) {
            log.setProperty(root.promptRow, "echo", root.echoText)
            root.promptRow = -1
        }
        root.busy = true
        // The password is NOT cleared here: PAM may still ask for it.
        if (root.hasSddm) sddm.login(root.loginName, pw.text, root.sessionIndex)
        watchdog.restart()
    }

    Timer {
        id: watchdog
        interval: 8000
        onTriggered: {
            root.busy = false
            pw.text = ""
            root.printNow(root.row({ s4: "-- no answer from PAM, re-arming", kind: "dim" }))
            root.newPrompt()
            pw.forceActiveFocus()
        }
    }

    Connections {
        // informationMessage/errorMessage exist on a real greeter but not on the
        // qylock shim, and surfaceRevealed only on the shim: without
        // ignoreUnknownSignals this object errors out on one host or the other.
        target: (typeof sddm !== "undefined") ? sddm : null
        ignoreUnknownSignals: true

        function onSurfaceRevealed() { root.playIntro() }

        function onLoginFailed() {
            watchdog.stop()
            root.busy = false
            root.attempts += 1
            pw.text = ""
            // The log never resets: a failure is two more lines of history and
            // a fresh prompt underneath it.
            root.printNow(root.row({ s4: "Authentication failure (attempt " + root.attempts + ")", kind: "fail" }))
            root.newPrompt()
            pw.forceActiveFocus()
        }

        function onLoginSucceeded() {
            watchdog.stop()
            root.busy = false
            root.unlocked = true
            root.printNow(root.row({ s4: "Access granted.", kind: "good" }))
            // The host calls Qt.quit() 100ms after this signal for any pack that
            // is not clockwork, so the outro is a 90ms wipe, not a curtain.
            wipeAnim.start()
        }

        function onInformationMessage(msg) {
            if (msg) root.printNow(root.row({ s4: String(msg), kind: "dim" }))
            pw.forceActiveFocus()
        }
        function onErrorMessage(msg) {
            if (msg) root.printNow(root.row({ s4: String(msg), kind: "fail" }))
        }
    }

    // ── power keys ──────────────────────────────────────────────────────────
    // Under qylock these act immediately with no confirmation dialog, so
    // reboot and power off are armed once and fired on the second press.
    property string powerArm: ""
    Timer { id: powerDisarm; interval: 4000; onTriggered: root.powerArm = "" }

    function powerKey(what) {
        if (root.unlocked) return
        if (root.powerArm === what) {
            powerDisarm.stop()
            root.powerArm = ""
            root.printNow(root.row({ s4: "-- " + what + "...", kind: "dim" }))
            if (root.hasSddm) {
                if (what === "reboot") sddm.reboot()
                else if (what === "power off") sddm.powerOff()
            }
            return
        }
        root.powerArm = what
        powerDisarm.restart()
        root.printNow(root.row({ s4: "-- " + what + "? press the same key again to confirm", kind: "dim" }))
        root.newPrompt()
    }

    function handleKey(e) {
        if (root.unlocked) { e.accepted = true; return }
        root.fastForward()
        if (e.key === Qt.Key_F1) {
            e.accepted = true
            root.printNow(root.row({ s4: "-- suspending...", kind: "dim" }))
            if (root.hasSddm) sddm.suspend()
        } else if (e.key === Qt.Key_F2) {
            e.accepted = true; root.powerKey("reboot")
        } else if (e.key === Qt.Key_F3) {
            e.accepted = true; root.powerKey("power off")
        } else if (root.powerArm !== "") {
            root.powerArm = ""
            powerDisarm.stop()
        }
    }

    // ── intro ───────────────────────────────────────────────────────────────
    property real uiOpacity: 0
    property real clockRevealF: 0
    property bool introPlayed: false

    NumberAnimation { id: fadeIn; target: root; property: "uiOpacity"; to: 1; duration: 220; easing.type: Easing.OutCubic }
    NumberAnimation { id: clockWipe; target: root; property: "clockRevealF"; from: 0; to: 1; duration: 300; easing.type: Easing.OutCubic }
    Timer { id: bootStart; interval: 300; onTriggered: root.pumpNext() }

    function playIntro() {
        // onSecureChanged can fire more than once in a session.
        if (root.introPlayed) return
        root.introPlayed = true
        fadeIn.start()
        clockWipe.start()

        // Two lines are already on the screen when the lock paints: a console
        // that has been up for a while, not one that boots when you look at it.
        root.printNow(root.okLine("Started User Login Management."))
        root.printNow(root.okLine("Reached target Multi-User System."))

        root.queue(function() { return root.okLine("Reached target Graphical Interface.", 130) })
        root.queue(function() { return root.okLine("Started Ryoku Session Lock.", 200) })
        root.queue(function() {
            // Built here rather than up front so the timestamp is the moment the
            // line prints and hostName has had time to arrive from /etc/hostname.
            var t = new Date()
            return root.row({
                s4: root.hostName + " login: session locked at " + Qt.formatDateTime(t, "HH:mm:ss"),
                pause: 170
            })
        })
        root.queue(function() {
            return root.row({
                s4: root.echoAsterisk
                    ? "-- keystrokes echo as asterisks"
                    : "-- keystrokes are not echoed, like sudo",
                kind: "dim", pause: 80
            })
        })
        root.queue(function() {
            return root.row({ s4: "-- esc clears   f1 suspend   f2 reboot   f3 power off", kind: "dim", pause: 200 })
        })
        root.queue(function() {
            return root.row({ s2: root.promptPrefix, s3: ":~$ ", isPrompt: true, pause: 0 })
        })
        bootStart.start()
    }

    // surfaceRevealed never comes from a real SDDM greeter (and not from the
    // X11 branch of the lock host either), so the intro also has a timer.
    Timer { id: introFallback; interval: 900; onTriggered: root.playIntro() }

    Component.onCompleted: {
        if (typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0)
            root.sessionIndex = sessionModel.lastIndex
        if (root.paletteInk) {
            readJson(root.homeDir + "/.cache/ryoku/colors.json", function(o) {
                if (o.onSurface)        pal.fg = o.onSurface
                if (o.onSurfaceVariant) pal.dim = o.onSurfaceVariant
                if (o.outline)          pal.faint = o.outline
                if (o.primary)          pal.accent = o.primary
                if (o.secondary)        pal.foam = o.secondary
                if (o.error)            pal.err = o.error
                haze.requestPaint()
            })
        } else {
            // Single-phosphor console: one green, three brightnesses.
            pal.fg = "#8ce6b0"; pal.dim = "#4f9a72"; pal.faint = "#2f6249"
            pal.accent = "#8ce6b0"; pal.foam = "#8ce6b0"; pal.ok = "#8ce6b0"
        }
        introFallback.start()
    }

    // ── the screen ──────────────────────────────────────────────────────────
    readonly property int padX: Math.round(70 * root.s)
    readonly property int padY: Math.round(94 * root.s)

    // A wide, very soft phosphor bloom under the text. Real blur is a shader and
    // shaders do not survive the offscreen preview, so this is a Canvas gradient.
    Canvas {
        id: haze
        // fills the surface: a canvas smaller than the screen cuts the gradient
        // off while it is still faintly opaque, and that edge is visible
        anchors.fill: parent
        opacity: root.uiOpacity
        property color tint: pal.accent
        onTintChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var cx = width * 0.26, cy = height * 0.24, r = Math.max(width, height) * 0.78
            var g = ctx.createRadialGradient(cx, cy, 0, cx, cy, r)
            // 8-bit gradients band badly on near-black, so keep the peak low and
            // the falloff long
            g.addColorStop(0.0, Qt.rgba(tint.r, tint.g, tint.b, 0.036))
            g.addColorStop(0.35, Qt.rgba(tint.r, tint.g, tint.b, 0.022))
            g.addColorStop(0.7, Qt.rgba(tint.r, tint.g, tint.b, 0.008))
            g.addColorStop(1.0, Qt.rgba(tint.r, tint.g, tint.b, 0.0))
            ctx.fillStyle = g
            ctx.fillRect(0, 0, width, height)
        }
    }

    Item {
        id: viewport
        x: root.padX
        y: root.padY
        width: root.width - 2 * root.padX
        height: root.height - 2 * root.padY
        clip: true
        opacity: root.uiOpacity

        Column {
            id: doc
            width: parent.width
            // The log scrolls, it never resets: once the column is taller than
            // the viewport it rides up so the newest line stays visible.
            y: Math.min(0, viewport.height - doc.height)
            Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            // clock, top-left, part of the log rather than a widget beside it
            Item {
                id: clockArea
                width: doc.width
                height: clockBox.height + Math.round(10 * root.s)

                Item {
                    id: clockBox
                    width: clockText.implicitWidth
                    height: clockText.implicitHeight
                    Item {
                        width: parent.width
                        height: parent.height * root.clockRevealF
                        clip: true
                        Text {
                            id: clockText
                            text: root.clockArt
                            color: pal.fg
                            font.family: root.monoFamily
                            font.pixelSize: root.clockPx
                            lineHeightMode: Text.FixedHeight
                            lineHeight: root.blockH
                            // one pixel of overlap between cells: at a fractional
                            // advance the shared edge otherwise antialiases into a
                            // grid of hairlines across every solid stroke
                            font.letterSpacing: -1
                            renderType: Text.NativeRendering
                            style: Text.Outline
                            styleColor: Qt.rgba(pal.fg.r, pal.fg.g, pal.fg.b, 0.14)
                            topPadding: Math.round(root.clockPx * 0.28)
                        }
                    }
                }

                Column {
                    anchors.left: clockBox.right
                    anchors.leftMargin: Math.round(26 * root.s)
                    anchors.bottom: clockBox.bottom
                    anchors.bottomMargin: Math.round(root.clockPx * 0.10)
                    spacing: Math.round(4 * root.s)
                    opacity: root.clockRevealF
                    // same LineText as the log below, so the meta column sits on
                    // the same grid and carries the same bloom
                    LineText {
                        text: Qt.formatDate(root.now, "ddd dd MMM yyyy").toLowerCase()
                        color: pal.dim
                    }
                    LineText {
                        text: root.hostName + " tty1  " + Math.round(root.width) + "x" + Math.round(root.height)
                        color: pal.faint
                    }
                }
            }

            Item { width: 1; height: root.lineH }   // one blank console line

            Repeater {
                model: log
                delegate: Item {
                    id: lineItem
                    width: doc.width
                    height: root.lineH

                    // Everything except the row being typed is fully revealed.
                    readonly property int rev: (index === root.typingRow) ? root.typedChars : 1000000
                    readonly property bool isLive: model.isPrompt && index === root.promptRow
                    readonly property string t2: model.isPrompt ? root.promptPrefix : model.s2
                    readonly property int o2: model.s1.length
                    readonly property int o3: o2 + t2.length
                    readonly property int o4: o3 + model.s3.length
                    readonly property bool tail: index === log.count - 1

                    function cut(str, off) {
                        var n = lineItem.rev - off
                        if (n <= 0) return ""
                        return (n >= str.length) ? str : str.substring(0, n)
                    }

                    readonly property color inkHead: model.kind === "ok" ? pal.ok
                        : model.kind === "info" ? pal.foam
                        : model.kind === "fail" ? pal.err
                        : model.kind === "good" ? pal.ok
                        : model.isPrompt ? pal.accent : pal.fg
                    readonly property color inkBody: model.kind === "fail" ? pal.err
                        : model.kind === "good" ? pal.ok
                        : model.kind === "dim" ? pal.faint : pal.fg

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0

                        LineText { text: lineItem.cut(model.s1, 0);            color: pal.dim }
                        LineText { text: lineItem.cut(lineItem.t2, lineItem.o2); color: lineItem.inkHead }
                        LineText { text: lineItem.cut(model.s3, lineItem.o3);  color: pal.dim }
                        LineText { text: lineItem.cut(model.s4, lineItem.o4);  color: lineItem.inkBody }
                        LineText {
                            // the typed-in password, or the frozen copy of it
                            text: lineItem.rev < lineItem.o4 ? ""
                                : (lineItem.isLive ? root.echoText : model.echo)
                            color: pal.fg
                        }
                        Rectangle {
                            // block cursor: it lives at the tail of the log, so it
                            // follows the typewriter and then waits at the prompt
                            width: root.charW
                            height: Math.round(root.fontPx * 1.22)
                            color: pal.fg
                            visible: lineItem.tail && !root.unlocked
                            opacity: (root.typing || root.busy) ? 1 : (root.caretOn ? 1 : 0)
                        }
                    }
                }
            }
        }
    }

    property bool caretOn: true
    Timer {
        // the DEC/VT block cursor blinks at roughly 530ms
        id: blink
        interval: 530; repeat: true
        running: root.underQylock || Window.active
        onTriggered: root.caretOn = !root.caretOn
    }
    // Restart the phase whenever the cursor lands somewhere new, so it is always
    // lit for a full period first — a cursor that arrives mid-blink reads as lag.
    function armCaret() { root.caretOn = true; if (blink.running) blink.restart() }

    component LineText: Text {
        font.family: root.monoFamily
        font.pixelSize: root.fontPx
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        // Phosphor bloom. A real blur is a shader, and shaders come out blank in
        // the offscreen preview, so the halo is a translucent glyph outline: one
        // pixel of the ink's own colour, which is what the effect amounts to at
        // this size anyway.
        style: Text.Outline
        styleColor: Qt.rgba(color.r, color.g, color.b, 0.18)
    }

    // ── input sink ──────────────────────────────────────────────────────────
    // The field is invisible on purpose: what you see is drawn by the prompt
    // line. It is still a real TextInput, so Backspace, Ctrl+U, paste and
    // numpad Enter behave exactly as they do in a terminal, and Password mode
    // keeps the buffer off the clipboard.
    TextInput {
        id: pw
        width: 1; height: 1
        opacity: 0
        echoMode: TextInput.Password
        passwordMaskDelay: 0
        readOnly: root.busy || root.unlocked   // NOT `enabled`, which drops focus
        focus: true
        activeFocusOnTab: false
        selectByMouse: false
        cursorVisible: false
        onAccepted: root.submit()              // Return and numpad Enter both
        Keys.onPressed: (e) => {
            root.fastForward()
            // do not accept the event: the field still has to insert the char
        }
    }

    // Focus: the host force-focuses the loaded item, this hands it down to the
    // field, and the timer covers the case where the surface arrives late.
    Timer { interval: 250; running: true; onTriggered: pw.forceActiveFocus() }
    Timer { id: refocus; interval: 60; onTriggered: pw.forceActiveFocus() }
    Connections {
        target: pw
        function onActiveFocusChanged() { if (!pw.activeFocus && !root.unlocked) refocus.restart() }
    }

    // ── CRT overlay ─────────────────────────────────────────────────────────
    Canvas {
        id: scan
        anchors.fill: parent
        z: 40
        visible: root.showScanlines
        opacity: root.uiOpacity
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            // one dark line every third pixel at a tenth opacity: about 3% net,
            // invisible on the black ground and only felt across the glyphs
            var step = Math.max(3, Math.round(2.2 * root.s))
            ctx.fillStyle = "rgba(0,0,0,0.10)"
            for (var y = 0; y < height; y += step) ctx.fillRect(0, y, width, 1)
        }
    }

    // ── unlock wipe ─────────────────────────────────────────────────────────
    Rectangle {
        id: wipe
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: 0
        color: "#000000"
        z: 50
        Rectangle {
            anchors.right: parent.right
            width: Math.max(1, Math.round(2 * root.s))
            height: parent.height
            color: pal.ok
            opacity: 0.5
            visible: wipe.width > 0
        }
    }
    NumberAnimation {
        id: wipeAnim
        target: wipe; property: "width"
        from: 0; to: root.width
        duration: 90; easing.type: Easing.InQuad
    }
}
