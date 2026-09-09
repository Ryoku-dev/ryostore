import QtQuick
import QtQuick.Window
import QtQuick.Shapes
// Qt5Compat is namespaced: its RadialGradient would otherwise shadow the one
// from QtQuick.Shapes, which is the one this file wants.
import Qt5Compat.GraphicalEffects as FX

Rectangle {
    id: root

    // Sizing: parent-relative, because under a real SDDM greeter the root has no
    // parent (Screen is right there) while under the lock and the offscreen
    // renderer the parent is the true surface and Screen is not.
    width: parent ? parent.width : Screen.width
    height: parent ? parent.height : Screen.height
    readonly property real s: height / 768
    color: "#04000c"

    focus: true
    Keys.onEscapePressed: (e) => { pw.text = ""; pw.forceActiveFocus(); e.accepted = true }

    // Wayland cursor fix (orbital's idiom); also puts focus back after a stray click.
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.ArrowCursor
        z: -1
        onClicked: pw.forceActiveFocus()
    }

    // ── host detection ──────────────────────────────────────────────────────
    readonly property bool hasSddm: typeof sddm !== "undefined"
    // fingerprintHint is the documented discriminator: true under qylock,
    // undefined (falsy) under a real SDDM greeter.
    readonly property bool underQylock: root.hasSddm && sddm.fingerprintHint === true
    // Animations idle out when this surface cannot be seen. The qylock shim only
    // exists while the lock is up, so there it always runs.
    readonly property bool onScreen: root.underQylock || Window.active
    // The host stacks its own fingerprint overlay above every theme, so this
    // skin only adjusts its wording. Both properties are undefined under a real
    // SDDM greeter, which makes the whole thing evaluate false there.
    readonly property bool fpLive: root.underQylock && sddm.fingerprintReady === true
    readonly property bool fpScanning: root.fpLive && sddm.fingerprintState === "scanning"

    // ── config (every value arrives as a STRING) ────────────────────────────
    function num(v, d) { var n = parseFloat(v); return isNaN(n) ? d : n }
    readonly property real cfgGridSpeed: root.num(typeof config !== "undefined" ? config.gridSpeed : undefined, 1.0)
    readonly property real cfgScanline: root.num(typeof config !== "undefined" ? config.scanlineOpacity : undefined, 0.10)
    readonly property real cfgAberration: root.num(typeof config !== "undefined" ? config.aberration : undefined, 3.0)
    readonly property real cfgNeonHue: root.num(typeof config !== "undefined" ? config.neonHue : undefined, 315)
    readonly property bool cfg24h: (typeof config === "undefined") || config.clock24h !== "false"

    // ── palette ─────────────────────────────────────────────────────────────
    // This skin deliberately leaves the desktop palette behind, but Ryoku's
    // `primary` is mixed into the cool neon so the grid still belongs to this
    // machine when the wallpaper (and therefore the palette) changes.
    QtObject {
        id: pal
        property color primary: "#c4a7e7"
        property color error:   "#eb6f92"
    }
    readonly property string homeDir:
        "/home/" + ((typeof userModel !== "undefined" && userModel.lastUser) ? userModel.lastUser : "")

    function readJson(path, onOk) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            // a file:// read reports status 0 on success AND on failure; an empty
            // responseText is the only reliable "missing file" signal
            if ((xhr.status === 200 || xhr.status === 0) && xhr.responseText) {
                try { onOk(JSON.parse(xhr.responseText)) } catch (e) { /* keep fallback */ }
            }
        }
        try { xhr.open("GET", "file://" + path, true); xhr.send() } catch (e) { /* keep fallback */ }
    }

    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t, 1)
    }

    readonly property color neonHot: Qt.hsla((root.cfgNeonHue % 360) / 360, 0.92, 0.62, 1)
    readonly property color neonCool: Qt.hsla(((root.cfgNeonHue + 230) % 360) / 360, 0.88, 0.60, 1)
    readonly property color neonAmber: Qt.hsla(((root.cfgNeonHue + 105) % 360) / 360, 0.95, 0.60, 1)
    readonly property color neonViolet: Qt.hsla(((root.cfgNeonHue + 320) % 360) / 360, 0.85, 0.60, 1)
    readonly property color gridBase: root.mix(root.neonCool, pal.primary, 0.34)

    // Live colours: a failed password floods the neon red. Behaviors animate the
    // swap in both directions, so the settle is free.
    property color neonNow: root.failing ? "#ff2f3e" : root.neonHot
    Behavior on neonNow { ColorAnimation { duration: 130 } }
    property color gridNow: root.failing ? "#ff3a46" : root.gridBase
    Behavior on gridNow { ColorAnimation { duration: 130 } }

    // ── geometry of the world ───────────────────────────────────────────────
    readonly property real horizonY: Math.round(height * 0.615)
    readonly property real gridH: height - root.horizonY
    readonly property real sunR: height * 0.19
    readonly property real sunCy: root.horizonY - height * 0.028
    // Fraction of the disc that clears the horizon. The cutout bands are spread
    // across this visible part, not across the whole circle, or they would all
    // fall below the waterline.
    readonly property real sunCut: root.sunR > 0 ? (height * 0.028 + root.sunR) / (2 * root.sunR) : 0.5

    // ── clock ───────────────────────────────────────────────────────────────
    property var now: new Date()
    Timer {
        interval: 1000; repeat: true
        running: root.onScreen
        onTriggered: root.now = new Date()
    }

    FontLoader { id: displayFont; source: Qt.resolvedUrl("font/Outfit-Black.ttf") }
    // FontLoader.name is "" until the file is parsed; binding font.family to ""
    // silently gives you the default face for a frame or two.
    readonly property string displayFamily: displayFont.status === FontLoader.Ready ? displayFont.name : "Inter Display"
    readonly property string uiFamily: "Inter"

    // ── shared animation drivers ────────────────────────────────────────────
    // Everything that moves reads one of these four numbers. There is no
    // per-element timer anywhere in this file.
    property real gridPhase: 0     // 0..1, one perspective row
    property real gridRush: 0      // extra rows/second on unlock
    property real pulse: 0         // 0..1, the password slot's breath
    property real glitchX: 0       // horizontal displacement during a glitch
    property real tearAmt: 0       // 0..1, RGB tear bar visibility
    property real aberrBoost: 1    // aberration multiplier, spikes on failure

    NumberAnimation on gridPhase {
        running: root.onScreen
        loops: Animation.Infinite
        from: 0; to: 1
        duration: Math.max(600, 5200 / Math.max(0.15, root.cfgGridSpeed))
    }
    SequentialAnimation on pulse {
        running: root.onScreen
        loops: Animation.Infinite
        NumberAnimation { from: 0; to: 1; duration: 1250; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1; to: 0; duration: 1250; easing.type: Easing.InOutSine }
    }

    // ── perspective projection ──────────────────────────────────────────────
    // A ground plane seen by a camera at height e, focal f: a line at depth z
    // lands gridH/z below the horizon (K = f*e = gridH, so depth 1 is the bottom
    // edge). Rows sit at even depths, which is what makes the spacing compress
    // toward the horizon instead of being a stack of evenly spaced lines.
    // Scrolling is z_i(u=1) == z_(i+1)(u=0), so the loop is seamless.
    readonly property real gridStep: 0.34
    readonly property int gridRows: 42
    function rowDepth(i) {
        var u = 1 - ((root.gridPhase + root.gridRush) % 1)
        return (1 - root.gridStep) + root.gridStep * (i + u)
    }

    // ── auth state ──────────────────────────────────────────────────────────
    property int sessionIndex: 0
    property bool busy: false
    property bool failing: false
    property string errorText: ""
    property bool capsOn: false

    Repeater {
        id: userScan
        model: (typeof userModel !== "undefined") ? userModel : null
        delegate: Item {
            property string login: model.name || ""
            property string display: model.realName || model.name || ""
        }
    }
    // The models are empty at Component.onCompleted; lastUser is not.
    readonly property string loginName: (userScan.count > 0 && userScan.itemAt(0) && userScan.itemAt(0).login)
        ? userScan.itemAt(0).login
        : ((typeof userModel !== "undefined" && userModel.lastUser) ? userModel.lastUser : "user")
    property string displayName: ""
    function refreshName() {
        if (userScan.count > 0 && userScan.itemAt(0) && userScan.itemAt(0).display)
            root.displayName = userScan.itemAt(0).display
        else if (typeof userModel !== "undefined" && userModel.lastUser)
            root.displayName = userModel.lastUser
    }
    Timer { interval: 400; running: true; onTriggered: root.refreshName() }

    Repeater {
        id: sessionScan
        model: (typeof sessionModel !== "undefined") ? sessionModel : null
        delegate: Item { property string sName: model.name || "" }
    }

    function submit() {
        if (root.busy) return
        // PAM never answers an empty key (the shim returns before starting it),
        // so a spinner here would hang forever. Just take focus back.
        if (pw.text.length === 0) { root.errorText = ""; pw.forceActiveFocus(); return }
        root.busy = true
        root.errorText = ""
        if (root.hasSddm) sddm.login(root.loginName, pw.text, root.sessionIndex)
        watchdog.restart()
    }
    Timer {
        id: watchdog
        interval: 8000
        onTriggered: { root.busy = false; pw.text = ""; root.errorText = ""; pw.forceActiveFocus() }
    }

    Connections {
        target: (typeof sddm !== "undefined") ? sddm : null
        // informationMessage/errorMessage exist on a real greeter but not on the
        // qylock shim; surfaceRevealed is the other way round.
        ignoreUnknownSignals: true
        function onSurfaceRevealed() { root.playIntro() }
        function onLoginFailed() {
            watchdog.stop()
            bloomAnim.stop(); bloom.opacity = 0; root.gridRush = 0
            root.busy = false
            root.failing = true
            // clear the field BEFORE the message: pw.onTextChanged wipes
            // errorText, so the other order silently swallows the error
            pw.text = ""
            root.errorText = "ACCESS DENIED"
            pw.forceActiveFocus()
            glitchAnim.restart()
        }
        function onLoginSucceeded() {
            watchdog.stop()
            root.busy = false
            bloomAnim.start()
        }
        function onInformationMessage(msg) { root.errorText = (msg || "").toUpperCase(); pw.forceActiveFocus() }
        function onErrorMessage(msg) { root.errorText = (msg || "").toUpperCase() }
    }

    // ── intro / glitch / unlock ─────────────────────────────────────────────
    property real uiOpacity: 0
    property real crtOpen: 0.004      // vertical scale of the whole picture
    property bool introPlayed: false
    SequentialAnimation {
        id: introAnim
        // A CRT waking up: one bright line, then the picture unfolds from it.
        NumberAnimation { target: root; property: "uiOpacity"; to: 1; duration: 90 }
        PauseAnimation { duration: 60 }
        ParallelAnimation {
            NumberAnimation { target: root; property: "crtOpen"; to: 1; duration: 460; easing.type: Easing.OutCubic }
            NumberAnimation { target: crtFlash; property: "opacity"; to: 0; duration: 420; easing.type: Easing.OutQuad }
        }
    }
    function playIntro() {
        if (root.introPlayed) return   // onSecureChanged can fire more than once
        root.introPlayed = true
        introAnim.start()
    }
    // surfaceRevealed never arrives under a real greeter, and not on the X11
    // branch of the lock host either, so the intro also has a plain deadline.
    Timer { id: introFallback; interval: 900; onTriggered: root.playIntro() }

    function placeTears() {
        tear1.y = root.height * (0.05 + Math.random() * 0.85)
        tear2.y = root.height * (0.05 + Math.random() * 0.85)
        tear3.y = root.height * (0.05 + Math.random() * 0.85)
    }
    SequentialAnimation {
        id: glitchAnim
        ScriptAction { script: root.placeTears() }
        ParallelAnimation {
            NumberAnimation { target: root; property: "glitchX"; to: 17 * root.s; duration: 50 }
            NumberAnimation { target: root; property: "tearAmt"; to: 1; duration: 40 }
            NumberAnimation { target: root; property: "aberrBoost"; to: 7; duration: 50 }
        }
        ScriptAction { script: root.placeTears() }
        NumberAnimation { target: root; property: "glitchX"; to: -12 * root.s; duration: 55 }
        ScriptAction { script: root.placeTears() }
        NumberAnimation { target: root; property: "glitchX"; to: 7 * root.s; duration: 45 }
        ParallelAnimation {
            NumberAnimation { target: root; property: "glitchX"; to: 0; duration: 150; easing.type: Easing.OutBack }
            NumberAnimation { target: root; property: "tearAmt"; to: 0; duration: 160 }
            NumberAnimation { target: root; property: "aberrBoost"; to: 1; duration: 240 }
        }
        ScriptAction { script: root.failing = false }
    }

    // The host quits ~100ms after loginSucceeded for any pack that is not
    // clockwork+windup, so the bloom has to land inside that window; the grid
    // rush is the part that gets cut off, and that is fine.
    SequentialAnimation {
        id: bloomAnim
        ParallelAnimation {
            NumberAnimation { target: root; property: "gridRush"; to: 9; duration: 420; easing.type: Easing.InQuad }
            NumberAnimation { target: bloom; property: "opacity"; to: 1; duration: 110; easing.type: Easing.InQuad }
        }
    }

    Component.onCompleted: {
        if (typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0)
            root.sessionIndex = sessionModel.lastIndex
        root.readJson(root.homeDir + "/.cache/ryoku/colors.json", function(o) {
            if (o.primary) pal.primary = o.primary
            if (o.error) pal.error = o.error
        })
        introFallback.start()
    }

    // ════════════════════════════════════════════════════════════════════════
    // The picture
    // ════════════════════════════════════════════════════════════════════════
    Item {
        id: picture
        anchors.fill: parent
        opacity: root.uiOpacity
        transform: [
            Scale { origin.x: root.width / 2; origin.y: root.height / 2; yScale: root.crtOpen },
            Translate { x: root.glitchX }
        ]

        // ── sky ─────────────────────────────────────────────────────────────
        Rectangle {
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: parent.top
            height: root.horizonY
            gradient: Gradient {
                GradientStop { position: 0.0;  color: "#05000f" }
                GradientStop { position: 0.42; color: "#1b0538" }
                GradientStop { position: 0.78; color: "#3d0a55" }
                GradientStop { position: 1.0;  color: "#6b1064" }
            }
        }

        // Stars, seeded from a deterministic hash so they never re-scatter when a
        // binding re-evaluates.
        Item {
            anchors.fill: parent
            Repeater {
                model: 44
                delegate: Rectangle {
                    function h(k) { var x = Math.sin(k * 127.1 + 311.7) * 43758.5453; return x - Math.floor(x) }
                    width: 1 + h(index + 200) * 1.8 * root.s
                    height: width
                    radius: width / 2
                    color: "#ffffff"
                    x: h(index) * root.width
                    y: h(index + 100) * root.horizonY * 0.72
                    opacity: (0.25 + h(index + 300) * 0.65) * (1 - y / (root.horizonY * 0.85))
                }
            }
        }

        // ── the sun's atmosphere ────────────────────────────────────────────
        // A Shape radial gradient, not an image and not a blur effect: shader
        // based effects render as nothing in the offscreen preview.
        Shape {
            anchors.fill: parent
            antialiasing: true
            opacity: 0.85
            ShapePath {
                strokeWidth: -1
                fillGradient: RadialGradient {
                    centerX: root.width / 2; centerY: root.sunCy
                    centerRadius: root.sunR * 2.35
                    focalX: root.width / 2; focalY: root.sunCy
                    GradientStop { position: 0.0;  color: Qt.rgba(root.neonNow.r, root.neonNow.g, root.neonNow.b, 0.55) }
                    GradientStop { position: 0.35; color: Qt.rgba(root.neonNow.r, root.neonNow.g, root.neonNow.b, 0.22) }
                    GradientStop { position: 1.0;  color: Qt.rgba(root.neonNow.r, root.neonNow.g, root.neonNow.b, 0.0) }
                }
                startX: 0; startY: 0
                PathLine { x: root.width; y: 0 }
                PathLine { x: root.width; y: root.height }
                PathLine { x: 0; y: root.height }
            }
        }

        // ── the sun ─────────────────────────────────────────────────────────
        Item {
            id: sun
            width: root.sunR * 2
            height: root.horizonY - (root.sunCy - root.sunR)
            x: (root.width - width) / 2
            y: root.sunCy - root.sunR
            clip: true                          // the horizon cuts the disc
            readonly property real solidT: 0.30 // where the cutout bands begin

            // The unbroken cap is one rounded Rectangle, not a stack of bars:
            // bars wide enough to show a gap are also wide enough to turn the
            // fast-curving top of the circle into a visible staircase.
            Item {
                width: parent.width
                height: parent.width * sun.solidT
                clip: true
                Rectangle {
                    width: parent.width
                    height: parent.width
                    radius: width / 2
                    gradient: Gradient {
                        GradientStop { position: 0.0;  color: root.neonAmber }
                        GradientStop { position: 0.55; color: root.neonNow }
                        GradientStop { position: 1.0;  color: root.neonViolet }
                    }
                }
            }

            // Cutout bands. Each bar's half-width is sqrt(R^2 - dy^2), so the
            // slats follow the same circle the cap does; the gap widens toward
            // the horizon, which is where the eye expects the disc to dissolve.
            Repeater {
                model: 40
                delegate: Rectangle {
                    readonly property real slot: (root.sunR * 2) * (1 - sun.solidT) / 40
                    readonly property real y0: (root.sunR * 2) * sun.solidT + index * slot
                    readonly property real t: root.sunR > 0 ? y0 / (root.sunR * 2) : 0
                    readonly property real vis: Math.max(0, Math.min(1,
                        (t - sun.solidT) / Math.max(0.001, root.sunCut - sun.solidT)))
                    readonly property real dy: y0 + slot / 2 - root.sunR
                    width: 2 * Math.sqrt(Math.max(0, root.sunR * root.sunR - dy * dy))
                    height: Math.max(0.8, slot * (1 - Math.min(0.88, vis * 0.92)))
                    x: (parent.width - width) / 2
                    y: y0 + slot * Math.min(0.88, vis * 0.92) / 2
                    color: t < 0.55
                        ? root.mix(root.neonAmber, root.neonNow, t / 0.55)
                        : root.mix(root.neonNow, root.neonViolet, (t - 0.55) / 0.45)
                }
            }
        }

        // ── ground ──────────────────────────────────────────────────────────
        Rectangle {
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: parent.top; anchors.topMargin: root.horizonY
            height: root.gridH
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#22063f" }
                GradientStop { position: 0.5; color: "#10012a" }
                GradientStop { position: 1.0; color: "#05000f" }
            }
        }

        Item {
            id: grid
            x: 0; y: root.horizonY
            width: root.width; height: root.gridH
            clip: true

            // Vanishing lines. One Shape, one path: the ground's X grid projects
            // to a fan of straight lines from the vanishing point, evenly spaced
            // where they cross the near edge.
            function vpath() {
                var w = root.width, gh = root.gridH
                if (w <= 0 || gh <= 0) return ""
                var cx = w / 2, sp = w * 0.085, out = ""
                for (var j = -16; j <= 16; j++)
                    out += "M " + cx + ",0 L " + (cx + j * sp) + "," + gh + " "
                return out
            }
            Shape {
                anchors.fill: parent
                antialiasing: true
                opacity: 0.8
                ShapePath {
                    strokeColor: root.gridNow
                    strokeWidth: Math.max(1, 1.3 * root.s)
                    fillColor: "transparent"
                    capStyle: ShapePath.FlatCap
                    PathSvg { path: grid.vpath() }
                }
            }

            // Depth rows. Rectangles rather than Shapes: these are the only part
            // of the grid that moves, and 42 rebindings per frame is far cheaper
            // than rebuilding a path.
            Repeater {
                model: root.gridRows
                delegate: Rectangle {
                    readonly property real d: 1 / root.rowDepth(index)   // 0..1 of gridH
                    width: parent.width
                    height: Math.max(1, 3.0 * root.s * Math.pow(d, 0.8))
                    y: root.gridH * d - height
                    color: root.gridNow
                    opacity: 0.9 * Math.min(1, Math.max(0, (d - 0.07) / 0.13))
                }
            }

            // Haze: fades the near-horizon end of every grid line into the
            // ground instead of letting 33 strokes pile up on the vanishing point.
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right
                anchors.top: parent.top
                height: root.height * 0.075
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#22063f" }
                    GradientStop { position: 0.45; color: Qt.rgba(0.13, 0.02, 0.25, 0.6) }
                    GradientStop { position: 1.0; color: Qt.rgba(0.13, 0.02, 0.25, 0.0) }
                }
            }
        }

        // Horizon bloom. A radial gradient squashed into an ellipse around the
        // sun's foot, not a full-width band: an even strip of pink from bezel to
        // bezel looks like a painted stripe rather than light coming off a disc.
        Item {
            anchors.fill: parent
            transform: Scale { origin.x: root.width / 2; origin.y: root.horizonY; yScale: 0.20 }
            Shape {
                anchors.fill: parent
                antialiasing: true
                ShapePath {
                    strokeWidth: -1
                    fillGradient: RadialGradient {
                        centerX: root.width / 2; centerY: root.horizonY
                        centerRadius: root.width * 0.44
                        focalX: root.width / 2; focalY: root.horizonY
                        GradientStop { position: 0.0;  color: Qt.rgba(root.neonNow.r, root.neonNow.g, root.neonNow.b, 0.62) }
                        GradientStop { position: 0.45; color: Qt.rgba(root.neonNow.r, root.neonNow.g, root.neonNow.b, 0.26) }
                        GradientStop { position: 1.0;  color: Qt.rgba(root.neonNow.r, root.neonNow.g, root.neonNow.b, 0.0) }
                    }
                    // the path is deliberately taller than the screen: the Scale
                    // above shrinks it, and a screen-sized path would crop the bloom
                    startX: 0; startY: -root.height
                    PathLine { x: root.width; y: -root.height }
                    PathLine { x: root.width; y: 2 * root.height }
                    PathLine { x: 0; y: 2 * root.height }
                }
            }
        }
        // The horizon itself. It fades out sideways: a hard rule from bezel to
        // bezel reads as a UI divider, not as the edge of a world.
        Rectangle {
            width: parent.width
            height: Math.max(1, 1.6 * root.s)
            y: root.horizonY - height / 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0;  color: "#00ffffff" }
                GradientStop { position: 0.16; color: Qt.rgba(1, 1, 1, 0.42) }
                GradientStop { position: 0.5;  color: Qt.rgba(1, 1, 1, 0.95) }
                GradientStop { position: 0.84; color: Qt.rgba(1, 1, 1, 0.42) }
                GradientStop { position: 1.0;  color: "#00ffffff" }
            }
        }

        // Bloom behind the clock. The Glow below only paints on a real GPU
        // path, so the halo that carries the composition is a Shape gradient.
        Shape {
            anchors.fill: parent
            antialiasing: true
            ShapePath {
                strokeWidth: -1
                fillGradient: RadialGradient {
                    centerX: root.width / 2; centerY: root.height * 0.25
                    centerRadius: root.height * 0.27
                    focalX: root.width / 2; focalY: root.height * 0.25
                    GradientStop { position: 0.0; color: Qt.rgba(root.neonNow.r, root.neonNow.g, root.neonNow.b, 0.17) }
                    GradientStop { position: 0.6; color: Qt.rgba(root.neonNow.r, root.neonNow.g, root.neonNow.b, 0.07) }
                    GradientStop { position: 1.0; color: Qt.rgba(root.neonNow.r, root.neonNow.g, root.neonNow.b, 0.0) }
                }
                startX: 0; startY: 0
                PathLine { x: root.width; y: 0 }
                PathLine { x: root.width; y: root.height }
                PathLine { x: 0; y: root.height }
            }
        }

        // ════════════════════════════════════════════════════════════════════
        // HUD
        // ════════════════════════════════════════════════════════════════════

        // The grid is the loudest thing on screen and the login panel sits on
        // top of it. This is the pocket that gives the panel its contrast.
        Item {
            anchors.fill: parent
            transform: Scale { origin.x: root.width / 2; origin.y: root.height * 0.855; yScale: 0.26 }
            Shape {
                anchors.fill: parent
                antialiasing: true
                ShapePath {
                    strokeWidth: -1
                    fillGradient: RadialGradient {
                        centerX: root.width / 2; centerY: root.height * 0.855
                        centerRadius: root.width * 0.30
                        focalX: root.width / 2; focalY: root.height * 0.855
                        GradientStop { position: 0.0;  color: Qt.rgba(0.02, 0.0, 0.05, 0.72) }
                        GradientStop { position: 0.55; color: Qt.rgba(0.02, 0.0, 0.05, 0.38) }
                        GradientStop { position: 1.0;  color: Qt.rgba(0.02, 0.0, 0.05, 0.0) }
                    }
                    startX: 0; startY: -root.height
                    PathLine { x: root.width; y: -root.height }
                    PathLine { x: root.width; y: 2 * root.height }
                    PathLine { x: 0; y: 2 * root.height }
                }
            }
        }

        // ── header ──────────────────────────────────────────────────────────
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 56 * root.s
            anchors.top: parent.top
            anchors.topMargin: 40 * root.s
            spacing: 12 * root.s
            Rectangle {
                width: 6 * root.s; height: 6 * root.s
                anchors.verticalCenter: parent.verticalCenter
                color: root.neonNow
                rotation: 45
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                // hostName starts as "localhost" and is replaced asynchronously,
                // so bind to it rather than snapshotting it.
                text: (root.hasSddm && sddm.hostName ? sddm.hostName.toUpperCase() : "SYSTEM")
                font.family: root.uiFamily
                font.pixelSize: 11 * root.s
                font.letterSpacing: 5 * root.s
                font.weight: Font.Bold
                color: "#ffffff"
                opacity: 0.9
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "// LOCKED"
                font.family: root.uiFamily
                font.pixelSize: 11 * root.s
                font.letterSpacing: 4 * root.s
                color: root.gridNow
                opacity: 0.85
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 56 * root.s
            anchors.top: parent.top
            anchors.topMargin: 40 * root.s
            spacing: 24 * root.s
            NeonAction {
                label: sessionScan.count > 1 && sessionScan.itemAt(root.sessionIndex)
                    ? sessionScan.itemAt(root.sessionIndex).sName : "Session"
                visible: !root.underQylock && sessionScan.count > 1
                onTriggered: root.sessionIndex = (root.sessionIndex + 1) % sessionScan.count
            }
            NeonAction { label: "Suspend";  onTriggered: if (root.hasSddm) sddm.suspend() }
            NeonAction { label: "Reboot";   onTriggered: if (root.hasSddm) sddm.reboot() }
            NeonAction { label: "Shutdown"; onTriggered: if (root.hasSddm) sddm.powerOff() }
        }

        // ── date + clock ────────────────────────────────────────────────────
        Text {
            id: dateLine
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.height * 0.098
            text: Qt.formatDate(root.now, "ddd dd MMM yyyy").toUpperCase()
            font.family: root.uiFamily
            font.pixelSize: 13 * root.s
            font.letterSpacing: 9 * root.s
            color: root.mix(Qt.rgba(1, 1, 1, 1), root.gridNow, 0.55)
            opacity: 0.8
        }

        // Chromatic aberration: the same string three times, the cyan and hot
        // copies pushed apart by `aberration`, which the glitch multiplies.
        Item {
            id: clockGroup
            width: root.width
            height: clockWhite.implicitHeight
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.height * 0.255 - height / 2
            readonly property real a: root.cfgAberration * root.s * root.aberrBoost
            readonly property string t: Qt.formatDateTime(root.now, root.cfg24h ? "HH:mm" : "hh:mm")

            Text {
                x: -clockGroup.a; y: -clockGroup.a * 0.4; width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: clockGroup.t
                font.family: root.displayFamily
                font.pixelSize: 190 * root.s
                font.letterSpacing: -4 * root.s
                color: root.neonCool
            }
            Text {
                x: clockGroup.a; y: clockGroup.a * 0.4; width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: clockGroup.t
                font.family: root.displayFamily
                font.pixelSize: 190 * root.s
                font.letterSpacing: -4 * root.s
                color: root.neonNow
            }
            Text {
                id: clockWhite
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: clockGroup.t
                font.family: root.displayFamily
                font.pixelSize: 190 * root.s
                font.letterSpacing: -4 * root.s
                color: "#ffffff"
            }
        }
        FX.Glow {
            anchors.fill: clockGroup
            source: clockGroup
            radius: 20 * root.s
            samples: 17
            spread: 0.18
            color: root.neonNow
            opacity: 0.55
            transparentBorder: true
        }

        // ── login ───────────────────────────────────────────────────────────
        Column {
            id: panel
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.height * 0.795
            width: 420 * root.s
            spacing: 12 * root.s

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.displayName.toUpperCase()
                font.family: root.uiFamily
                font.pixelSize: 12 * root.s
                font.letterSpacing: 7 * root.s
                font.weight: Font.Medium
                color: "#ffffff"
                // the grid runs straight under this line; an outline is cheaper
                // and sharper than a scrim plate
                style: Text.Outline
                styleColor: Qt.rgba(0, 0, 0, 0.7)
                opacity: 0.85
            }

            Item {
                width: parent.width
                height: 54 * root.s

                // Outer glow, breathing on the shared pulse. Eight contiguous
                // rules with a quadratic falloff: a real blur is shader work and
                // renders as nothing off the GPU path, this does not.
                Repeater {
                    model: 8
                    delegate: Rectangle {
                        anchors.centerIn: parent
                        readonly property real g: (2 + index * 2.4) * root.s + 5 * root.s * root.pulse
                        width: parent.width + g * 2
                        height: parent.height + g * 2
                        radius: 3 * root.s + g
                        color: "transparent"
                        border.width: Math.max(1, 2.6 * root.s)
                        border.color: root.neonNow
                        opacity: 0.30 * Math.pow(1 - index / 8, 1.9) * (0.55 + 0.45 * root.pulse)
                    }
                }

                Rectangle {
                    id: slot
                    anchors.fill: parent
                    radius: 3 * root.s
                    color: Qt.rgba(0.03, 0.0, 0.09, 0.72)
                    border.width: Math.max(1, 2.0 * root.s)
                    border.color: root.neonNow

                    // bright inner rule, the "tube" of the neon
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 3 * root.s
                        radius: 2 * root.s
                        color: "transparent"
                        border.width: 1
                        border.color: "#ffffff"
                        opacity: 0.34 + 0.26 * root.pulse
                    }

                    TextInput {
                        id: pw
                        anchors.fill: parent
                        anchors.leftMargin: 18 * root.s
                        anchors.rightMargin: 18 * root.s
                        echoMode: TextInput.Password
                        passwordCharacter: "*"
                        passwordMaskDelay: 0
                        // readOnly, not `enabled: false`: disabling drops active focus.
                        readOnly: root.busy
                        focus: true
                        activeFocusOnTab: false
                        selectByMouse: false
                        // the characters are drawn as blocks below; this is the
                        // real field, kept invisible so Qt still owns editing
                        color: "transparent"
                        cursorVisible: false
                        cursorDelegate: Item { width: 0; height: 0 }
                        font.family: root.uiFamily
                        font.pixelSize: 15 * root.s
                        onAccepted: root.submit()      // Return AND numpad Enter
                        onTextChanged: if (root.errorText !== "") root.errorText = ""

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

                    Row {
                        anchors.centerIn: parent
                        spacing: 6 * root.s
                        Repeater {
                            model: Math.min(pw.text.length, 22)
                            delegate: Rectangle {
                                width: 9 * root.s
                                height: 24 * root.s
                                color: root.neonNow
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 2 * root.s
                                    color: "#ffffff"
                                    opacity: 0.55
                                }
                                NumberAnimation on scale { from: 0.25; to: 1; duration: 110; easing.type: Easing.OutBack }
                            }
                        }
                        // narrower than a character block on purpose: a caret
                        // the same size as a block reads as an unlit character
                        Rectangle {
                            id: caret
                            width: 3.5 * root.s
                            height: 24 * root.s
                            color: "#ffffff"
                            visible: pw.activeFocus && !root.busy
                            SequentialAnimation on opacity {
                                running: caret.visible && root.onScreen
                                loops: Animation.Infinite
                                NumberAnimation { from: 0.95; to: 0.08; duration: 520 }
                                NumberAnimation { from: 0.08; to: 0.95; duration: 520 }
                            }
                        }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                height: 16 * root.s
                text: root.errorText !== "" ? root.errorText
                    : (root.fpScanning ? "SCANNING"
                    : (root.capsOn ? "CAPS LOCK"
                    : (pw.text.length === 0
                        ? (root.fpLive ? "TYPE OR TOUCH THE SENSOR" : "TYPE TO UNLOCK")
                        : "")))
                font.family: root.uiFamily
                font.pixelSize: 12 * root.s
                font.letterSpacing: 4 * root.s
                font.weight: root.errorText !== "" ? Font.Bold : Font.Normal
                color: root.errorText !== "" ? "#ff5566" : (root.capsOn ? root.neonAmber : "#ffffff")
                style: Text.Outline
                styleColor: Qt.rgba(0, 0, 0, 0.7)
                opacity: root.errorText !== "" ? 1.0 : 0.55
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // CRT layer: scanlines, the tracking wobble, the tears, the vignette
    // ════════════════════════════════════════════════════════════════════════
    Item {
        id: crt
        anchors.fill: parent
        opacity: root.uiOpacity

        Item {
            anchors.fill: parent
            opacity: root.cfgScanline
            Repeater {
                // Pitch is in device pixels scaled by s so the texture reads the
                // same on a 1080p panel and on this machine's 1600p one.
                model: Math.max(0, Math.floor(root.height / Math.max(3, Math.round(3.0 * root.s))))
                delegate: Rectangle {
                    readonly property real pitch: Math.max(3, Math.round(3.0 * root.s))
                    width: root.width
                    height: pitch * 0.45
                    y: index * pitch
                    color: "#000000"
                }
            }
        }

        // VHS tracking wobble: one NumberAnimation, 8s top to bottom.
        Rectangle {
            id: roll
            width: parent.width
            height: root.height * 0.22
            gradient: Gradient {
                GradientStop { position: 0.0;  color: "#00ffffff" }
                GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0.075) }
                GradientStop { position: 0.55; color: Qt.rgba(1, 1, 1, 0.10) }
                GradientStop { position: 1.0;  color: "#00ffffff" }
            }
            NumberAnimation on y {
                running: root.onScreen
                loops: Animation.Infinite
                from: -root.height * 0.22; to: root.height
                duration: 8000
            }
        }

        // RGB tear bars, only alive during a glitch.
        Rectangle {
            id: tear1
            width: parent.width; height: 9 * root.s
            x: root.glitchX * 1.8
            opacity: root.tearAmt * 0.8
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0;  color: Qt.rgba(0, 1, 1, 0.85) }
                GradientStop { position: 0.45; color: "#00000000" }
                GradientStop { position: 1.0;  color: Qt.rgba(1, 0, 0.6, 0.85) }
            }
        }
        Rectangle {
            id: tear2
            width: parent.width; height: 20 * root.s
            x: -root.glitchX * 2.4
            opacity: root.tearAmt * 0.55
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0;  color: Qt.rgba(1, 0, 0.6, 0.8) }
                GradientStop { position: 0.6;  color: "#00000000" }
                GradientStop { position: 1.0;  color: Qt.rgba(0, 1, 1, 0.8) }
            }
        }
        Rectangle {
            id: tear3
            width: parent.width; height: 4 * root.s
            x: root.glitchX * 3.2
            opacity: root.tearAmt * 0.9
            color: "#ffffff"
        }

        // vignette
        Rectangle {
            width: parent.width; height: root.height * 0.26
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.55) }
                GradientStop { position: 1.0; color: "#00000000" }
            }
        }
        Rectangle {
            width: parent.width; height: root.height * 0.24
            y: root.height - height
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#00000000" }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.5) }
            }
        }
        Rectangle {
            width: root.width * 0.2; height: parent.height
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.45) }
                GradientStop { position: 1.0; color: "#00000000" }
            }
        }
        Rectangle {
            width: root.width * 0.2; height: parent.height
            x: root.width - width
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#00000000" }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.45) }
            }
        }
    }

    // The CRT power-on line, and the unlock bloom.
    Rectangle {
        id: crtFlash
        width: parent.width
        height: Math.max(2, 3 * root.s)
        y: root.height / 2 - height / 2
        color: "#ffffff"
        opacity: 1
    }
    Rectangle {
        id: bloom
        anchors.fill: parent
        color: "#ffffff"
        opacity: 0
    }

    // ── focus: taken late, and taken back whenever it is lost ───────────────
    Timer { interval: 250; running: true; onTriggered: pw.forceActiveFocus() }
    Connections {
        target: pw
        function onActiveFocusChanged() { if (!pw.activeFocus) refocus.restart() }
    }
    Timer { id: refocus; interval: 60; onTriggered: pw.forceActiveFocus() }

    component NeonAction: Item {
        id: act
        property string label: ""
        signal triggered()
        width: visible ? t.implicitWidth : 0
        height: 16 * root.s
        Text {
            id: t
            anchors.centerIn: parent
            text: act.label.toUpperCase()
            font.family: root.uiFamily
            font.pixelSize: 10 * root.s
            font.letterSpacing: 4 * root.s
            color: ma.containsMouse ? root.neonNow : "#ffffff"
            opacity: ma.containsMouse ? 1.0 : 0.58
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: act.triggered()
        }
    }
}
