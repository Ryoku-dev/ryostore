import QtQuick

// Fūin 封印 — Jurai's Threshold, seated as an SDDM greeter theme.
//
// Threshold (Threshold.qml) is the shell's lock face, written against a
// small contract — the `gate` — and it never learns who checks the
// password. The shell seats it on PAM, greetd seats it on its daemon, and
// this file seats it on SDDM: the fourth host for the same face. Everything
// SDDM-specific lives here and in Config.qml; the face and its components
// stand as they are in the shell.
//
// The gate's terms, honoured below: `submit()` hands the password over;
// SDDM's answer comes back as `checking` clearing, `failed` + a `reason`
// sentence, or `leaving` rising (the face plays the welcome, then the
// session handover is SDDM's — the greeter may exit while the welcome is
// still on screen; the mechanism is kept faithful and the race is SDDM's
// own, as it is for every theme that welcomes).
Item {
    id: main

    // Unsized on purpose: the greeter sizes the root to its screen, as it
    // does for every theme (a root that sizes itself from Screen can be
    // left at 0 by a host whose screen geometry settles after creation).

    // ---- SDDM's models, read the way the shipped themes read them ---------

    readonly property bool haveUsers: typeof userModel !== "undefined" && userModel !== null
    readonly property bool haveSessions: typeof sessionModel !== "undefined" && sessionModel !== null

    property int userIndex: main.haveUsers && userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIndex: main.haveSessions && sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0

    readonly property var userObj: {
        if (!main.haveUsers || typeof userModel.get !== "function")
            return null;
        if (main.userIndex < 0 || main.userIndex >= userModel.rowCount())
            return null;
        return userModel.get(main.userIndex);
    }
    readonly property var sessionObj: {
        if (!main.haveSessions || typeof sessionModel.get !== "function")
            return null;
        if (main.sessionIndex < 0 || main.sessionIndex >= sessionModel.rowCount())
            return null;
        return sessionModel.get(main.sessionIndex);
    }

    readonly property string displayName: main.userObj ? (main.userObj.realName || main.userObj.name || "") : ""
    readonly property string loginName: main.userObj ? (main.userObj.name || "") : ""
    readonly property string sessionName: main.sessionObj ? (main.sessionObj.name || "") : ""

    // The icon role arrives as a path, a file URL, or empty.
    readonly property url avatarUrl: {
        const icon = main.userObj ? main.userObj.icon : "";
        if (!icon)
            return "";
        const s = String(icon);
        if (s.startsWith("/"))
            return "file://" + s;
        return s;
    }

    // The wallpaper knee: theme.conf's `background` is a path (empty = the
    // sealed door: the veiled Theme.background alone), `wallpaperMode`
    // its fit.
    readonly property string wallpaperPath: (typeof config !== "undefined" && config.background) ? String(config.background) : ""
    readonly property string wallpaperModeConf: (typeof config !== "undefined" && config.wallpaperMode) ? String(config.wallpaperMode) : "fill"
    readonly property string densityConf: (typeof config !== "undefined" && config.density) ? String(config.density) : "normal"
    readonly property bool twentyFourConf: !(typeof config !== "undefined" && String(config.twentyFourHour) === "false")

    // Caps lock, when the greeter exposes a keyboard witness; absent, the
    // word simply never shows.
    readonly property bool capsOn: (typeof keyboard !== "undefined" && keyboard) ? !!keyboard.capsLock : false

    // ---- The gate -----------------------------------------------------------

    QtObject {
        id: gate

        property string active: "primary"
        property string password: ""
        property bool checking: false
        property bool failed: false
        property string reason: ""
        property bool leaving: false

        property string fullName: main.displayName
        property string loginName: main.loginName
        property url avatar: main.avatarUrl
        property bool hasAvatar: avatar.toString().length > 0

        function avatarFailed() {
            avatar = "";
        }

        function wallpaperFor(screenName) {
            return main.wallpaperPath;
        }

        property string wallpaperMode: main.wallpaperModeConf
        property string density: main.densityConf
        property bool twentyFourHour: main.twentyFourConf

        function submit() {
            main.tryLogin();
        }

        // SDDM owns the session handover; there is nothing to enter here.
        function entered() {
        }
    }

    function tryLogin() {
        if (typeof sddm === "undefined" || !sddm)
            return;
        gate.checking = true;
        gate.failed = false;
        gate.reason = "";
        sddm.login(main.loginName, gate.password, main.sessionIndex);
    }

    Connections {
        target: (typeof sddm !== "undefined") ? sddm : null

        function onLoginFailed() {
            gate.checking = false;
            gate.failed = true;
            gate.reason = "That is not the password";
        }

        function onLoginSucceeded() {
            gate.checking = false;
            gate.leaving = true;
        }
    }

    // ---- The faces bundled with the theme ----------------------------------

    FontLoader { source: "fonts/Orbitron.ttf" }
    FontLoader { source: "fonts/Spectral-Regular.ttf" }
    FontLoader { source: "fonts/Spectral-Medium.ttf" }

    // ---- The door itself -----------------------------------------------------

    Rectangle {
        anchors.fill: parent
        color: Theme.background
    }

    Loader {
        id: faceLoader
        anchors.fill: parent
        sourceComponent: faceComponent

        // Threshold declares its gate `required`: a Loader component that
        // creates it without the gate in hand fails outright, so the gate
        // rides on the Loader and the component binds to it at creation.
        property var gateRef: gate

        onLoaded: if (item) item.focusField()
    }

    Component {
        id: faceComponent

        Threshold {
            gate: faceLoader.gateRef
            screen: ({ "name": "primary" })
            movable: false
            welcomes: true
        }
    }

    // ---- The greeter's necessities, at the foot ----------------------------
    //
    // A session lock has one user and no session to choose; a greeter can
    // have several of each. The choices live down here, in the face's own
    // typography, and only appear when a real choice exists. The face's
    // composition is untouched. Switching the user rebuilds the face, so
    // the field starts empty against the new name.

    function cycleUser() {
        if (!main.haveUsers || userModel.rowCount() < 2)
            return;
        main.userIndex = (main.userIndex + 1) % userModel.rowCount();
        gate.password = "";
        gate.avatar = main.avatarUrl;
        faceLoader.active = false;
        faceLoader.active = true;
    }

    function cycleSession() {
        if (!main.haveSessions || sessionModel.rowCount() < 2)
            return;
        main.sessionIndex = (main.sessionIndex + 1) % sessionModel.rowCount();
    }

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 28
        height: 22
        opacity: gate.leaving ? 0 : 1

        Behavior on opacity { NumberAnimation { duration: Timing.transition } }

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            visible: main.haveUsers && userModel.rowCount() > 1
            text: (main.displayName || main.loginName).toUpperCase()
            color: Theme.textMuted
            font.family: Typography.technical
            font.weight: Typography.weightLabel
            font.pixelSize: 11
            font.letterSpacing: Typography.tracking(11, Typography.labelTracking)

            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onClicked: main.cycleUser()
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            visible: main.capsOn
            text: "CAPS LOCK"
            color: Theme.alert
            font.family: Typography.technical
            font.weight: Typography.weightLabel
            font.pixelSize: 11
            font.letterSpacing: Typography.tracking(11, Typography.labelTracking)
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: main.haveSessions && sessionModel.rowCount() > 1
            text: main.sessionName.toUpperCase()
            color: Theme.textMuted
            font.family: Typography.technical
            font.weight: Typography.weightLabel
            font.pixelSize: 11
            font.letterSpacing: Typography.tracking(11, Typography.labelTracking)

            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onClicked: main.cycleSession()
            }
        }
    }

    Component.onCompleted: {
        if (faceLoader.item)
            faceLoader.item.focusField();
    }
}
