import QtQuick
import QtQuick.Window
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects
import Qt.labs.folderlistmodel

Rectangle {
    id: root

    // Wayland Cursor Fix
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.ArrowCursor
        z: -1
    }

    // ── sizing ──────────────────────────────────────────────────────────────
    // Parent-relative, not Screen-relative: under a real SDDM greeter the root
    // has no parent and Screen is the right answer, but under the lock (and one
    // surface per output) the parent is the only thing that knows this
    // monitor's size. Every dimension below is "pixels at 768p" times s.
    width: parent ? parent.width : Screen.width
    height: parent ? parent.height : Screen.height
    readonly property real s: height / 768
    color: pal.bg

    focus: true
    Keys.onEscapePressed: (e) => { pw.text = ""; root.errorText = ""; pw.forceActiveFocus(); e.accepted = true }

    // ── host detection ──────────────────────────────────────────────────────
    // fingerprintHint exists only on the lock shim; under a real greeter it is
    // undefined, so every qylock-only branch below evaluates false there.
    readonly property bool hasSddm: typeof sddm !== "undefined"
    readonly property bool underQylock: root.hasSddm && sddm.fingerprintHint === true

    // ── config (every value arrives as a STRING) ─────────────────────────────
    function cfgNum(key, def) {
        if (typeof config === "undefined" || config[key] === undefined) return def
        var v = parseFloat(config[key])
        return isNaN(v) ? def : v
    }
    readonly property real blurStrength: Math.max(0, Math.min(64, cfgNum("blurStrength", 64)))
    readonly property real cardOpacity: Math.max(0.02, Math.min(0.6, cfgNum("cardOpacity", 0.14)))
    readonly property real dimAmount: Math.max(0, Math.min(0.95, cfgNum("dimAmount", 0.58)))
    readonly property bool showSeconds: (typeof config !== "undefined") && config.showSeconds === "true"
    readonly property bool clock24h: (typeof config === "undefined") || config.clock24h !== "false"

    // ── palette ─────────────────────────────────────────────────────────────
    // Ryoku rewrites colors.json on every wallpaper change; the hard-coded
    // Rose Pine values below are what a non-Ryoku box (or a real SDDM greeter,
    // where file:// XHR is not allowed) falls back to.
    QtObject {
        id: pal
        property color bg:      "#191724"
        property color surface: "#26233a"
        property color fg:      "#e0def4"
        property color dim:     "#908caa"
        property color accent:  "#c4a7e7"
        property color accent2: "#9ccfd8"
        property color error:   "#eb6f92"
        property color shadow:  "#0d0b14"
    }

    readonly property string homeDir:
        "/home/" + ((typeof userModel !== "undefined" && userModel.lastUser) ? userModel.lastUser : "")

    // A theme must stay loadable by a real SDDM greeter, so no Quickshell.Io:
    // XHR on file:// is the only reader available. lock.sh sets
    // QML_XHR_ALLOW_FILE_READ=1; a real greeter does not, hence every read
    // degrades silently and leaves the fallback in place.
    function readFile(path, onOk) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            // a file:// read reports status 0 on success AND on failure; an
            // empty responseText is the only reliable "missing file" signal
            if ((xhr.status === 200 || xhr.status === 0) && xhr.responseText) {
                try { onOk(xhr.responseText) } catch (e) { }
            }
        }
        try { xhr.open("GET", "file://" + path, true); xhr.send() } catch (e) { }
    }

    function loadPalette() {
        readFile(root.homeDir + "/.cache/ryoku/colors.json", function(txt) {
            var o = JSON.parse(txt)
            if (o.background)       pal.bg = o.background
            if (o.surfaceContainer) pal.surface = o.surfaceContainer
            if (o.onSurface)        pal.fg = o.onSurface
            if (o.onSurfaceVariant) pal.dim = o.onSurfaceVariant
            if (o.primary)          pal.accent = o.primary
            if (o.secondary)        pal.accent2 = o.secondary
            if (o.error)            pal.error = o.error
            if (o.shadow)           pal.shadow = o.shadow
        })
    }

    // ── wallpaper resolution ────────────────────────────────────────────────
    // The active wallpaper may be a live one, in which case the state file
    // names an .mp4 that Image cannot open. Ryoku's frame extractor leaves
    // stills in ryoku-live-frames/, named after the video, so prefer a still
    // belonging to *this* video and fall back to the newest one.
    property string wpUrl: ""
    property string wpStem: ""
    property bool framesWanted: false
    readonly property bool wpReady: wpImg.status === Image.Ready

    function resolveWallpaper() {
        readFile(root.homeDir + "/.local/state/ryoku-wallpaper", function(txt) {
            var p = txt.split("\n")[0].trim()
            if (p === "") return
            if (/\.(mp4|webm|mkv|mov|avi|m4v)$/i.test(p)) {
                var base = p.substring(p.lastIndexOf("/") + 1)
                root.wpStem = base.substring(0, base.lastIndexOf("."))
                root.framesWanted = true
                root.pickFrame()
            } else {
                root.wpUrl = "file://" + p
            }
        })
    }

    function pickFrame() {
        if (!root.framesWanted || frames.count === 0) return
        var best = ""
        for (var i = 0; i < frames.count; i++) {
            var u = String(frames.get(i, "fileUrl"))
            // FolderListModel silently keeps scanning its default folder when
            // the one it was given does not exist, so never trust a row whose
            // path is not actually in the frame cache.
            if (u.indexOf("/ryoku-live-frames/") < 0) continue
            if (best === "") best = u   // rows are Time-sorted: newest first
            var fn = String(frames.get(i, "fileName"))
            if (root.wpStem !== "" && fn.indexOf(root.wpStem) === 0) { best = u; break }
        }
        if (best !== "") root.wpUrl = best
    }

    FolderListModel {
        id: frames
        folder: "file://" + root.homeDir + "/.local/state/ryoku-live-frames/"
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
        sortField: FolderListModel.Time
        showDirs: false
        onCountChanged: root.pickFrame()
    }

    // ── clock ───────────────────────────────────────────────────────────────
    property var now: new Date()
    Timer {
        interval: root.showSeconds ? 1000 : 15000
        repeat: true
        // Under the greeter a backgrounded window must not keep waking the CPU;
        // the lock shim only exists while the surface is up, so it always ticks.
        running: root.underQylock || Window.active
        onTriggered: root.now = new Date()
    }
    readonly property string clockText: Qt.formatDateTime(root.now,
        root.clock24h ? (root.showSeconds ? "HH:mm:ss" : "HH:mm")
                      : (root.showSeconds ? "h:mm:ss" : "h:mm"))
    readonly property string meridiem: root.clock24h ? "" : Qt.formatDateTime(root.now, "AP")

    readonly property string uiFamily: "Inter"
    readonly property string displayFamily: "Inter Display"

    // ── identity ────────────────────────────────────────────────────────────
    // The models are empty at Component.onCompleted and fill in a few hundred
    // ms later, so read them through a Repeater and keep lastUser as the
    // always-available fallback.
    Repeater {
        id: userScan
        model: (typeof userModel !== "undefined") ? userModel : null
        delegate: Item {
            property string login: model.name || ""
            property string pretty: model.realName || model.name || ""
        }
        onCountChanged: root.refreshName()
    }
    readonly property string loginName: (userScan.count > 0 && userScan.itemAt(0) && userScan.itemAt(0).login)
        ? userScan.itemAt(0).login
        : ((typeof userModel !== "undefined" && userModel.lastUser) ? userModel.lastUser : "user")
    property string displayName: ""
    readonly property string initial: root.displayName.length > 0 ? root.displayName.charAt(0).toUpperCase() : "?"
    function refreshName() {
        var n = (userScan.count > 0 && userScan.itemAt(0)) ? userScan.itemAt(0).pretty : ""
        if (n === "") n = root.loginName
        root.displayName = n.charAt(0).toUpperCase() + n.slice(1)
    }
    Timer { interval: 400; running: true; onTriggered: root.refreshName() }

    Repeater {
        id: sessionScan
        model: (typeof sessionModel !== "undefined") ? sessionModel : null
        delegate: Item { property string sName: model.name || "" }
    }

    // ── auth state ──────────────────────────────────────────────────────────
    property int sessionIndex: 0
    property bool busy: false
    property bool capsOn: false
    property bool errorMode: false
    property string errorText: ""

    function submit() {
        if (root.busy) return
        // SddmShim.login() returns without starting PAM on an empty password,
        // so nothing would ever answer and the busy state would never lift.
        if (pw.text.length === 0) { pw.forceActiveFocus(); return }
        root.busy = true
        root.errorText = ""
        root.errorMode = false
        if (root.hasSddm) sddm.login(root.loginName, pw.text, root.sessionIndex)
        watchdog.restart()
    }

    // Second line of defence for the cases where PAM answers with neither
    // signal (a wedged helper, a fingerprint scan that went nowhere).
    Timer {
        id: watchdog
        interval: 8000
        onTriggered: { root.busy = false; root.errorText = ""; pw.text = ""; pw.forceActiveFocus() }
    }

    Timer { id: errorHold; interval: 1200; onTriggered: root.errorMode = false }

    Connections {
        // informationMessage/errorMessage exist on a real greeter and not on
        // the shim, and surfaceRevealed the other way round: without
        // ignoreUnknownSignals this whole block errors out on one host or both.
        target: root.hasSddm ? sddm : null
        ignoreUnknownSignals: true

        function onSurfaceRevealed() { root.playIntro() }

        function onLoginFailed() {
            watchdog.stop()
            root.busy = false
            // clear the field first: onTextChanged retires the message, and
            // setting it before the clear would wipe it in the same tick
            pw.text = ""
            root.errorText = "WRONG PASSWORD"
            root.errorMode = true
            errorHold.restart()
            pw.forceActiveFocus()
            shake.restart()
        }

        function onLoginSucceeded() {
            watchdog.stop()
            errorHold.stop()
            root.busy = false
            root.errorMode = false
            unlockAnim.start()
        }

        function onInformationMessage(msg) { root.errorText = (msg || "").toUpperCase(); pw.forceActiveFocus() }
        function onErrorMessage(msg) { root.errorText = (msg || "").toUpperCase() }
    }

    // ── intro / outro ───────────────────────────────────────────────────────
    // introT and outroT are plain 0..1 drivers; every transform below is a
    // binding on them, so nothing has to know the screen size in advance
    // (root.width/height are still 0 during Component.onCompleted).
    property real introT: 0
    property real outroT: 0
    property bool introPlayed: false
    readonly property real hudOpacity: root.introT * (1 - root.outroT)

    NumberAnimation { id: introAnim; target: root; property: "introT"; to: 1; duration: 620; easing.type: Easing.OutCubic }
    ParallelAnimation {
        id: unlockAnim
        // The host quits ~100ms after loginSucceeded, so this is a flash that
        // gets cut off, not a curtain. Only the first frames of it are seen.
        NumberAnimation { target: root; property: "outroT"; to: 1; duration: 240; easing.type: Easing.InCubic }
        NumberAnimation { target: root; property: "blurNow"; to: 0; duration: 240; easing.type: Easing.OutCubic }
    }

    function playIntro() {
        if (root.introPlayed) return   // onSecureChanged can fire more than once
        root.introPlayed = true
        introAnim.start()
    }
    // surfaceRevealed never arrives under a real greeter, and not on the X11
    // path of the lock either; the timer is the fallback that always fires.
    Timer { id: introFallback; interval: 900; onTriggered: root.playIntro() }

    Component.onCompleted: {
        if (typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0)
            root.sessionIndex = sessionModel.lastIndex
        root.loadPalette()
        root.resolveWallpaper()
        introFallback.start()
    }

    // ── backdrop ────────────────────────────────────────────────────────────
    // Layer 1: a palette mesh, always painted, so a missing or unreadable
    // wallpaper is a living gradient and never a black screen.
    readonly property bool meshAwake: mesh.visible && (root.underQylock || Window.active)

    Item {
        anchors.fill: parent
        clip: true

        Canvas {
            id: mesh
            // Painted at a fraction of the screen and stretched back over it.
            // Radial gradients lose nothing to the interpolation, and it keeps
            // a full-screen software repaint off the animation path — at full
            // size this stalls the GUI thread for seconds on first paint.
            width: 384
            height: 216
            transformOrigin: Item.TopLeft
            scale: Math.max(root.width / width, root.height / height)
            visible: wpWrap.opacity < 0.995
            property real phase: 0
            property color cA: pal.accent
            property color cB: pal.accent2
            property color cC: pal.surface
            onCAChanged: requestPaint()
            onCBChanged: requestPaint()
            onCCChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var w = width, h = height
                var p = phase * 2 * Math.PI
                ctx.fillStyle = pal.bg
                ctx.fillRect(0, 0, w, h)
                function blob(cx, cy, r, c) {
                    var g = ctx.createRadialGradient(cx, cy, 0, cx, cy, r)
                    g.addColorStop(0.0, Qt.rgba(c.r, c.g, c.b, 0.95))
                    g.addColorStop(0.45, Qt.rgba(c.r, c.g, c.b, 0.40))
                    g.addColorStop(1.0, Qt.rgba(c.r, c.g, c.b, 0.0))
                    ctx.fillStyle = g
                    ctx.fillRect(0, 0, w, h)
                }
                blob(w * (0.26 + 0.07 * Math.sin(p)),        h * (0.22 + 0.06 * Math.cos(p * 0.8)), h * 1.05, cC)
                blob(w * (0.22 + 0.06 * Math.cos(p * 0.7)),  h * (0.28 + 0.08 * Math.sin(p * 1.1)), h * 0.85, cA)
                blob(w * (0.80 + 0.05 * Math.sin(p * 0.6)),  h * (0.76 + 0.06 * Math.cos(p)),       h * 0.80, cB)
            }
            // 20 fps is plenty for a drift this slow, and a wrapped phase can
            // never accumulate: the mesh looks the same after an hour.
            Timer {
                interval: 50
                repeat: true
                running: root.meshAwake
                onTriggered: { mesh.phase = (mesh.phase + 0.0007) % 1; mesh.requestPaint() }
            }
        }

        // Layer 2: the wallpaper. sourceSize is deliberately tiny — the decode
        // is downscaled and stretched back over the screen, which is a real
        // blur that survives the software renderer (and the theme preview).
        // FastBlur on top adds the GPU smear the glass wants.
        Item {
            id: wpWrap
            anchors.fill: parent
            opacity: root.wpReady ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 650; easing.type: Easing.OutCubic } }

            Image {
                id: wpImg
                anchors.fill: parent
                source: root.wpUrl
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                smooth: true
                sourceSize.width: Math.round(2100 / Math.max(8, root.blurStrength))
                // a wallpaper that vanished between the state file and here
                // must not strand a half-drawn screen
                onStatusChanged: if (status === Image.Error) root.wpUrl = ""
            }
            FastBlur {
                anchors.fill: wpImg
                source: wpImg
                radius: root.blurNow
                visible: wpImg.status === Image.Ready
            }
        }
    }

    // blurNow starts bound to the config value; unlockAnim overwrites that
    // binding on purpose, and nothing re-reads it afterwards.
    property real blurNow: root.blurStrength

    // Layer 3: the dim, lifted through the middle band so the card sits in the
    // brightest part of the frame.
    Rectangle {
        anchors.fill: parent
        opacity: root.dimAmount * (1 - root.outroT * 0.7)
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(pal.bg.r, pal.bg.g, pal.bg.b, 1.0) }
            GradientStop { position: 0.42; color: Qt.rgba(pal.bg.r, pal.bg.g, pal.bg.b, 0.78) }
            GradientStop { position: 1.0; color: Qt.rgba(pal.bg.r, pal.bg.g, pal.bg.b, 1.0) }
        }
    }

    // Layer 4: a cinematic vignette. Four gradient quads rather than a radial
    // Canvas: same read, none of the full-screen paint cost.
    Item {
        anchors.fill: parent
        opacity: 1 - root.outroT * 0.6
        Rectangle {
            width: parent.width; height: parent.height * 0.26
            anchors.top: parent.top
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(pal.bg.r, pal.bg.g, pal.bg.b, 0.55) }
                GradientStop { position: 1.0; color: Qt.rgba(pal.bg.r, pal.bg.g, pal.bg.b, 0.0) }
            }
        }
        Rectangle {
            width: parent.width; height: parent.height * 0.40
            anchors.bottom: parent.bottom
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(pal.bg.r, pal.bg.g, pal.bg.b, 0.0) }
                GradientStop { position: 1.0; color: Qt.rgba(pal.bg.r, pal.bg.g, pal.bg.b, 0.72) }
            }
        }
        Rectangle {
            width: parent.width * 0.22; height: parent.height
            anchors.left: parent.left
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(pal.bg.r, pal.bg.g, pal.bg.b, 0.50) }
                GradientStop { position: 1.0; color: Qt.rgba(pal.bg.r, pal.bg.g, pal.bg.b, 0.0) }
            }
        }
        Rectangle {
            width: parent.width * 0.22; height: parent.height
            anchors.right: parent.right
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(pal.bg.r, pal.bg.g, pal.bg.b, 0.0) }
                GradientStop { position: 1.0; color: Qt.rgba(pal.bg.r, pal.bg.g, pal.bg.b, 0.50) }
            }
        }
    }

    // ── the glass ───────────────────────────────────────────────────────────
    readonly property real cardW: 440 * s
    readonly property real cardPad: 40 * s

    Item {
        id: hud
        anchors.fill: parent
        opacity: root.hudOpacity

        Item {
            id: cardWrap
            width: root.cardW
            // hugs its content: the column's children size from the card's
            // width and from s, never from this height, so there is no loop.
            // The foot is shorter than the head because the status line
            // already carries empty space when there is nothing to say.
            height: stack.implicitHeight + root.cardPad + 20 * root.s
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            // Sit above optical centre: it balances the empty foot of the
            // frame and keeps the password pill clear of the fingerprint
            // overlay band the host draws at 0.60h.
            anchors.verticalCenterOffset: -0.045 * root.height
            transform: [
                Translate {
                    x: root.shakeX
                    y: (1 - root.introT) * 26 * root.s - root.outroT * 44 * root.s
                },
                Scale {
                    origin.x: cardWrap.width / 2
                    origin.y: cardWrap.height / 2
                    xScale: 0.975 + 0.025 * root.introT + 0.03 * root.outroT
                    yScale: 0.975 + 0.025 * root.introT + 0.03 * root.outroT
                }
            ]

            // Drop shadow. Canvas rather than DropShadow/MultiEffect, which
            // paint nothing off the GPU path, and painted at a quarter size
            // then scaled: a 46px blur upscales without any visible loss.
            Canvas {
                id: cardShadow
                readonly property real q: 0.25
                readonly property real pad: 100 * root.s
                anchors.centerIn: parent
                width: (parent.width + 2 * pad) * q
                height: (parent.height + 2 * pad) * q
                transformOrigin: Item.Center
                scale: 1 / q
                property color tint: pal.shadow
                onTintChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    var m = pad * q
                    ctx.shadowColor = Qt.rgba(tint.r, tint.g, tint.b, 0.70)
                    ctx.shadowBlur = 66 * root.s * q
                    ctx.shadowOffsetY = 26 * root.s * q
                    ctx.fillStyle = Qt.rgba(tint.r, tint.g, tint.b, 0.70)
                    ctx.beginPath()
                    ctx.roundedRect(m, m, width - 2 * m, height - 2 * m, 34 * root.s * q, 34 * root.s * q)
                    ctx.fill()
                }
            }

            Rectangle {
                id: card
                anchors.fill: parent
                radius: 34 * root.s
                border.width: Math.max(1, Math.round(root.s))
                border.color: Qt.rgba(pal.fg.r, pal.fg.g, pal.fg.b, 0.14)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(pal.fg.r, pal.fg.g, pal.fg.b, root.cardOpacity * 1.6) }
                    GradientStop { position: 0.55; color: Qt.rgba(pal.fg.r, pal.fg.g, pal.fg.b, root.cardOpacity * 0.85) }
                    GradientStop { position: 1.0; color: Qt.rgba(pal.fg.r, pal.fg.g, pal.fg.b, root.cardOpacity * 1.05) }
                }

                // A breath of the accent across the top of the glass; without
                // it a white wash over a grey backdrop reads as a grey box.
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(pal.accent.r, pal.accent.g, pal.accent.b, 0.15) }
                        GradientStop { position: 0.55; color: Qt.rgba(pal.accent2.r, pal.accent2.g, pal.accent2.b, 0.05) }
                        GradientStop { position: 1.0; color: Qt.rgba(pal.accent.r, pal.accent.g, pal.accent.b, 0.0) }
                    }
                }

                // Specular top edge: the one line that makes a flat translucent
                // rectangle read as glass rather than as a grey box.
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 1
                    width: parent.width - 68 * root.s
                    height: Math.max(1, Math.round(root.s))
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Qt.rgba(pal.fg.r, pal.fg.g, pal.fg.b, 0.0) }
                        GradientStop { position: 0.5; color: Qt.rgba(pal.fg.r, pal.fg.g, pal.fg.b, 0.58) }
                        GradientStop { position: 1.0; color: Qt.rgba(pal.fg.r, pal.fg.g, pal.fg.b, 0.0) }
                    }
                }

                Column {
                    id: stack
                    anchors.top: parent.top
                    anchors.topMargin: root.cardPad
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 2 * root.cardPad
                    spacing: 0

                    // clock
                    Item {
                        width: parent.width
                        height: 96 * root.s
                        Row {
                            anchors.centerIn: parent
                            spacing: 8 * root.s
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.clockText
                                color: pal.fg
                                font.family: root.displayFamily
                                font.pixelSize: 88 * root.s
                                font.weight: Font.DemiBold
                                font.letterSpacing: -2 * root.s
                            }
                            Text {
                                anchors.baseline: parent.children[0].baseline
                                visible: root.meridiem !== ""
                                text: root.meridiem
                                color: pal.dim
                                font.family: root.uiFamily
                                font.pixelSize: 18 * root.s
                                font.weight: Font.Medium
                                font.letterSpacing: 1 * root.s
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 20 * root.s
                        Text {
                            anchors.centerIn: parent
                            text: Qt.formatDate(root.now, "dddd d MMMM").toUpperCase()
                            color: pal.dim
                            font.family: root.uiFamily
                            font.pixelSize: 11 * root.s
                            font.weight: Font.Medium
                            font.letterSpacing: 4.5 * root.s
                        }
                    }

                    Item {
                        width: parent.width
                        height: 30 * root.s
                        Rectangle {
                            anchors.centerIn: parent
                            width: 64 * root.s
                            height: Math.max(1, Math.round(root.s))
                            color: Qt.rgba(pal.fg.r, pal.fg.g, pal.fg.b, 0.12)
                        }
                    }

                    // identity
                    Item {
                        width: parent.width
                        height: 46 * root.s
                        Row {
                            anchors.centerIn: parent
                            spacing: 13 * root.s
                            Rectangle {
                                width: 40 * root.s
                                height: 40 * root.s
                                radius: width / 2
                                anchors.verticalCenter: parent.verticalCenter
                                color: Qt.rgba(pal.accent.r, pal.accent.g, pal.accent.b, 0.16)
                                border.width: Math.max(1, Math.round(root.s))
                                border.color: Qt.rgba(pal.accent.r, pal.accent.g, pal.accent.b, 0.38)
                                Text {
                                    anchors.centerIn: parent
                                    text: root.initial
                                    color: pal.accent
                                    font.family: root.displayFamily
                                    font.pixelSize: 17 * root.s
                                    font.weight: Font.DemiBold
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.displayName
                                color: pal.fg
                                font.family: root.uiFamily
                                font.pixelSize: 16 * root.s
                                font.weight: Font.Medium
                                font.letterSpacing: 0.4 * root.s
                            }
                        }
                    }

                    Item { width: parent.width; height: 26 * root.s }

                    // ── the password pill ───────────────────────────────────
                    Item {
                        id: pillBox
                        width: parent.width
                        height: 54 * root.s

                        // Focus glow. Eight overlapping hairlines stand in for a
                        // real Glow, which paints nothing off the GPU path;
                        // three fat rings read as rings, these read as light.
                        Repeater {
                            model: 8
                            delegate: Rectangle {
                                required property int index
                                anchors.centerIn: pill
                                width: pill.width + (index + 1) * 4.6 * root.s
                                height: pill.height + (index + 1) * 4.6 * root.s
                                radius: height / 2
                                color: "transparent"
                                border.width: 2.8 * root.s
                                border.color: root.errorMode ? pal.error : pal.accent
                                opacity: (pw.activeFocus || root.errorMode)
                                    ? (root.errorMode ? 0.30 : 0.17) * Math.pow(1 - index / 8, 2.1)
                                    : 0
                                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                                Behavior on border.color { ColorAnimation { duration: 200 } }
                            }
                        }

                        Rectangle {
                            id: pill
                            anchors.fill: parent
                            radius: height / 2
                            color: Qt.rgba(pal.bg.r, pal.bg.g, pal.bg.b, 0.34)
                            border.width: Math.max(1, Math.round(root.s * 1.2))
                            border.color: root.errorMode ? pal.error
                                : (pw.activeFocus ? Qt.rgba(pal.accent.r, pal.accent.g, pal.accent.b, 0.85)
                                                  : Qt.rgba(pal.fg.r, pal.fg.g, pal.fg.b, 0.14))
                            Behavior on border.color { ColorAnimation { duration: 200 } }

                            // The real input, kept invisible: echoMode Password
                            // brings backspace, Ctrl+U, paste and onAccepted for
                            // free, while the dots below are drawn by hand.
                            TextInput {
                                id: pw
                                anchors.fill: parent
                                opacity: 0
                                echoMode: TextInput.Password
                                passwordMaskDelay: 0
                                readOnly: root.busy      // `enabled: false` would drop focus
                                focus: true
                                activeFocusOnTab: false
                                selectByMouse: false
                                cursorVisible: false
                                cursorDelegate: Item { width: 0; height: 0 }
                                onAccepted: root.submit()
                                onTextChanged: if (pw.text.length > 0 && root.errorText !== "") root.errorText = ""
                                // keyboard.capsLock is inert under the lock shim, so infer
                                // it: a letter arriving uppercase without Shift means caps.
                                Keys.onPressed: (e) => {
                                    if (e.text.length === 1 && e.text.toLowerCase() !== e.text.toUpperCase()) {
                                        var upper = (e.text === e.text.toUpperCase())
                                        var shift = (e.modifiers & Qt.ShiftModifier) !== 0
                                        root.capsOn = (upper && !shift) || (!upper && shift)
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: pw.text.length === 0
                                text: "ENTER PASSWORD"
                                color: pal.dim
                                font.family: root.uiFamily
                                font.pixelSize: 11 * root.s
                                font.weight: Font.Medium
                                font.letterSpacing: 3.4 * root.s
                                opacity: 0.88
                            }

                            Row {
                                id: dots
                                anchors.centerIn: parent
                                spacing: Math.round(9 * root.s)
                                opacity: root.busy ? 0.4 : 1
                                Behavior on opacity { NumberAnimation { duration: 220 } }
                                Repeater {
                                    // capped so a long passphrase can neither
                                    // reach the chevron nor spill out the ends
                                    model: Math.min(pw.text.length, 14)
                                    delegate: Rectangle {
                                        id: dot
                                        width: Math.round(9 * root.s)
                                        height: width
                                        radius: width / 2
                                        color: pal.fg
                                        scale: 0.2
                                        opacity: 0
                                        ParallelAnimation {
                                            id: pop
                                            running: true
                                            NumberAnimation { target: dot; property: "scale"; to: 1; duration: 340; easing.type: Easing.OutBack; easing.overshoot: 3.2 }
                                            NumberAnimation { target: dot; property: "opacity"; to: 1; duration: 160 }
                                        }
                                    }
                                }
                            }

                            // submit chevron
                            Item {
                                id: chev
                                width: 40 * root.s
                                height: parent.height
                                anchors.right: parent.right
                                anchors.rightMargin: 8 * root.s
                                opacity: pw.text.length > 0 ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                Shape {
                                    anchors.centerIn: parent
                                    width: 18 * root.s
                                    height: 18 * root.s
                                    antialiasing: true
                                    ShapePath {
                                        strokeColor: chevMa.containsMouse ? pal.fg : pal.accent
                                        strokeWidth: 2.4 * root.s
                                        fillColor: "transparent"
                                        capStyle: ShapePath.RoundCap
                                        joinStyle: ShapePath.RoundJoin
                                        startX: 6 * root.s; startY: 3 * root.s
                                        PathLine { x: 13 * root.s; y: 9 * root.s }
                                        PathLine { x: 6 * root.s; y: 15 * root.s }
                                    }
                                }
                                MouseArea {
                                    id: chevMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: pw.text.length > 0
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.submit()
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.rightMargin: 48 * root.s
                                cursorShape: Qt.ArrowCursor
                                onClicked: pw.forceActiveFocus()
                            }
                        }
                    }

                    // status line: the error wins, the caps hint fills in
                    Item {
                        width: parent.width
                        height: 36 * root.s
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            text: root.errorText !== "" ? root.errorText : (root.capsOn ? "CAPS LOCK" : "")
                            color: root.errorMode ? pal.error : pal.dim
                            Behavior on color { ColorAnimation { duration: 400 } }
                            font.family: root.uiFamily
                            font.pixelSize: 10 * root.s
                            font.weight: Font.Medium
                            font.letterSpacing: 3 * root.s
                            opacity: 0.95
                        }
                    }
                }
            }
        }

        // ── chrome ──────────────────────────────────────────────────────────
        Text {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 56 * root.s
            anchors.bottomMargin: 46 * root.s
            text: (root.hasSddm ? sddm.hostName : "").toUpperCase()
            color: pal.dim
            opacity: 0.6
            font.family: root.uiFamily
            font.pixelSize: 10 * root.s
            font.weight: Font.Medium
            font.letterSpacing: 4 * root.s
        }

        Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 56 * root.s
            anchors.bottomMargin: 42 * root.s
            spacing: 22 * root.s

            // Only a real greeter has more than one session to switch between;
            // the lock shim ignores sessionIndex entirely.
            AuroraAction {
                label: (sessionScan.count > 0 && sessionScan.itemAt(root.sessionIndex))
                    ? sessionScan.itemAt(root.sessionIndex).sName : "Session"
                visible: !root.underQylock && sessionScan.count > 1
                onTriggered: root.sessionIndex = (root.sessionIndex + 1) % sessionScan.count
            }
            AuroraAction { label: "Suspend";  onTriggered: if (root.hasSddm) sddm.suspend() }
            AuroraAction { label: "Restart";  onTriggered: if (root.hasSddm) sddm.reboot() }
            AuroraAction { label: "Shut down"; onTriggered: if (root.hasSddm) sddm.powerOff() }
        }
    }

    // ── shake ───────────────────────────────────────────────────────────────
    // A Translate, not an anchor margin: animating a margin would destroy its
    // binding to the centre offset above.
    property real shakeX: 0
    SequentialAnimation {
        id: shake
        NumberAnimation { target: root; property: "shakeX"; to: 13 * root.s; duration: 55; easing.type: Easing.OutSine }
        NumberAnimation { target: root; property: "shakeX"; to: -11 * root.s; duration: 65; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "shakeX"; to: 7 * root.s; duration: 60; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "shakeX"; to: 0; duration: 70; easing.type: Easing.OutSine }
    }

    // ── focus, taken late and re-taken whenever it is lost ───────────────────
    // The host force-focuses the loaded root, which is not the TextInput, and
    // the surface may arrive after the item is built; hence the late kick.
    Timer { interval: 250; running: true; onTriggered: pw.forceActiveFocus() }
    Timer { id: refocus; interval: 60; onTriggered: pw.forceActiveFocus() }
    Connections {
        target: pw
        function onActiveFocusChanged() { if (!pw.activeFocus) refocus.restart() }
    }

    // ── reusable pieces ─────────────────────────────────────────────────────
    component AuroraAction: Item {
        id: act
        property string label: ""
        signal triggered()
        width: actTxt.implicitWidth
        height: 18 * root.s
        Text {
            id: actTxt
            anchors.centerIn: parent
            text: act.label.toUpperCase()
            color: actMa.containsMouse ? pal.fg : pal.dim
            opacity: actMa.containsMouse ? 1.0 : 0.55
            font.family: root.uiFamily
            font.pixelSize: 10 * root.s
            font.weight: Font.Medium
            font.letterSpacing: 3 * root.s
            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on opacity { NumberAnimation { duration: 180 } }
        }
        MouseArea {
            id: actMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: act.triggered()
        }
    }
}
