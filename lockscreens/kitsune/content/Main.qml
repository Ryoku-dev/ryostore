import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "gotchi"

// KITSUNE — the greeter (built 2026-10-21, the captain's order).
//
// Ase and her seven folds at the outer door — the same composition
// that guards the lock, seated over SDDM's own machinery. The login
// speaks astronaut's exact idiom (the valence theme's Input.qml):
// userModel/sessionModel ComboBoxes on lastIndex, and
//   sddm.login(user.toLowerCase(), password, selectedSession)
// because kitsune.conf carries AllowUppercaseLettersInUsernames=false,
// the same rule valence runs. Nothing of SDDM's PAM path is touched.
//
//   typing        -> one fold binds per character, Ase reacts
//   7 bound       -> INVOKE THE SEAL rises (the Cast = login)
//   login failed  -> she is hurt, the cards scatter (astronaut's
//                    failed flag + 2s resetError, her ceremony over it)
//   login success -> all seven revealed, she transforms, the seal opens
//
// Self-contained by necessity: the greeter runs as user `sddm` and
// cannot read the captain's home. Her palette is baked at install;
// the ground is the manager-published still
// (/var/lib/valence-greeter/wallpaper.jpg, world-readable), with a
// theme-local copy underneath as the fallback.
// The user ComboBox is omitted by design: one captain, one account —
// the username field stands prefilled from userModel.lastUser and
// stays editable.
Rectangle {
    id: root
    color: "#06070c"
    focus: true

    // Baked palette — matugen's word at install time (matches the
    // lock face's live palette the night this was built).
    readonly property color palBackground: "#12131c"
    readonly property color palText:       "#e3e1ef"
    readonly property color palPrimary:    "#bec2ff"
    readonly property color palSecondary:  "#ccc1e9"
    readonly property color palAlert:      "#f43f5e"

    property bool _checking: false
    property real _pulseTime: 0
    property real _pulseSurge: 0
    property real _pulseFront: -0.4
    property real _pulseCrackle: 0
    property real _rippleX: 0.5
    property real _rippleY: 0.5
    property real _rippleStart: -100.0
    function _rippleAt(px, py) {
        root._rippleX = px / Math.max(1, root.width);
        root._rippleY = py / Math.max(1, root.height);
        root._rippleStart = root._pulseTime;
    }
    property bool _failed: false
    property bool _leaving: false

    // ---- Her fold canon (the scene's own, mirrored for the wiring) --
    readonly property var _foldIds: ["truth","power","wisdom","judgment","life","love","discipline"]
    readonly property var _foldLabels: ["THE EYE","THE PHANTOM","THE BLADE","THE SAGE","THE SHROUD","THE FORGE","THE MIRROR"]
    readonly property var _foldPrinciples: ["TRUTH","POWER","WISDOM","JUDGMENT","LIFE","LOVE","DISCIPLINE"]
    readonly property var _foldColors: ["#4ade80","#f43f5e","#00B4D8","#9B1FA0","#818cf8","#f59e0b","#6366f1"]

    // ---- Ceremony state, driven by the password field -----------------
    readonly property string _pw: passwordField.text
    readonly property int _bound: Math.min(7, root._pw.length)

    property var   _tapped: []
    property int   _activeFoldIdx: -1
    property color _activeFoldColor: "#00B4D8"
    property real  _activePulse: 0.0
    property int   _lastLen: 0

    // ---- The mantra gate ------------------------------------------------
    // theme.conf speaks two keys (both optional):
    //   MantraGate=true            — the gate stands at this door
    //   MantraOrder=truth,power,…  — your order of the seven folds
    // With neither key set, the face is a plain password door, as before.
    readonly property bool _gateDefault: typeof config !== "undefined" && config.MantraGate === "true"
    readonly property var _gateOrder: {
        const raw = (typeof config !== "undefined" && config.MantraOrder) ? String(config.MantraOrder) : "";
        const list = raw.split(",").map(function(w) { return w.trim(); })
                        .filter(function(w) { return root._foldIds.indexOf(w) >= 0; });
        return list.length === 7 ? list : root._foldIds;
    }
    property bool _gateOn: root._gateDefault
    property bool _gatePassed: !root._gateDefault
    readonly property bool _gateActive: root._gateOn && !root._gatePassed
    property var _gateDeal: []      // the fold id dealt to each fan slot
    property var _gateEntry: []     // the slot numbers spoken so far
    // MantraPass in theme.conf is the key the mantra speaks to PAM when
    // the sequence is right. Empty (the shipped way) = the gate opens
    // onto the password field instead. It is a password in plain text:
    // it belongs only on a seat whose theme.conf no one else can read.
    readonly property string _mantraPass: (typeof config !== "undefined" && config.MantraPass) ? String(config.MantraPass) : ""
    property bool _gateAttempt: false   // the last login came from the gate
    readonly property int _gateMaxDefault: {
        const n = (typeof config !== "undefined" && config.MantraAttempts) ? parseInt(String(config.MantraAttempts), 10) : NaN;
        return isNaN(n) ? 3 : Math.max(1, Math.min(9, n));
    }
    property int _gateMaxAttempts: root._gateMaxDefault
    property int _gateAttempts: 0
    property bool _refusedWasGate: false
    property bool _settingsOpen: false

    NumberAnimation {
        id: pulseDecay
        target: root; property: "_activePulse"
        to: 0.0; duration: 500; easing.type: Easing.OutCubic
        running: false
    }

    readonly property real _entropy: {
        const pw = root._pw;
        if (pw.length === 0) return 0;
        const uniq = new Set(pw.split("")).size;
        const lenScore = Math.min(1, pw.length / 16);
        const variety = uniq / pw.length;
        return Math.min(1, lenScore * 0.65 + variety * 0.25 + lenScore * variety * 0.3);
    }

    function _passwordEdited() {
        if (root._gateActive) return;
        const n = root._pw.length;
        const bound = Math.min(7, n);
        if (root._leaving) return;

        if (n > root._lastLen && bound > 0) {
            const ci = bound - 1;
            root._activeFoldIdx = ci;
            root._activeFoldColor = root._foldColors[ci];
            root._activePulse = 1.0;
            pulseDecay.restart();
            scene.aseReact(Qt.color(root._foldColors[ci]));
        }
        root._lastLen = n;
        root._tapped = root._foldIds.slice(0, bound);

        if (root._failed || root._checking) return;
        if (bound === 0)
            root._setWhisper("the sigils await · read the cards · invoke your sequence");
        else if (bound < 7)
            root._setWhisper(root._foldLabels[bound - 1] + " · " + root._foldPrinciples[bound - 1] + " · bound to your will · " + bound + " of 7");
        else
            root._setWhisper("the sequence is complete · invoke the seal to pass");
    }

    // ---- The gate's dealing and answering --------------------------------
    function _deal() {
        const ids = root._foldIds.slice();
        for (let i = ids.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            const t = ids[i]; ids[i] = ids[j]; ids[j] = t;
        }
        root._gateEntry = [];
        root._tapped = [];
        root._gateDeal = ids;
    }
    function _gateLayout() {
        return root._gateDeal.map(function(id, i) {
            return { id: id, color: root._foldColors[root._foldIds.indexOf(id)], position: i + 1 };
        });
    }
    function _gateDigit(d) {
        if (!root._gateActive || d < 1 || d > 7) return;
        if (root._gateEntry.indexOf(d) >= 0) return;   // a slot is spoken once
        root._gateEntry = root._gateEntry.concat([d]);
        root._tapped = root._gateEntry.map(function(e) { return root._gateDeal[e - 1]; });
        const ci = root._foldIds.indexOf(root._gateDeal[d - 1]);
        root._activeFoldIdx = ci;
        root._activeFoldColor = root._foldColors[ci];
        root._activePulse = 1.0;
        pulseDecay.restart();
        scene.aseReact(Qt.color(root._foldColors[ci]));
        if (root._gateEntry.length < 7) {
            root._setWhisper(root._foldLabels[ci] + " · " + root._foldPrinciples[ci]
                             + " · spoken · " + root._gateEntry.length + " of 7");
            return;
        }
        root._setWhisper("the sequence is complete · invoke the seal to pass");
    }
    function _gateSubmit() {
        if (!root._gateActive) return;
        if (root._gateEntry.length < 7) {
            root._setWhisper("the mantra is sevenfold · speak it whole, then invoke");
            return;
        }
        if (root._tapped.join(",") === root._gateOrder.join(",")) {
            root._gatePassed = true;
            if (root._mantraPass.length > 0) {
                root._setWhisper("the mantra holds · the seal yields…");
                gateUnlockTimer.restart();
            } else {
                root._setWhisper("the mantra holds · now speak your password");
                gatePassTimer.restart();
            }
        } else {
            scene.aseHurt();
            root._gateAttempts++;
            if (root._gateAttempts >= root._gateMaxAttempts) {
                root._setWhisper("attempts spent · the gate stands down");
                gateStandDownTimer.restart();
            } else {
                root._setWhisper("the mantra breaks · the cards redeal · "
                                 + (root._gateMaxAttempts - root._gateAttempts) + " attempts remain");
                gateRedealTimer.restart();
            }
        }
    }
    function _toggleGate() {
        root._gateAttempts = 0;
        if (root._gateOn) {
            root._gateOn = false;
            root._gatePassed = true;
            root._gateEntry = [];
            root._tapped = [];
            root._setWhisper("the sigils await · read the cards · invoke your sequence");
            passwordField.forceActiveFocus();
        } else {
            root._gateOn = true;
            root._gatePassed = false;
            root._deal();
            root._setWhisper("the sigils are dealt · speak the mantra in its order");
            gateField.forceActiveFocus();
        }
    }
    Keys.onPressed: function(event) {
        if (event.text === "h") {
            root._settingsOpen = !root._settingsOpen;
            event.accepted = true;
            return;
        }
        if (root._settingsOpen) {
            if (event.key === Qt.Key_Escape) { root._settingsOpen = false; event.accepted = true; return; }
            if (event.text === "g") { root._toggleGate(); event.accepted = true; return; }
            if (event.text === "-" || event.text === "+") {
                root._gateMaxAttempts = Math.max(1, Math.min(5, root._gateMaxAttempts + (event.text === "+" ? 1 : -1)));
                event.accepted = true;
                return;
            }
        }
        if (!root._gateActive) return;
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root._gateSubmit();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Backspace) {
            if (root._gateEntry.length > 0) {
                root._gateEntry = root._gateEntry.slice(0, -1);
                root._tapped = root._gateEntry.map(function(e) { return root._gateDeal[e - 1]; });
            }
            event.accepted = true;
            return;
        }
        const d = parseInt(event.text, 10);
        if (!isNaN(d)) { root._gateDigit(d); event.accepted = true; }
    }
    Timer { id: gatePassTimer; interval: 650; repeat: false
        onTriggered: { root._gateOn = false; root._tapped = []; passwordField.forceActiveFocus(); } }
    Timer { id: gateUnlockTimer; interval: 550; repeat: false
        onTriggered: {
            root._gateOn = false;
            root._gateAttempt = true;
            root._submitLogin(root._mantraPass);
        } }
    Timer { id: gateStandDownTimer; interval: 900; repeat: false
        onTriggered: {
            root._gateOn = false;
            root._gatePassed = true;
            root._gateAttempts = 0;
            root._gateEntry = [];
            root._tapped = [];
            root._setWhisper("the gate stands down · speak your password");
            passwordField.forceActiveFocus();
        } }
    Timer { id: gateRedealTimer; interval: 900; repeat: false
        onTriggered: { root._deal(); root._setWhisper("the sigils are dealt · speak the mantra in its order"); gateField.forceActiveFocus(); } }

    // ---- The whisper (her typewriter, 22ms a letter) ------------------
    property string _whisperTarget: ""
    property string _whisperDisplay: ""
    property int    _whisperIdx: 0

    function _setWhisper(msg) {
        root._whisperTarget = msg;
        root._whisperDisplay = "";
        root._whisperIdx = 0;
        whisperTimer.restart();
    }
    Timer {
        id: whisperTimer; interval: 22; repeat: true
        onTriggered: {
            if (root._whisperIdx < root._whisperTarget.length) {
                root._whisperDisplay += root._whisperTarget[root._whisperIdx];
                root._whisperIdx++;
            } else { stop(); }
        }
    }

    // ---- Time driver ---------------------------------------------------
    property real _time: 0.0
    NumberAnimation on _time {
        from: 0; to: 100000; duration: 100000000
        loops: Animation.Infinite; running: true
    }

    // ---- The ground -----------------------------------------------------
    // The port veils BOTH layers (2026-10-25, the captain's word: the
    // current wallpaper shows through the lock, blurred for privacy).
    // In the shell the theme-local copy stood raw beneath the manager's
    // blurred still; standing alone it would have shown the picture
    // plain at the door. Same blur, same dimming, same easing as hers.
    Item {
        id: groundStack
        anchors.fill: parent
    Image {
        anchors.fill: parent
        source: "Backgrounds/wallpaper.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: root._leaving ? 0.3 : 0.8
            blurMax: 64
            brightness: root._leaving ? -0.02 : -0.10
            Behavior on blur { NumberAnimation { duration: 380; easing.type: Easing.OutQuad } }
            Behavior on brightness { NumberAnimation { duration: 380; easing.type: Easing.OutQuad } }
        }
    }
    Image {
        anchors.fill: parent
        source: "file:///var/lib/valence-greeter/wallpaper.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: root._leaving ? 0.3 : 0.8
            blurMax: 64
            brightness: root._leaving ? -0.02 : -0.10
            Behavior on blur { NumberAnimation { duration: 380; easing.type: Easing.OutQuad } }
            Behavior on brightness { NumberAnimation { duration: 380; easing.type: Easing.OutQuad } }
        }
    }
    // The desktop at the lock's instant (fuin-lock sets it down in the
    // runtime tmpfs on the way in), veiled like the rest of the ground.
    // When no capture waits — an idle lock, the greeter — this draws
    // nothing and the wallpaper ground stands, as before.
    Image {
        anchors.fill: parent
        source: "file:///run/user/1000/fuin-desktop.png"
        cache: false
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: root._leaving ? 0.3 : 0.8
            blurMax: 64
            brightness: root._leaving ? -0.02 : -0.10
            Behavior on blur { NumberAnimation { duration: 380; easing.type: Easing.OutQuad } }
            Behavior on brightness { NumberAnimation { duration: 380; easing.type: Easing.OutQuad } }
        }
    }
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(root.palBackground, 0.30)
    }
    }
    ShaderEffectSource {
        id: groundSource
        sourceItem: groundStack
        hideSource: false
        live: true
        visible: false
    }

    // ---- The pulse (energy in the glass — calm, surges, rare crackle) ---
    ShaderEffect {
        anchors.fill: parent
        fragmentShader: "shaders/pulse.frag.qsb"
        property real u_time: root._pulseTime
        property real u_surge: root._pulseSurge
        property real u_front: root._pulseFront
        property real u_crackle: root._pulseCrackle
        property real u_calm: 0.05
        property var u_click: Qt.vector2d(root._rippleX, root._rippleY)
        property real u_clickAge: root._pulseTime - root._rippleStart
        property real u_aspect: root.width / Math.max(1, root.height)
        property var u_ground: groundSource
    }
    MouseArea {
        anchors.fill: parent
        onPressed: function(mouse) { root._rippleAt(mouse.x, mouse.y); }
    }
    Timer {
        interval: 50; running: true; repeat: true
        onTriggered: root._pulseTime += 0.05
    }
    Timer {
        id: pulseScheduler
        interval: 7000; running: true; repeat: false
        onTriggered: root._pulseEvent()
    }
    function _pulseEvent() {
        if (Math.random() < 0.28) crackleAnim.restart(); else surgeAnim.restart();
        pulseScheduler.interval = 9000 + Math.random() * 14000;
        pulseScheduler.restart();
    }
    SequentialAnimation {
        id: surgeAnim
        ParallelAnimation {
            NumberAnimation { target: root; property: "_pulseFront"; from: -0.35; to: 1.35; duration: 2600; easing.type: Easing.InOutSine }
            SequentialAnimation {
                NumberAnimation { target: root; property: "_pulseSurge"; to: 1; duration: 600; easing.type: Easing.OutQuad }
                PauseAnimation { duration: 1200 }
                NumberAnimation { target: root; property: "_pulseSurge"; to: 0; duration: 800; easing.type: Easing.InQuad }
            }
        }
    }
    SequentialAnimation {
        id: crackleAnim
        NumberAnimation { target: root; property: "_pulseCrackle"; to: 1; duration: 90 }
        NumberAnimation { target: root; property: "_pulseCrackle"; to: 0.3; duration: 120 }
        NumberAnimation { target: root; property: "_pulseCrackle"; to: 0.75; duration: 80 }
        NumberAnimation { target: root; property: "_pulseCrackle"; to: 0; duration: 420; easing.type: Easing.OutQuad }
    }

    // ---- Her scene (rides high — the fields hold the foot) --------------
    InseiScene {
        id: scene
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: parent.height * 0.84

        layout:          root._gateOn ? root._gateLayout() : []
        tappedFolds:     root._tapped
        lockedCount:     root._gateActive ? root._gateEntry.length : root._bound
        entropy:         root._entropy
        sequenceStr:     root._tapped.join(":")
        time:            root._time
        activeFoldIdx:   root._activeFoldIdx
        activeFoldColor: root._activeFoldColor
        activePulse:     root._activePulse
        whisper:         root._whisperDisplay
        hasError:        root._failed
        isLoading:       root._checking
        isUnlocked:      root._leaving
        readyToCast:     root._gateActive ? (root._gateEntry.length >= 7 && !root._checking)
                                           : (root._bound >= 7 && !root._checking && !root._leaving)

        onCastRequested: root._gateActive ? root._gateSubmit() : root.attemptLogin()
        onCardTapped: function(foldId, position, px, py) {
            root._rippleAt(px, py);
            root._gateDigit(position);
        }
    }

    // ---- The login (astronaut's call, letter for letter) -----------------
    function _submitLogin(pw) {
        if (root._checking || root._leaving) return;
        root._checking = true;
        const u = usernameField.text;
        sddm.login(config.AllowUppercaseLettersInUsernames == "false" ? u.toLowerCase() : u,
                   pw, sessionSelect.selectedSession);
    }
    function attemptLogin() {
        if (passwordField.text.length === 0 || root._checking || root._leaving) return;
        root._gateAttempt = false;
        root._setWhisper("the binding speaks · the seal yields…");
        root._submitLogin(passwordField.text);
    }

    Connections {
        target: sddm
        function onLoginSucceeded() {
            root._checking = false;
            root._leaving = true;
            root._tapped = root._foldIds.slice(0, 7);
            scene.aseTransform();
            root._setWhisper("the seal opens · welcome, " + usernameField.text);
        }
        function onLoginFailed() {
            root._checking = false;
            root._failed = true;
            scene.aseHurt();
            shake.restart();
            passwordField.text = "";
            if (root._gateAttempt) {
                root._refusedWasGate = true;
                root._gateAttempt = false;
                root._gateOn = false;
                root._gatePassed = true;
            }
            root._lastLen = 0;
            root._tapped = [];
            resetError.restart();
            failWhisper.restart();
            passwordField.forceActiveFocus();
        }
    }
    Timer { id: resetError; interval: 2000; repeat: false; onTriggered: root._failed = false }
            // A refused key stands the gate down; the switch is manual.
    Timer {
        id: failWhisper; interval: 150; repeat: false
        onTriggered: root._setWhisper(root._refusedWasGate
            ? "the binding refuses · the stored key was refused — your password, then"
            : "the binding refuses · login failed")
    }

    // ---- The gate's ear: a quiet field that only listens for digits ------
    TextField {
        id: gateField
        opacity: 0
        width: 1; height: 1
        x: 0; y: 0
        enabled: root._gateActive
        background: Item {}
        onAccepted: root._gateSubmit()
        onTextChanged: {
            const t = text;
            if (t.length === 0) return;
            const d = parseInt(t.charAt(t.length - 1), 10);
            text = "";
            if (!isNaN(d)) root._gateDigit(d);
        }
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Backspace && root._gateEntry.length > 0) {
                root._gateEntry = root._gateEntry.slice(0, -1);
                root._tapped = root._gateEntry.map(function(e) { return root._gateDeal[e - 1]; });
            }
        }
    }

    // ---- The fields, at the foot of her scene -----------------------------
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        spacing: 9
        z: 2
        visible: !root._gateActive
        opacity: root._gateActive ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 250 } }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root._failed
            text: "LOGIN FAILED"
            color: root.palAlert
            font.family: "3270 Nerd Font Mono, Fira Code, monospace"
            font.pixelSize: 12
            font.letterSpacing: 2
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 300
            height: 40
            radius: 20
            color: Qt.alpha("#0a0a12", 0.55)
            border.width: 1
            border.color: usernameField.activeFocus ? Qt.alpha(root.palPrimary, 0.6) : Qt.alpha(root.palText, 0.22)
            Behavior on border.color { ColorAnimation { duration: 200 } }

            TextField {
                id: usernameField
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                text: userModel.lastUser
                color: root.palText
                font.family: "3270 Nerd Font Mono, Fira Code, monospace"
                font.pixelSize: 13
                font.letterSpacing: 2
                horizontalAlignment: TextInput.AlignHCenter
                verticalAlignment: TextInput.AlignVCenter
                background: Item {}
                onAccepted: passwordField.forceActiveFocus()
            }
        }

        Rectangle {
            id: pill
            anchors.horizontalCenter: parent.horizontalCenter
            width: 300
            height: 46
            radius: 23
            color: Qt.alpha("#0a0a12", 0.55)
            border.width: 1
            border.color: root._failed
                ? Qt.alpha(root.palAlert, 0.8)
                : (passwordField.activeFocus ? Qt.alpha(root.palPrimary, 0.6) : Qt.alpha(root.palText, 0.22))
            Behavior on border.color { ColorAnimation { duration: 200 } }
            transform: Translate { id: pillShift }

            SequentialAnimation {
                id: shake
                NumberAnimation { target: pillShift; property: "x"; to: -7; duration: 45 }
                NumberAnimation { target: pillShift; property: "x"; to: 6; duration: 55 }
                NumberAnimation { target: pillShift; property: "x"; to: -4; duration: 55 }
                NumberAnimation { target: pillShift; property: "x"; to: 2; duration: 50 }
                NumberAnimation { target: pillShift; property: "x"; to: 0; duration: 45 }
            }
            opacity: root._leaving ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 300 } }

            TextField {
                id: passwordField
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                echoMode: TextInput.Password
                placeholderText: "PASSWORD"
                placeholderTextColor: Qt.alpha(root.palText, 0.35)
                color: root.palText
                font.family: "3270 Nerd Font Mono, Fira Code, monospace"
                font.pixelSize: 14
                font.letterSpacing: 2
                horizontalAlignment: TextInput.AlignHCenter
                verticalAlignment: TextInput.AlignVCenter
                background: Item {}
                enabled: !root._checking
                onTextChanged: root._passwordEdited()
                onAccepted: root.attemptLogin()
            }
        }

        // The session, astronaut's ComboBox idiom in quiet dress.
        ComboBox {
            id: sessionSelect
            property var selectedSession: currentIndex
            anchors.horizontalCenter: parent.horizontalCenter
            model: sessionModel
            currentIndex: model.lastIndex
            textRole: "name"
            background: Item {}
            indicator: Item {}
            contentItem: Text {
                text: "Session (" + sessionSelect.currentText + ")"
                color: Qt.alpha(root.palText, sessionSelect.hovered ? 0.9 : 0.55)
                font.family: "3270 Nerd Font Mono, Fira Code, monospace"
                font.pixelSize: 11
                font.letterSpacing: 1.5
                horizontalAlignment: Text.AlignHCenter
            }
            delegate: ItemDelegate {
                width: sessionSelect.width
                contentItem: Text {
                    text: model.name
                    color: root.palText
                    font.family: "3270 Nerd Font Mono, Fira Code, monospace"
                    font.pixelSize: 11
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: highlighted ? Qt.alpha(root.palPrimary, 0.25) : "transparent"
                }
            }
            popup: Popup {
                y: -implicitHeight - 4
                width: sessionSelect.width
                padding: 6
                contentItem: ListView {
                    clip: true
                    implicitHeight: contentHeight
                    model: sessionSelect.popup.visible ? sessionSelect.delegateModel : null
                    currentIndex: sessionSelect.highlightedIndex
                }
                background: Rectangle {
                    radius: 8
                    color: Qt.alpha("#0a0a12", 0.92)
                    border.width: 1
                    border.color: Qt.alpha(root.palText, 0.18)
                }
            }
        }

    }

    // ---- The hint: the face explains itself --------------------------------
    Row {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 22
        anchors.bottomMargin: 16
        z: 2
        Text {
            text: "hint"
            color: Qt.alpha(root.palText, settingsArea.containsMouse ? 0.9 : 0.45)
            font.family: "3270 Nerd Font Mono, Fira Code, monospace"
            font.pixelSize: 11
            font.letterSpacing: 1.5
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.alpha(root.palPrimary, 0.9)
                shadowBlur: settingsArea.containsMouse ? 0.75 : 0.0
                shadowOpacity: settingsArea.containsMouse ? 0.95 : 0.0
                Behavior on shadowBlur { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                Behavior on shadowOpacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
            }
            MouseArea { id: settingsArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root._settingsOpen = !root._settingsOpen }
        }
    }

    Rectangle {
        id: settingsPanel
        visible: root._settingsOpen
        anchors.centerIn: parent
        width: 540
        height: panelCol.implicitHeight + 44
        radius: 14
        z: 30
        color: Qt.alpha(root.palBackground, 0.94)
        border.width: 1
        border.color: Qt.alpha(root.palText, 0.18)

        Column {
            id: panelCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 22
            spacing: 11

            Text {
                text: "MANTRA GATE — THE HINT"
                color: root.palText
                font.family: "3270 Nerd Font Mono, Fira Code, monospace"
                font.pixelSize: 12
                font.letterSpacing: 2
            }
            Row {
                spacing: 10
                Text {
                    text: "mantra gate"
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.alpha(root.palText, 0.85)
                    font.family: "3270 Nerd Font Mono, Fira Code, monospace"
                    font.pixelSize: 12
                }
                Rectangle {
                    width: 30; height: 16; radius: 8
                    anchors.verticalCenter: parent.verticalCenter
                    color: root._gateOn ? Qt.alpha(root.palPrimary, 0.35) : Qt.alpha("#0a0a12", 0.55)
                    border.width: 1
                    border.color: Qt.alpha(root.palText, root._gateOn ? 0.5 : 0.22)
                    Rectangle {
                        width: 10; height: 10; radius: 5
                        y: 2
                        x: root._gateOn ? 17 : 3
                        color: root._gateOn ? root.palPrimary : Qt.alpha(root.palText, 0.45)
                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root._toggleGate() }
                }
                Text {
                    text: root._gateOn ? "standing" : "down"
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.alpha(root.palText, 0.55)
                    font.family: "3270 Nerd Font Mono, Fira Code, monospace"
                    font.pixelSize: 11
                }
            }
            Row {
                spacing: 10
                Text {
                    text: "attempts before stand-down"
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.alpha(root.palText, 0.85)
                    font.family: "3270 Nerd Font Mono, Fira Code, monospace"
                    font.pixelSize: 12
                }
                Text {
                    text: "−"
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.alpha(root.palText, 0.9)
                    font.family: "3270 Nerd Font Mono, Fira Code, monospace"
                    font.pixelSize: 15
                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor
                                onClicked: root._gateMaxAttempts = Math.max(1, root._gateMaxAttempts - 1) }
                }
                Text {
                    text: root._gateMaxAttempts
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.palText
                    font.family: "3270 Nerd Font Mono, Fira Code, monospace"
                    font.pixelSize: 12
                }
                Text {
                    text: "+"
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.alpha(root.palText, 0.9)
                    font.family: "3270 Nerd Font Mono, Fira Code, monospace"
                    font.pixelSize: 15
                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor
                                onClicked: root._gateMaxAttempts = Math.min(5, root._gateMaxAttempts + 1) }
                }
            }
            Text {
                text: root._mantraPass.length > 0
                    ? "key: a stored key is set — a right sequence unlocks"
                    : "key: none set — a right sequence opens the password field"
                color: Qt.alpha(root.palText, 0.7)
                font.family: "3270 Nerd Font Mono, Fira Code, monospace"
                font.pixelSize: 11
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "The gate deals the seven folds shuffled at every showing. Answer with the slot "
                    + "numbers — keys 1 to 7, or tap the cards — in your order of the folds, then invoke "
                    + "the seal (Enter). A wrong sequence redeals; after the attempt limit the gate "
                    + "stands down to the password field and stays down until a human stands it again. "
                    + "The switch is manual. The gate is a sequence in front of PAM: what PAM checks is "
                    + "a password — typed here, or the stored key a right sequence speaks. Standing "
                    + "choices live in theme.conf: MantraGate, MantraOrder, MantraAttempts, MantraPass. "
                    + "Changes in this panel last for this showing. kitsune-mantra, the companion, "
                    + "sets the standing choices from your session. Keys: h this hint, g the gate, "
                    + "\u2212 and + the attempts, esc closes."
                color: Qt.alpha(root.palText, 0.75)
                font.family: "3270 Nerd Font Mono, Fira Code, monospace"
                font.pixelSize: 11
                lineHeight: 1.3
            }
            Text {
                text: "done"
                anchors.horizontalCenter: parent.horizontalCenter
                color: Qt.alpha(root.palText, doneArea.containsMouse ? 0.95 : 0.6)
                font.family: "3270 Nerd Font Mono, Fira Code, monospace"
                font.pixelSize: 11
                font.letterSpacing: 2
                MouseArea { id: doneArea; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: root._settingsOpen = false }
            }
        }
    }

    // ---- The door's other duties: power ----------------------------------
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 22
        anchors.bottomMargin: 16
        spacing: 18
        z: 2

        Row {
            spacing: 7
            anchors.verticalCenter: parent.verticalCenter
            Text {
                text: "mantra"
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.alpha(root.palText, (mantraLabelArea.containsMouse || mantraArea.containsMouse) ? 0.95 : (root._gateOn ? 0.9 : 0.45))
                font.family: "3270 Nerd Font Mono, Fira Code, monospace"
                font.pixelSize: 11
                font.letterSpacing: 1.5
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Qt.alpha(root.palPrimary, 0.9)
                    shadowBlur: (mantraLabelArea.containsMouse || mantraArea.containsMouse) ? 0.75 : 0.0
                    shadowOpacity: (mantraLabelArea.containsMouse || mantraArea.containsMouse) ? 0.95 : 0.0
                    Behavior on shadowBlur { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                    Behavior on shadowOpacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                }
                MouseArea { id: mantraLabelArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root._toggleGate() }
            }
            Rectangle {
                width: 30; height: 16; radius: 8
                anchors.verticalCenter: parent.verticalCenter
                color: root._gateOn ? Qt.alpha(root.palPrimary, 0.35) : Qt.alpha("#0a0a12", 0.55)
                border.width: 1
                border.color: Qt.alpha(root.palText, root._gateOn ? 0.5 : 0.22)
                Behavior on color { ColorAnimation { duration: 150 } }
                Rectangle {
                    width: 10; height: 10; radius: 5
                    y: 2
                    x: root._gateOn ? 17 : 3
                    color: root._gateOn ? root.palPrimary : Qt.alpha(root.palText, 0.45)
                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                }
                MouseArea { id: mantraArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root._toggleGate() }
            }
        }
        Text {
            text: "reboot"
            color: Qt.alpha(root.palText, rebootArea.containsMouse ? 0.9 : 0.45)
            font.family: "3270 Nerd Font Mono, Fira Code, monospace"
            font.pixelSize: 11
            font.letterSpacing: 1.5
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.alpha(root.palPrimary, 0.9)
                shadowBlur: rebootArea.containsMouse ? 0.75 : 0.0
                shadowOpacity: rebootArea.containsMouse ? 0.95 : 0.0
                Behavior on shadowBlur { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                Behavior on shadowOpacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
            }
            MouseArea { id: rebootArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sddm.reboot() }
        }
        Text {
            text: "power off"
            color: Qt.alpha(root.palText, powerArea.containsMouse ? 0.9 : 0.45)
            font.family: "3270 Nerd Font Mono, Fira Code, monospace"
            font.pixelSize: 11
            font.letterSpacing: 1.5
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.alpha(root.palPrimary, 0.9)
                shadowBlur: powerArea.containsMouse ? 0.75 : 0.0
                shadowOpacity: powerArea.containsMouse ? 0.95 : 0.0
                Behavior on shadowBlur { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                Behavior on shadowOpacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
            }
            MouseArea { id: powerArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sddm.powerOff() }
        }
    }

    // ---- Entrance ---------------------------------------------------------
    Timer {
        id: manifestTimer; interval: 60; repeat: false
        onTriggered: {
            scene.aseWake();
            if (root._gateActive) {
                root._gateAttempts = 0;
                root._deal();
                root._setWhisper("the sigils are dealt · speak the mantra in its order");
                gateField.forceActiveFocus();
            } else {
                root._setWhisper("the sigils await · read the cards · invoke your sequence");
                passwordField.forceActiveFocus();
            }
            root.forceActiveFocus();
        }
    }
    Component.onCompleted: manifestTimer.restart()
    onVisibleChanged: if (visible) manifestTimer.restart()
}
