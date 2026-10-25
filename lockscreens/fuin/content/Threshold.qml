import QtQuick
import QtQuick.Effects

// The threshold: what stands between a person and the desktop, on one screen.
// The lock screen and the greeter are both this; what differs is the surface
// that holds it and who checks the password — PAM for the lock, greetd for the
// greeter. So both wear the shell's own appearance, from one place (Akusen,
// 2026-09-27).
//
// Every screen gets the wallpaper, blurred and veiled: nothing behind it can
// be read. Only the screen the mudra is on holds anything else — the time
// and the bell's face, the date, who this is and the field. Two fields would
// be two places to type into and one of them deaf.
//
// Nothing moves on its own once it is there. It arrives from where it starts —
// the desktop it covers, or the wallpaper, sharp — blurring into the veiled
// picture, and the composition follows, one element after the next; it leaves
// the same way backwards. Between the two the only change is the minute.
//
// The greeter leaves differently (`welcomes`): the person stays — the
// portrait and the name — while the rest goes, "Welcome to" and the logotype
// open out from under the name, and then the whole screen fades to black.
// What follows it is the session's compositor starting on a black screen, so
// the handover has no seam (Akusen, 2026-09-27).
//
// `gate` is the state it reads and writes:
//
//   active            the screen that holds the field
//   password, checking, failed, reason, leaving
//   submit()          the field was accepted
//   fullName, avatar, hasAvatar, avatarFailed()
//   wallpaperFor(screenName), wallpaperMode, density, twentyFourHour
//   captureFor(screenName)   optional: a photograph to start from
//   entered()         optional: called when a welcome has faded to black —
//                     by every screen, so the owner acts on the first
Item {
    id: root

    required property var gate
    // The screen this is drawn on.
    property var screen: null
    // Whether a press on another screen brings the field there. The lock
    // allows it; the greeter keeps it on the primary screen.
    property bool movable: true
    // Whether leaving welcomes the person in, rather than clearing back to
    // the desktop. The greeter's way: there is no desktop behind it yet.
    property bool welcomes: false

    readonly property bool active: root.screen && root.gate.active === root.screen.name
    readonly property var metrics: Metrics.step(root.gate.density)
    readonly property real factor: metrics.factor

    anchors.fill: parent

    // ---- Arriving and leaving -----------------------------------------------------

    // 0 is where the gate starts from, sharp — the desktop as it was, or
    // the wallpaper; 1 is the wallpaper blurred and veiled. The blur, the photograph and the veil all follow this one value.
    property real dissolve: 0

    // The composition, one element after another: each takes `Timing.open`,
    // the next one starting `stagger` after it.
    property real cascade: 0
    readonly property int stagger: Timing.stagger * 3
    readonly property int steps: 6
    readonly property real cascadeSpan: Timing.open + (steps - 1) * stagger

    // ---- Valence ---------------------------------------------------------------
    //
    // The prism that rims the glass: a slow walk around the spectrum, anchored
    // at violet. Subtle enough to mistake for stillness until it is watched —
    // gradient radiance, never glow. The theme is named for the atom's outer
    // shell, where everything bonds; this light is that shell, refracting.
    property real prismPhase: 0

    NumberAnimation on prismPhase {
        from: 0
        to: 1
        duration: 36000
        loops: Animation.Infinite
        running: root.active
    }

    function prismColor(strength) {
        return Qt.hsva((root.prismPhase + 0.72) % 1.0, 0.55, 1.0, strength);
    }

    // How far element `index` has arrived, eased out: it starts quickly and
    // settles, like every opening in the shell.
    function arrived(index) {
        const elapsed = root.cascade * root.cascadeSpan - index * root.stagger;
        const linear = Math.max(0, Math.min(1, elapsed / Timing.open));
        return 1 - Math.pow(1 - linear, 3);
    }

    SequentialAnimation {
        id: arrival
        running: true

        ParallelAnimation {
            // The wallpaper's own crossfade, and its curve: slow at both ends,
            // so the desktop is seen to melt rather than to vanish.
            NumberAnimation {
                target: root
                property: "dissolve"
                to: 1
                duration: Timing.wallpaper
                easing.type: Easing.InOutQuad
            }

            SequentialAnimation {
                PauseAnimation { duration: Timing.open }
                NumberAnimation {
                    target: root
                    property: "cascade"
                    to: 1
                    duration: root.cascadeSpan
                }
            }
        }
    }

    // Leaving: the composition goes quickly, last element first, then the
    // picture clears back to the desktop. whoever owns the gate acts when both are done.
    SequentialAnimation {
        id: departure

        NumberAnimation {
            target: root
            property: "cascade"
            to: 0
            duration: Timing.close
        }

        NumberAnimation {
            target: root
            property: "dissolve"
            to: 0
            duration: Timing.open
            easing.type: Easing.InOutQuad
        }
    }

    // Welcoming: the portrait and the name are kept while the rest goes; the
    // welcome opens under the name, one line after the next, stays long
    // enough to be read, and the screen fades to black.
    property real kept: 0
    property real greeting: 0
    property real dark: 0
    readonly property real greetingSpan: Timing.welcomeOpen + 3 * Timing.welcomeStagger

    function greeted(index) {
        const elapsed = root.greeting * root.greetingSpan - index * Timing.welcomeStagger;
        const linear = Math.max(0, Math.min(1, elapsed / Timing.welcomeOpen));
        return 1 - Math.pow(1 - linear, 3);
    }

    SequentialAnimation {
        id: welcome

        PropertyAction {
            target: root
            property: "kept"
            value: 1
        }

        // Not the quick close of the lock: the rest steps back to make room.
        NumberAnimation {
            target: root
            property: "cascade"
            to: 0
            duration: Timing.open
        }

        NumberAnimation {
            target: root
            property: "greeting"
            to: 1
            duration: root.greetingSpan
        }

        PauseAnimation { duration: Timing.welcome }

        // Slower than the picture arrived: the screen is seen to darken, not
        // to go out.
        NumberAnimation {
            target: root
            property: "dark"
            to: 1
            duration: Timing.welcomeFade
            easing.type: Easing.InOutQuad
        }

        ScriptAction {
            script: if (root.gate.entered) root.gate.entered()
        }
    }

    Connections {
        target: root.gate
        function onLeavingChanged() {
            if (!root.gate.leaving)
                return;
            arrival.stop();
            if (root.welcomes)
                welcome.start();
            else
                departure.start();
        }
    }

    // ---- Behind ------------------------------------------------------------------

    // How far the blurred picture runs past the screen's edges. A blur fades to
    // nothing at the edge of what it blurs, and a picture blurred only to the
    // screen's edge would be a picture with a dark frame.
    readonly property real bleed: 96

    Item {
        x: -root.bleed
        y: -root.bleed
        width: root.width + root.bleed * 2
        height: root.height + root.bleed * 2
        clip: root.gate.wallpaperMode === "span"

        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: root.dissolve
            blurMax: 64
            autoPaddingEnabled: false
        }

        WallpaperImage {
            source: root.screen ? root.gate.wallpaperFor(root.screen.name) : ""
            mode: root.gate.wallpaperMode
            screen: root.screen
            density: 0.25
        }

        // The desktop as it was, over the wallpaper, until the dissolve takes
        // it. Loaded before the first frame, or the lock would open on the
        // wallpaper and then flash to the desktop.
        Image {
            x: root.bleed
            y: root.bleed
            width: root.width
            height: root.height
            opacity: 1 - root.dissolve
            visible: opacity > 0 && status === Image.Ready
            source: root.screen && root.gate.captureFor
                    ? "file://" + root.gate.captureFor(root.screen.name) : ""
            asynchronous: false
            cache: false
            fillMode: Image.Stretch
        }
    }

    // The veil: the picture is a place, not something to look at, and the
    // text on it has to hold on any image.
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Theme.background, 0.38)
        opacity: root.dissolve
    }

    // A press anywhere on a screen that does not hold the field brings it here
    // — where the gate allows it to move at all.
    TapHandler {
        enabled: root.movable && !root.active
        onTapped: if (root.screen) root.gate.active = root.screen.name
    }

    // ---- In front, where the mudra is -------------------------------------------

    SystemClock {
        id: bell
        precision: SystemClock.Seconds
    }

    // The second hand, continuous: see MinuteHand.qml.
    MinuteHand {
        id: hand
    }

    // What the keypad's keys mean with num lock off, read as the figures
    // printed on them.
    readonly property var keypad: ({
        [Qt.Key_Insert]: "0", [Qt.Key_End]: "1", [Qt.Key_Down]: "2",
        [Qt.Key_PageDown]: "3", [Qt.Key_Left]: "4", [Qt.Key_Clear]: "5",
        [Qt.Key_Right]: "6", [Qt.Key_Home]: "7", [Qt.Key_Up]: "8",
        [Qt.Key_PageUp]: "9", [Qt.Key_Delete]: "."
    })

    readonly property string time: {
        const hours = root.gate.twentyFourHour
                      ? String(bell.hours).padStart(2, "0")
                      : String(bell.hours % 12 === 0 ? 12 : bell.hours % 12);
        return `${hours}:${String(bell.minutes).padStart(2, "0")}`;
    }

    Column {
        id: composition

        anchors.horizontalCenter: parent.horizontalCenter
        // A little above the middle: the eye's centre of a screen is higher
        // than its geometric one.
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -root.height * 0.06

        visible: root.active
        spacing: 0

        // Insei keeps this door. Her medallion is first in the cascade: a
        // prism-rimmed circle of glass with her state breathing at its centre
        // — quick when she speaks, slow when she dreams. When she is not
        // present — unwritten, stale, gone — it is not shown at all; absence
        // is the rule everywhere she is concerned.
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: Insei.available
            opacity: root.arrived(0)
            spacing: 8 * root.factor

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 54 * root.factor
                height: width
                radius: width / 2
                color: Qt.alpha(Theme.background, 0.35)
                antialiasing: true
                border.width: Metrics.crisp(1.5, Screen.devicePixelRatio)
                border.color: root.prismColor(0.75)

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.38
                    height: width
                    radius: width / 2
                    color: root.prismColor(0.5)

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: root.active && Insei.available
                        NumberAnimation { to: 0.4; duration: Insei.state === "speaking" ? 480 : 1900; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: Insei.state === "speaking" ? 480 : 1900; easing.type: Easing.InOutSine }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "INSEI · " + Insei.state.toUpperCase()
                color: Theme.textMuted
                font: Qt.font({
                    "family": Typography.technical,
                    "pixelSize": root.metrics.fontLabel,
                    "weight": Typography.weightLabel,
                    "letterSpacing": Typography.tracking(root.metrics.fontLabel,
                                                         Typography.labelTracking)
                })
            }
        }

        Item {
            width: 1
            height: Insei.available ? 20 * root.factor : 0
        }

        // The time is the bell's, and the bell is a human thing: the
        // expressive voice, with tabular figures so the minute does not move
        // the line. Beside it, the bell apsara's own face — the hour filling,
        // the minute going round — as tall as the figures.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(time.font.pixelSize * 0.22)
            opacity: root.arrived(1)
            transform: Translate { y: (1 - root.arrived(1)) * 4 * root.factor }

            Text {
                id: time
                anchors.verticalCenter: parent.verticalCenter
                text: root.time
                color: Theme.text
                font: Typography.tabular(Qt.font({
                    "family": Typography.expressive,
                    "pixelSize": Math.round(112 * root.factor),
                    "weight": Typography.weightValue
                }))
            }

            Dial {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(time.font.pixelSize * 0.62)
                height: width
                fraction: (bell.minutes * 60 + bell.seconds) / 3600
                orbit: hand.value
                orbitEased: false
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: root.arrived(2)
            transform: Translate { y: (1 - root.arrived(2)) * 4 * root.factor }
            text: bell.date.toLocaleDateString(Qt.locale("en_GB"), "dddd d MMMM").toUpperCase()
            color: Theme.textMuted
            font: Qt.font({
                "family": Typography.technical,
                "pixelSize": root.metrics.fontSecondary,
                "weight": Typography.weightLabel,
                "letterSpacing": Typography.tracking(root.metrics.fontSecondary,
                                                     Typography.labelTracking)
            })
        }

        Item { width: 1; height: 72 * root.factor }

        // The avatar as the Door apsara wears it at rest — the portrait in a
        // round apsara of its own, glass and lit rim — at the lock's scale: 30 in
        // 40 there, the same proportion here. The person is the same one the
        // hem shows (Akusen, 2026-09-27).
        Item {
            id: badge

            readonly property real portrait: 76 * root.factor
            // The Door apsara's radius, which follows the Appearance page:
            // round at 100 %, squarer below it. The portrait inside stays a
            // circle, as it does in the apsara.
            readonly property real radius: Metrics.radiusFor(height, root.metrics)

            anchors.horizontalCenter: parent.horizontalCenter
            readonly property real shown: Math.max(root.arrived(3), root.kept)

            width: portrait * (Metrics.cellHeight / 30)
            height: width
            opacity: shown
            transform: Translate { y: (1 - badge.shown) * 4 * root.factor }

            Rectangle {
                anchors.fill: parent
                radius: badge.radius
                color: Qt.alpha(Theme.apsara, Config.get("apsara.opacity", 0.72))
                antialiasing: true
            }

            Rim {
                anchors.fill: parent
                radius: badge.radius
            }

            Portrait {
                anchors.centerIn: parent
                width: badge.portrait
                height: width
                source: root.gate.avatar
                available: root.gate.hasAvatar
                onFailed: root.gate.avatarFailed()
            }
        }

        Item { width: 1; height: 14 * root.factor }

        Text {
            id: fullName

            readonly property real shown: Math.max(root.arrived(4), root.kept)

            anchors.horizontalCenter: parent.horizontalCenter
            opacity: shown
            transform: Translate { y: (1 - fullName.shown) * 4 * root.factor }
            text: root.gate.loginName ? root.gate.loginName.toUpperCase() : ""
            color: Theme.text
            font.family: Typography.expressive
            font.pixelSize: Math.round(20 * root.factor)
        }

        // Two shapes apart by the shell's own gap between shapes.
        Item { width: 1; height: root.metrics.gap }

        // ---- The field ---------------------------------------------------------

        Item {
            id: field

            // It grows from its middle to its width, as a capsule opens into
            // a panel: animated in width, never scaled, so the outline and the
            // curve of its caps stay what they are.
            readonly property real grown: root.arrived(5)

            anchors.horizontalCenter: parent.horizontalCenter
            width: height + (300 * root.factor - height) * field.grown
            height: 44 * root.factor

            // Waiting on PAM, the field says so by stepping back rather than
            // by a spinner: nothing here moves without a value behind it.
            opacity: Math.min(field.grown * 2, 1) * (root.gate.checking ? 0.6 : 1)

            Rectangle {
                anchors.fill: parent
                radius: Metrics.radiusFor(height, root.metrics)
                antialiasing: true
                color: Qt.alpha(Theme.lift(Theme.background, -0.01),
                                Config.get("apsara.opacity", 0.72))
                border.width: Metrics.crisp(1.5, Screen.devicePixelRatio)
                // Valence: the field's rim is the prism — full when the hand
                // is in it, a held breath otherwise; failure still speaks in
                // the alert's own voice, at once.
                border.color: root.gate.failed ? Theme.alert
                            : secret.activeFocus ? root.prismColor(0.9)
                            : root.prismColor(0.32)
            }

            // What is inside comes in once the shape is nearly at size.
            readonly property real inside: Math.max(0, (field.grown - 0.7) / 0.3)

            Text {
                anchors.centerIn: parent
                visible: secret.text.length === 0
                opacity: field.inside
                text: "Password"
                color: Theme.textMuted
                font.family: Typography.expressive
                font.pixelSize: root.metrics.fontSecondary
            }

            TextInput {
                id: secret

                anchors.fill: parent
                opacity: field.inside
                anchors.leftMargin: 20 * root.factor
                anchors.rightMargin: 20 * root.factor
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                clip: true

                echoMode: TextInput.Password
                passwordCharacter: "•"
                color: Theme.text
                selectionColor: Qt.alpha(Theme.primary, 0.35)
                selectedTextColor: Theme.text
                font.family: Typography.expressive
                font.pixelSize: Math.round(16 * root.factor)
                readOnly: root.gate.checking

                focus: root.active

                onTextEdited: {
                    root.gate.password = text;
                    root.gate.failed = false;
                }

                onAccepted: root.gate.submit()

                // The keypad types figures whether num lock is on or not.
                // niri turns it on only when it starts, and every reload of
                // the keymap — a layout changed from the mudra apsara — turns
                // it off again, so a password with figures in it would
                // otherwise depend on what happened to the keymap since login.
                Keys.onPressed: event => {
                    if (!(event.modifiers & Qt.KeypadModifier))
                        return;
                    const figure = root.keypad[event.key];
                    if (figure === undefined || secret.readOnly)
                        return;
                    if (secret.selectedText.length > 0)
                        secret.remove(secret.selectionStart, secret.selectionEnd);
                    secret.insert(secret.cursorPosition, figure);
                    root.gate.password = secret.text;
                    root.gate.failed = false;
                    event.accepted = true;
                }

                // Escape empties the field: the one way back from a password
                // typed wrong, other than typing over it.
                Keys.onEscapePressed: {
                    secret.clear();
                    root.gate.password = "";
                    root.gate.failed = false;
                }
            }

            // A wrong password leaves what was typed where it was, selected:
            // the next key replaces it, and nothing had to be typed twice to
            // find out what was wrong.
            Connections {
                target: root.gate
                function onFailedChanged() {
                    if (root.gate.failed)
                        secret.selectAll();
                }
            }
        }

        Item { width: 1; height: 10 * root.factor }

        // Errors live where they happened, in a sentence.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: root.gate.failed ? 1 : 0
            text: root.gate.reason
            color: Theme.alert
            font.family: Typography.expressive
            font.pixelSize: root.metrics.fontSecondary

            Behavior on opacity { NumberAnimation { duration: Timing.transition } }
        }
    }

    // ---- The welcome ---------------------------------------------------------

    // Where the field was, and from the name down: each line comes in from
    // just above, as if let out of the name.
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: composition.y + field.y

        visible: root.active && root.greeting > 0
        spacing: 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: root.greeted(0)
            transform: Translate { y: (1 - root.greeted(0)) * -4 * root.factor }
            text: "Welcome to"
            color: Theme.textMuted
            font.family: Typography.expressive
            font.pixelSize: Math.round(18 * root.factor)
        }

        Item { width: 1; height: 20 * root.factor }

        Logotype {
            anchors.horizontalCenter: parent.horizontalCenter
            width: implicitWidth
            height: implicitHeight
            markHeight: Math.round(112 * root.factor)
            markShown: root.greeted(1)
            nameShown: root.greeted(2)
            lineShown: root.greeted(3)
            travel: -4 * root.factor
        }
    }

    // The dark the welcome ends in. Plain black, not the palette's background:
    // it is the colour of the screen between the greeter's compositor and the
    // session's, which is no colour at all.
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: root.dark
        visible: opacity > 0
    }

    // The field on this screen takes the keys whenever this becomes the screen
    // that holds it; the surface calls it again once it is mapped.
    function focusField() {
        if (root.active)
            secret.forceActiveFocus();
    }

    onActiveChanged: root.focusField()
}
