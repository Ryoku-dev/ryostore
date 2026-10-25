/* InseiGotchi.qml — The Ase Companion & Tarot Gate · Holographic Scene
 * ============================================================
 * Ase floats in open space above a holographic Tarot reveal.
 * No device shell. Just the scene, the companion, and the sequence.
 * ============================================================ */
pragma ComponentBehavior: Bound
import QtQuick
import "../tw" as TW

Item {
    id: aseGotchi

    property bool active: true
    readonly property real entropyOut: _entropy

    signal authenticated(string token)
    signal catalystFailed()

    anchors.fill: parent
    visible: active

    // ── Phase ─────────────────────────────────────────────────────────
    property int  _phase:      0
    property bool _isLoading:  _phase === 2
    property bool _isUnlocked: _phase === 3
    property bool _hasError:   false

    // ── Tarot state ───────────────────────────────────────────────────
    property var    _layout:      []
    property string _challenge:   ""
    property var    _sequence:    []
    property var    _tappedFolds: []   // fold IDs in tap order — drives card flip
    property int    _lockedCount: 0
    property real   _entropy:     0.0
    property bool   _configured:  false
    property int    _resetKey:    0    // increment to force card re-evaluation on reset
    property bool   _readyToCast: false   // true when all 7 drawn, waiting for CAST

    readonly property string _sequenceStr: _sequence.join(":")

    property bool  _setupMode:   false
    property var   _setupSeq1:   []
    property var   _setupSeq2:   []
    property bool  _setupPhase2: false

    property int  _failCount:    0
    property bool _lockdown:     false
    property int  _lockdownSecs: 30

    // ── Active fold ───────────────────────────────────────────────────
    property int   _activeFoldIdx:   -1
    property color _activeFoldColor: TW.TransparentWorld.accentWater
    property real  _activePulse:     0.0

    NumberAnimation {
        id: pulseDecay
        target: aseGotchi; property: "_activePulse"
        to: 0.0; duration: 500; easing.type: Easing.OutCubic
        running: false
    }

    // ── Breach ────────────────────────────────────────────────────────
    property real _breach: 0.0
    NumberAnimation {
        id: breachAnim
        target: aseGotchi; property: "_breach"
        from: 0.0; to: 1.0; duration: 900
        easing.type: Easing.OutCubic; running: false
    }

    // ── Whisper ───────────────────────────────────────────────────────
    property string _whisperTarget:  "the sigils await..."
    property string _whisperDisplay: ""
    property int    _whisperIdx:     0
    property bool   _whisperStreaming: false   // true when AI is streaming

    function _setWhisper(msg) {
        _whisperTarget    = msg
        _whisperDisplay   = ""
        _whisperIdx       = 0
        _whisperStreaming  = false
        whisperTimer.restart()
    }

    // AI whisper — streams from local Ollama via kasugai dispatch
    // Falls back to static msg if daemon is offline or response is slow
    function _whisperAI(context, fallback) {
        if (_daemonState !== "alive") { _setWhisper(fallback); return }

        _whisperDisplay  = ""
        _whisperStreaming = true
        whisperTimer.stop()

        var prompt = "You are Ase, a 7-tailed kitsune spirit guarding the Akashic Gate for SourceAura. " +
                     "Speak in 1 sentence. Mystical, direct, sorcerer register. No markdown. Just the whisper. " +
                     "Context: " + context

        var req = new XMLHttpRequest()
        req.onreadystatechange = function() {
            if (req.readyState === XMLHttpRequest.LOADING || req.readyState === XMLHttpRequest.DONE) {
                // Stream tokens as they arrive
                var raw = req.responseText || ""
                // Parse SSE lines — each line is "data: {token}" or the full response
                var lines = raw.split("\n")
                var newText = ""
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    if (line.startsWith("data: ")) {
                        try {
                            var d = JSON.parse(line.slice(6))
                            if (d.token) newText += d.token
                            else if (d.response) newText = d.response
                        } catch(e) {}
                    }
                }
                if (newText !== "") aseGotchi._whisperDisplay = newText.slice(0, 120)
            }
            if (req.readyState === XMLHttpRequest.DONE) {
                aseGotchi._whisperStreaming = false
                // If nothing came back, use fallback
                if (aseGotchi._whisperDisplay === "") aseGotchi._setWhisper(fallback)
            }
        }
        req.onerror = function() { aseGotchi._whisperStreaming = false; aseGotchi._setWhisper(fallback) }

        // 3s timeout — gate must be fast
        var timeoutTimer = Qt.createQmlObject('import QtQuick; Timer { interval: 3000; repeat: false }', aseGotchi)
        timeoutTimer.triggered.connect(function() {
            if (aseGotchi._whisperStreaming && aseGotchi._whisperDisplay === "") {
                req.abort()
                aseGotchi._whisperStreaming = false
                aseGotchi._setWhisper(fallback)
            }
            timeoutTimer.destroy()
        })
        timeoutTimer.start()

        req.open("POST", "http://127.0.0.1:8001/api/kasugai/dispatch", true)
        req.setRequestHeader("Content-Type", "application/json")
        req.send(JSON.stringify({ message: prompt, stream: true, max_tokens: 40 }))
    }

    Timer {
        id: whisperTimer; interval: 22; repeat: true
        onTriggered: {
            if (aseGotchi._whisperIdx < aseGotchi._whisperTarget.length) {
                aseGotchi._whisperDisplay += aseGotchi._whisperTarget[aseGotchi._whisperIdx]
                aseGotchi._whisperIdx++
            } else { stop() }
        }
    }

    // ── Daemon state ──────────────────────────────────────────────────
    property string _daemonState: "checking"

    function _fetchThreats() {
        var req = new XMLHttpRequest()
        req.onreadystatechange = function() {
            if (req.readyState !== XMLHttpRequest.DONE) return
            if (req.status === 200) {
                try {
                    var d = JSON.parse(req.responseText)
                    aseGotchi._daemonState = d.status === "alive" ? "alive" : "degraded"
                } catch(e) { aseGotchi._daemonState = "degraded" }
            } else { aseGotchi._daemonState = "dead" }
        }
        req.onerror = function() { aseGotchi._daemonState = "dead" }
        req.open("GET", "http://127.0.0.1:8001/api/health/ready", true)
        req.send()
    }

    // ── Lockdown ──────────────────────────────────────────────────────
    Timer {
        id: lockdownTimer; interval: 1000; repeat: true; running: aseGotchi._lockdown
        onTriggered: {
            aseGotchi._lockdownSecs--
            aseGotchi._setWhisper("binding locked · " + aseGotchi._lockdownSecs + "s until the seal breathes again")
            if (aseGotchi._lockdownSecs <= 0) {
                aseGotchi._lockdown     = false
                aseGotchi._failCount    = 0
                aseGotchi._lockdownSecs = 30
                aseGotchi._phase        = 1
                aseGotchi._setWhisper("the seal breathes · read the sigils · invoke again")
                numpadFocus.forceActiveFocus()
            }
        }
    }

    // ── Entrance / exit ───────────────────────────────────────────────
    property real _scale:   0.0
    property real _opacity: 0.0
    Behavior on _scale   { NumberAnimation { duration: 400; easing.type: Easing.OutBack; easing.overshoot: 0.25 } }
    Behavior on _opacity { NumberAnimation { duration: 300 } }

    Component.onCompleted: { if (active) _manifest() }
    onActiveChanged:       { if (active) _manifest(); else _dismiss() }

    function _manifest() {
        _phase        = 0
        _sequence     = []
        _tappedFolds  = []
        _lockedCount  = 0
        _entropy      = 0.0
        _hasError     = false
        _failCount    = 0
        _lockdown     = false
        _lockdownSecs = 30
        _setupMode    = false
        _setupSeq1    = []
        _setupSeq2    = []
        _setupPhase2  = false
        _activeFoldIdx   = -1
        _activePulse     = 0.0
        _breach          = 0.0
        _readyToCast   = false
        _resetKey      = 0
        _whisperAI("the gate opens for SourceAura · greet them as they approach",
                   "the sigils await · read the cards · invoke your sequence")
        _fetchThreats()
        _fetchChallenge()
        manifestTimer.restart()
    }

    function _dismiss() {
        _scale   = 0.0
        _opacity = 0.0
    }

    Timer {
        id: manifestTimer; interval: 60; repeat: false
        onTriggered: {
            aseGotchi._phase   = 1
            aseGotchi._scale   = 1.0
            aseGotchi._opacity = 1.0
            scene.aseWake()
            numpadFocus.forceActiveFocus()
        }
    }

    // ── Challenge fetch ───────────────────────────────────────────────
    function _fetchChallenge() {
        var req = new XMLHttpRequest()
        req.onreadystatechange = function() {
            if (req.readyState !== XMLHttpRequest.DONE) return
            if (req.status === 200) {
                try {
                    var d = JSON.parse(req.responseText)
                    aseGotchi._challenge  = d.challenge  || ""
                    aseGotchi._layout     = d.layout     || []
                    aseGotchi._configured = d.configured === true
                    if (aseGotchi._configured) {
                        aseGotchi._setupMode = false
                        aseGotchi._setWhisper("the sigils await · read the cards · invoke your sequence")
                    } else {
                        aseGotchi._setupMode = true
                        aseGotchi._setWhisper("the binding is unwritten · inscribe your sequence across the seven folds")
                    }
                } catch(e) {}
            } else {
                aseGotchi._setWhisper("the daemon sleeps · the gate cannot hear you")
            }
        }
        req.onerror = function() { aseGotchi._setWhisper("gate offline · daemon unreachable") }
        req.open("GET", "http://127.0.0.1:8001/api/auth/gate/challenge", true)
        req.send()
    }

    // ── Fold helpers ──────────────────────────────────────────────────
    readonly property var _canonicalOrder: ["truth","power","wisdom","judgment","life","love","discipline"]
    readonly property var _foldColors: [
        "#4ade80","#f43f5e","#00B4D8","#9B1FA0","#818cf8","#f59e0b","#6366f1"
    ]
    // Kasugai label — matches backend FOLDS and InseiScene
    readonly property var _foldLabelMap: ({
        "truth":      "THE EYE",
        "power":      "THE PHANTOM",
        "wisdom":     "THE BLADE",
        "judgment":   "THE SAGE",
        "life":       "THE SHROUD",
        "love":       "THE FORGE",
        "discipline": "THE MIRROR"
    })
    // Principle name
    readonly property var _principleMap: ({
        "truth":      "TRUTH",
        "power":      "POWER",
        "wisdom":     "WISDOM",
        "judgment":   "JUDGMENT",
        "life":       "LIFE",
        "love":       "LOVE",
        "discipline": "DISCIPLINE"
    })

    function _canonicalIndex(foldId) {
        for (var i = 0; i < _canonicalOrder.length; i++)
            if (_canonicalOrder[i] === foldId) return i
        return 0
    }

    // ── Card reset helper — clears sequence and forces flip-back ─────
    function _resetCards() {
        _sequence      = []
        _tappedFolds   = []
        _lockedCount   = 0
        _entropy       = 0.0
        _activeFoldIdx = -1
        _activePulse   = 0.0
        _setupSeq1     = []
        _setupSeq2     = []
        _setupPhase2   = false
        _readyToCast   = false
        _resetKey      = _resetKey + 1   // force delegate re-evaluation
    }

    // ── Input ─────────────────────────────────────────────────────────

    function _onNumpad(key) {
        if (_lockdown || _phase !== 1) return
        var num = parseInt(key)
        if (isNaN(num) || num < 1 || num > 7) return

        var foldId = ""
        for (var i = 0; i < _layout.length; i++) {
            if (parseInt(_layout[i].position) === num) { foldId = _layout[i].id; break }
        }
        if (!foldId) return

        if (_setupMode) _handleSetupInput(foldId)
        else            _handleAuthInput(foldId)
    }

    function _handleAuthInput(foldId) {
        var seq = _sequence.slice()
        if (seq.indexOf(foldId) !== -1) {
            _setWhisper(_foldLabelMap[foldId] + " · already bound · choose another")
            return
        }
        seq.push(foldId)
        _sequence    = seq
        _tappedFolds = seq.slice()
        _lockedCount = seq.length
        _entropy     = seq.length / 7.0

        var ci = _canonicalIndex(foldId)
        _activeFoldIdx   = ci
        _activeFoldColor = Qt.color(_foldColors[ci])
        _activePulse     = 1.0
        pulseDecay.restart()

        scene.aseReact(Qt.color(_foldColors[ci]))
        _setWhisper(_foldLabelMap[foldId] + " · " + _principleMap[foldId] + " · bound to your will · " + seq.length + " of 7")

        if (seq.length === 7) {
            _readyToCast = true
            _whisperAI("all seven folds are bound · the sequence is complete · speak the invocation",
                       "the sequence is complete · invoke the seal to pass")
        }
    }

    // ── Cast — fires verify after all 7 drawn ─────────────────────────
    function _cast() {
        if (_lockdown || _phase !== 1) return
        if (_setupMode) {
            if (_setupPhase2 && _setupSeq2.length === 7) {
                _phase = 2
                _setWhisper("the binding speaks · the seal yields…")
                scene.aseTransform()
                breachAnim.restart()
                _registerSequence(_setupSeq1, _setupSeq2)
            } else if (!_setupPhase2 && _setupSeq1.length === 7) {
                _setupPhase2 = true
                _tappedFolds = []
                _lockedCount = 0
                _entropy     = 0.0
                _activeFoldIdx = -1
                _readyToCast = false
                _setWhisper("the first binding is sealed · draw the same sequence again to confirm")
            }
        } else {
            if (_sequence.length === 7) {
                _phase = 2
                _setWhisper("the binding speaks · the seal yields…")
                scene.aseTransform()
                breachAnim.restart()
                _verifySequence(_sequence)
            }
        }
    }

    function _handleSetupInput(foldId) {
        var ci = _canonicalIndex(foldId)
        _activeFoldIdx   = ci
        _activeFoldColor = Qt.color(_foldColors[ci])
        _activePulse     = 1.0
        pulseDecay.restart()
        scene.aseReact(Qt.color(_foldColors[ci]))

        if (!_setupPhase2) {
            var s1 = _setupSeq1.slice()
            if (s1.indexOf(foldId) !== -1) {
                _setWhisper(_foldLabelMap[foldId] + " · already bound · choose another")
                return
            }
            s1.push(foldId)
            _setupSeq1   = s1
            _tappedFolds = s1.slice()
            _lockedCount = s1.length
            _entropy     = s1.length / 7.0
            _setWhisper(_foldLabelMap[foldId] + " · " + _principleMap[foldId] + " · " + s1.length + " of 7 inscribed")
            if (s1.length === 7) {
                _readyToCast = true
                _setWhisper("the first binding is written · invoke to seal it")
            }
        } else {
            var s2 = _setupSeq2.slice()
            if (s2.indexOf(foldId) !== -1) {
                _setWhisper(_foldLabelMap[foldId] + " · already bound · choose another")
                return
            }
            s2.push(foldId)
            _setupSeq2   = s2
            _tappedFolds = s2.slice()
            _lockedCount = s2.length
            _entropy     = s2.length / 7.0
            _setWhisper(_foldLabelMap[foldId] + " · CONFIRM · " + s2.length + " of 7")
            if (s2.length === 7) {
                _readyToCast = true
                _setWhisper("the confirmation is written · invoke to bind the seal forever")
            }
        }
    }

    function _verifySequence(seq) {
        var r = new XMLHttpRequest()
        r.onreadystatechange = function() {
            if (r.readyState !== XMLHttpRequest.DONE) return
            if (r.status === 200) {
                try {
                    var d = JSON.parse(r.responseText)
                    aseGotchi._phase = 3
                    aseGotchi._whisperAI("SourceAura has passed through the Akashic Gate · welcome them",
                                         "the seal opens · welcome, SourceAura")
                    aseGotchi._triggerUnlock(d.session_token || "")
                } catch(e) {
                    aseGotchi._deflect("the binding failed to parse · " + e)
                }
            } else {
                var detail = ""
                try { detail = JSON.parse(r.responseText).detail || r.status } catch(e) { detail = r.status }
                aseGotchi._deflect(detail)
            }
        }
        r.onerror = function() { aseGotchi._deflect("the daemon sleeps · the gate cannot hear you") }
        r.open("POST", "http://127.0.0.1:8001/api/auth/gate/verify", true)
        r.setRequestHeader("Content-Type", "application/json")
        r.send(JSON.stringify({ sequence: seq, challenge: aseGotchi._challenge }))
    }

    function _registerSequence(seq1, seq2) {
        var r = new XMLHttpRequest()
        r.onreadystatechange = function() {
            if (r.readyState !== XMLHttpRequest.DONE) return
            if (r.status === 200) {
                aseGotchi._setupMode  = false
                aseGotchi._configured = true
                aseGotchi._phase      = 3
                aseGotchi._setWhisper("the seal is bound · the gate remembers your will, SourceAura")
                aseGotchi._triggerUnlock("setup-complete")
            } else {
                aseGotchi._deflect("the binding failed · sequences do not match · begin again")
                aseGotchi._setupPhase2 = false
                aseGotchi._setupSeq1   = []
                aseGotchi._setupSeq2   = []
                aseGotchi._lockedCount = 0
            }
        }
        r.open("POST", "http://127.0.0.1:8001/api/auth/gate/setup", true)
        r.setRequestHeader("Content-Type", "application/json")
        r.send(JSON.stringify({ sequence: seq1, confirm: seq2, challenge: aseGotchi._challenge }))
    }

    function _triggerUnlock(token) {
        unlockTimer.token = token
        unlockTimer.restart()
    }

    Timer {
        id: unlockTimer; property string token: ""; interval: 1000; repeat: false
        onTriggered: {
            aseGotchi._scale   = 0.0
            aseGotchi._opacity = 0.0
            releaseTimer.token = token
            releaseTimer.restart()
        }
    }

    Timer {
        id: releaseTimer; property string token: ""; interval: 400; repeat: false
        onTriggered: aseGotchi.authenticated(token)
    }

    function _deflect(msg) {
        _setWhisper(msg)
        _hasError = true
        _phase    = 1
        _resetCards()
        scene.aseHurt()
        _failCount++
        catalystFailed()
        if (_failCount >= 3) {
            _lockdown     = true
            _lockdownSecs = 30
            _phase        = 0
            _whisperAI("the binding has been violated three times · speak a warning of consequence",
                       "THE BINDING SEVERS · resonance locked · 30s")
        } else {
            errorResetTimer.restart()
            numpadFocus.forceActiveFocus()
        }
    }

    Timer {
        id: errorResetTimer; interval: 2500; repeat: false
        onTriggered: {
            aseGotchi._hasError = false
            aseGotchi._fetchChallenge()
        }
    }

    // ── Backdrop ──────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, aseGotchi._phase >= 1 ? 0.65 : 0.0)
        Behavior on color { ColorAnimation { duration: 500 } }
    }

    // ── Scene ─────────────────────────────────────────────────────────
    InseiScene {
        id: scene
        anchors.fill: parent
        scale:   aseGotchi._scale
        opacity: aseGotchi._opacity
        transformOrigin: Item.Center

        readyToCast:     aseGotchi._readyToCast
        lockedCount:     aseGotchi._lockedCount
        entropy:         aseGotchi._entropy
        hasError:        aseGotchi._hasError
        isUnlocked:      aseGotchi._isUnlocked
        isLoading:       aseGotchi._isLoading
        whisper:         aseGotchi._whisperDisplay
        sequenceStr:     aseGotchi._sequenceStr
        layout:          aseGotchi._layout
        tappedFolds:     aseGotchi._tappedFolds
        time:            aseGotchi._time
        activeFoldIdx:   aseGotchi._activeFoldIdx
        activeFoldColor: aseGotchi._activeFoldColor
        activePulse:     aseGotchi._activePulse
        breach:          aseGotchi._breach
        setupMode:       aseGotchi._setupMode
        setupPhase2:     aseGotchi._setupPhase2
        resetKey:        aseGotchi._resetKey

        onCardTapped: function(foldId, position) {
            if (_setupMode) _handleSetupInput(foldId)
            else            _handleAuthInput(foldId)
        }
        onCastRequested: aseGotchi._cast()
    }

    // ── Time driver ───────────────────────────────────────────────────
    property real _time: 0.0
    NumberAnimation on _time {
        from: 0; to: 100000; duration: 100000000
        loops: Animation.Infinite; running: aseGotchi.active
    }

    // ── Numpad focus trap ─────────────────────────────────────────────
    Item {
        id: numpadFocus
        anchors.fill: parent
        focus: true

        Keys.onPressed: function(event) {
            var k = event.key
            var num = 0
            if      (k === Qt.Key_1 || k === Qt.Key_KP_1) num = 1
            else if (k === Qt.Key_2 || k === Qt.Key_KP_2) num = 2
            else if (k === Qt.Key_3 || k === Qt.Key_KP_3) num = 3
            else if (k === Qt.Key_4 || k === Qt.Key_KP_4) num = 4
            else if (k === Qt.Key_5 || k === Qt.Key_KP_5) num = 5
            else if (k === Qt.Key_6 || k === Qt.Key_KP_6) num = 6
            else if (k === Qt.Key_7 || k === Qt.Key_KP_7) num = 7

            if (num > 0) {
                aseGotchi._onNumpad(num.toString())
                event.accepted = true

            } else if (k === Qt.Key_B) {
                // B — dev bypass (local only)
                if (!aseGotchi._lockdown) {
                    aseGotchi._phase = 3
                    aseGotchi._setWhisper("sovereign passage · the seal yields")
                    aseGotchi._triggerUnlock("bypass-token")
                }
                event.accepted = true

            } else if (k === Qt.Key_R) {
                // R — reshuffle
                if (!aseGotchi._lockdown && aseGotchi._phase === 1) {
                    aseGotchi._resetCards()
                    aseGotchi._fetchChallenge()
                    aseGotchi._setWhisper("the cards scatter · read the new arrangement")
                }
                event.accepted = true

            } else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_KP_Enter) {
                if (!aseGotchi._lockdown && aseGotchi._phase === 1) {
                    if (aseGotchi._readyToCast) {
                        aseGotchi._cast()
                    } else {
                        var drawn = aseGotchi._setupMode
                            ? (aseGotchi._setupPhase2 ? aseGotchi._setupSeq2.length : aseGotchi._setupSeq1.length)
                            : aseGotchi._sequence.length
                        var remaining = 7 - drawn
                        aseGotchi._setWhisper(drawn + " of 7 bound · " + remaining + " fold" + (remaining !== 1 ? "s" : "") + " remain · read the sigils")
                    }
                }
                event.accepted = true

            } else if (k === Qt.Key_Escape) {
                if (aseGotchi._lockdown) {
                    event.accepted = true
                    return
                }
                var hasProgress = aseGotchi._sequence.length > 0
                    || aseGotchi._setupSeq1.length > 0
                    || aseGotchi._setupSeq2.length > 0
                if (hasProgress) {
                    aseGotchi._resetCards()
                    aseGotchi._fetchChallenge()
                    aseGotchi._setWhisper("the cards scatter · read the new arrangement")
                } else {
                    // Clean state — exit the gate
                    aseGotchi._dismiss()
                    aseGotchi.catalystFailed()
                }
                event.accepted = true
            }
        }
    }
}
