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

    // Baked palette — matugen's word at install time (matches the
    // lock face's live palette the night this was built).
    readonly property color palBackground: "#12131c"
    readonly property color palText:       "#e3e1ef"
    readonly property color palPrimary:    "#bec2ff"
    readonly property color palSecondary:  "#ccc1e9"
    readonly property color palAlert:      "#f43f5e"

    property bool _checking: false
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
    Image {
        anchors.fill: parent
        source: "Backgrounds/wallpaper.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: root._leaving ? 0.3 : 0.9
            blurMax: 64
            brightness: root._leaving ? -0.05 : -0.25
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
            blur: root._leaving ? 0.3 : 0.9
            blurMax: 64
            brightness: root._leaving ? -0.05 : -0.25
            Behavior on blur { NumberAnimation { duration: 380; easing.type: Easing.OutQuad } }
            Behavior on brightness { NumberAnimation { duration: 380; easing.type: Easing.OutQuad } }
        }
    }
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(root.palBackground, 0.55)
    }

    // ---- Her scene (rides high — the fields hold the foot) --------------
    InseiScene {
        id: scene
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: parent.height * 0.84

        layout:          []
        tappedFolds:     root._tapped
        lockedCount:     root._bound
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
        readyToCast:     root._bound >= 7 && !root._checking && !root._leaving

        onCastRequested: root.attemptLogin()
    }

    // ---- The login (astronaut's call, letter for letter) -----------------
    function attemptLogin() {
        if (passwordField.text.length === 0 || root._checking || root._leaving) return;
        root._checking = true;
        root._setWhisper("the binding speaks · the seal yields…");
        const u = usernameField.text;
        sddm.login(config.AllowUppercaseLettersInUsernames == "false" ? u.toLowerCase() : u,
                   passwordField.text, sessionSelect.selectedSession);
    }

    Connections {
        target: sddm
        function onLoginSucceeded() {
            root._checking = false;
            root._leaving = true;
            root._tapped = root._foldIds.slice(0, 7);
            scene.aseTransform();
            root._setWhisper("the seal opens · welcome, 0xSrcAura");
        }
        function onLoginFailed() {
            root._checking = false;
            root._failed = true;
            scene.aseHurt();
            shake.restart();
            passwordField.text = "";
            root._lastLen = 0;
            root._tapped = [];
            resetError.restart();
            failWhisper.restart();
            passwordField.forceActiveFocus();
        }
    }
    Timer { id: resetError; interval: 2000; repeat: false; onTriggered: root._failed = false }
    Timer {
        id: failWhisper; interval: 150; repeat: false
        onTriggered: root._setWhisper("the binding refuses · login failed")
    }

    // ---- The fields, at the foot of her scene -----------------------------
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 36
        spacing: 9
        z: 2

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

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "0XSRCAURA"
            color: Qt.alpha(root.palText, 0.55)
            opacity: root._leaving ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 150 } }
            font.family: "3270 Nerd Font Mono, Fira Code, monospace"
            font.pixelSize: 13
            font.letterSpacing: 4
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

        Text {
            text: "reboot"
            color: Qt.alpha(root.palText, rebootArea.containsMouse ? 0.9 : 0.45)
            font.family: "3270 Nerd Font Mono, Fira Code, monospace"
            font.pixelSize: 11
            font.letterSpacing: 1.5
            MouseArea { id: rebootArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sddm.reboot() }
        }
        Text {
            text: "power off"
            color: Qt.alpha(root.palText, powerArea.containsMouse ? 0.9 : 0.45)
            font.family: "3270 Nerd Font Mono, Fira Code, monospace"
            font.pixelSize: 11
            font.letterSpacing: 1.5
            MouseArea { id: powerArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sddm.powerOff() }
        }
    }

    // ---- Entrance ---------------------------------------------------------
    Timer {
        id: manifestTimer; interval: 60; repeat: false
        onTriggered: {
            scene.aseWake();
            root._setWhisper("the sigils await · read the cards · invoke your sequence");
            passwordField.forceActiveFocus();
        }
    }
    Component.onCompleted: manifestTimer.restart()
}
