/* InseiLiveHash.qml — Living Akashic Fingerprint
 * ================================================
 * 32-char stream split into 2 rows of 16.
 * Characters drawn from: binary, hex, runes, sigils, alchemical glyphs.
 * Locked chars crystallize in the active fold's color with glow.
 * Unlocked chars cascade through the full symbol set.
 * Groups of 4 separated by ·
 * Loading: all chars breathe in a sine wave.
 *
 * §14.8 — Cooperative + FBO, dirty-flag pattern.
 */
import QtQuick
import "../tw" as TW

Item {
    id: root

    property bool   active:      false
    property string password:    ""
    property real   entropy:     0.0
    property var    tappedFolds: []

    implicitWidth:  320
    implicitHeight: 32

    opacity: root.active ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 300 } }

    // ── Symbol pools — the living alphabet ───────────────────────────
    // Binary fragments
    readonly property var _binary: ["0","1","0","1","1","0","0","1","1","1","0","0","1","0","1","1"]
    // Hex
    readonly property var _hex: ["0","1","2","3","4","5","6","7","8","9","a","b","c","d","e","f"]
    // Elder Futhark runes
    readonly property var _runes: ["ᚠ","ᚢ","ᚦ","ᚨ","ᚱ","ᚲ","ᚷ","ᚹ","ᚺ","ᚾ","ᛁ","ᛃ","ᛇ","ᛈ","ᛉ","ᛊ","ᛏ","ᛒ","ᛖ","ᛗ","ᛚ","ᛜ","ᛞ","ᛟ"]
    // Alchemical / occult sigils
    readonly property var _sigils: ["◉","⊗","⚔","◈","☁","⬡","◌","⊕","∿","◆","⬟","⊘","⊛","⊜","⊝","⊞"]
    // Mathematical / esoteric
    readonly property var _math: ["∞","∂","∇","∆","∑","∏","√","∫","≈","≠","≡","∈","∉","∅","⊂","⊃"]
    // Braille fragments
    readonly property var _braille: ["⠁","⠃","⠉","⠙","⠑","⠋","⠛","⠓","⠊","⠚","⠅","⠇","⠍","⠝","⠕","⠏"]

    // Full living alphabet — all pools merged
    readonly property var _alphabet: _binary.concat(_hex).concat(_runes).concat(_sigils).concat(_math).concat(_braille)

    // Canonical fold colors
    readonly property var _foldColors: ({
        "truth":      "#4ade80",
        "power":      "#f43f5e",
        "wisdom":     "#00B4D8",
        "judgment":   "#9B1FA0",
        "life":       "#818cf8",
        "love":       "#f59e0b",
        "discipline": "#6366f1"
    })

    // Per-position fold color — each locked char uses the color of the fold that locked it
    readonly property var _charColors: {
        var colors = []
        var folds = root.tappedFolds
        var locked = root._lockedChars
        // Distribute locked chars across tapped folds proportionally
        for (var i = 0; i < 32; i++) {
            if (i < locked && folds.length > 0) {
                var foldIdx = Math.floor(i / Math.max(1, locked / folds.length))
                foldIdx = Math.min(foldIdx, folds.length - 1)
                var hex = _foldColors[folds[foldIdx]]
                colors.push(hex ? Qt.color(hex) : TW.TransparentWorld.accentWater)
            } else {
                colors.push(TW.TransparentWorld.accentWater)
            }
        }
        return colors
    }

    // ── Scramble state ────────────────────────────────────────────────
    property var    _stream:    []   // current 32 chars
    property bool   _dirty:     false
    property real   _loadPulse: 0.0
    property real   _glowPulse: 0.0

    readonly property int _lockedChars: Math.round(root.entropy * 32)
    readonly property var _lockedStream: {
        if (root.password.length === 0) return []
        var result = []
        for (var i = 0; i < 32; i++) {
            // Deterministic char from password — always the same for same password
            var code = 0
            for (var j = 0; j < root.password.length; j++)
                code = (code * 31 + root.password.charCodeAt(j) + i * 13) & 0xFFFF
            var pool = i % 4 === 0 ? root._runes
                     : i % 4 === 1 ? root._sigils
                     : i % 4 === 2 ? root._hex
                     : root._math
            result.push(pool[code % pool.length])
        }
        return result
    }

    // Continuous glow pulse
    NumberAnimation on _glowPulse {
        from: 0; to: Math.PI * 2; duration: 2400
        loops: Animation.Infinite; running: root.active
    }

    // Load pulse (faster)
    NumberAnimation on _loadPulse {
        from: 0; to: Math.PI * 2; duration: 900
        loops: Animation.Infinite; running: root.active
    }

    // Living scramble — cycles through all symbol pools
    Timer {
        interval: 60
        running:  root.active
        repeat:   true
        onTriggered: {
            var locked = root._lockedChars
            var s = root._stream.slice()
            while (s.length < 32) s.push("0")

            for (var i = 0; i < 32; i++) {
                if (i < locked) {
                    // Locked — use deterministic char from password
                    s[i] = root._lockedStream[i] || "◉"
                } else {
                    // Living — cycle through full alphabet with time offset
                    var t = Date.now() / 80 + i * 7.3
                    var idx = Math.floor(t) % root._alphabet.length
                    s[i] = root._alphabet[idx]
                }
            }
            root._stream = s
            root._dirty  = true
        }
    }

    // Repaint throttle
    Timer {
        interval: 33
        running:  root.active
        repeat:   true
        onTriggered: {
            if (root._dirty) { root._dirty = false; _canvas.requestPaint() }
        }
    }

    on_LockedCharsChanged:    { root._dirty = true }
    onActiveChanged:          { root._dirty = true }
    on_GlowPulseChanged:      { if (root.active) root._dirty = true }

    // ── Canvas ────────────────────────────────────────────────────────
    Canvas {
        id: _canvas
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        renderTarget:   Canvas.FramebufferObject

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            var stream  = root._stream
            if (stream.length === 0) return

            var locked  = root._lockedChars
            var aw      = TW.TransparentWorld.accentWater
            var rowH    = height / 2
            var charW   = width / 18.5
            var groupW  = charW * 4.6

            ctx.textBaseline = "middle"

            for (var row = 0; row < 2; row++) {
                var base = row * 16
                var y    = rowH * row + rowH / 2

                for (var col = 0; col < 16; col++) {
                    var i   = base + col
                    var ch  = i < stream.length ? stream[i] : "·"
                    var grp = Math.floor(col / 4)
                    var x   = grp * groupW + (col % 4) * charW + charW * 0.1

                    if (i < locked) {
                        // Locked — fold color + glow pulse
                        var fc  = root._charColors[i]
                        var glow = 0.75 + 0.20 * Math.sin(root._glowPulse + i * 0.4)
                        ctx.font = "bold 10px '3270 Nerd Font Mono', monospace"
                        ctx.fillStyle = Qt.rgba(fc.r, fc.g, fc.b, glow)

                        // Glow halo — draw twice, second pass slightly larger/dimmer
                        ctx.shadowColor = Qt.rgba(fc.r, fc.g, fc.b, 0.55)
                        ctx.shadowBlur  = 4
                        ctx.fillText(ch, x, y)
                        ctx.shadowBlur  = 0
                    } else if (root.entropy < 0.05) {
                        // Loading — breathe in unison
                        var pulse = 0.10 + 0.10 * Math.sin(root._loadPulse + col * 0.5)
                        ctx.font = "9px '3270 Nerd Font Mono', monospace"
                        ctx.fillStyle = Qt.rgba(aw.r, aw.g, aw.b, pulse)
                        ctx.fillText(ch, x, y)
                    } else {
                        // Living — cascade with position-staggered fade
                        var fade = 0.12 + 0.08 * Math.sin(root._glowPulse * 0.7 + i * 0.9)
                        ctx.font = "9px '3270 Nerd Font Mono', monospace"
                        ctx.fillStyle = Qt.rgba(aw.r, aw.g, aw.b, fade)
                        ctx.fillText(ch, x, y)
                    }
                }

                // Group separators
                for (var g = 1; g < 4; g++) {
                    var sx = g * groupW - charW * 0.5
                    ctx.font = "8px '3270 Nerd Font Mono', monospace"
                    ctx.fillStyle = Qt.rgba(aw.r, aw.g, aw.b, 0.10)
                    ctx.fillText("·", sx, y)
                }
            }
        }
    }
}
