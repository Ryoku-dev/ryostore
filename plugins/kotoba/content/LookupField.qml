import QtQuick
import Ryoku.PluginKit.Singletons

// A text field on the wallpaper layer is a HAZARD, not a convenience.
//
// Desktop.qml:707-713 grabs the keyboard for the entire wallpaper layer while a
// plugin's content root reports `editing: true`, and Desktop.qml:292 makes that
// grab WlrKeyboardFocus.Exclusive. If the flag ever sticks true, every keystroke
// on the desktop is swallowed until the shell restarts. The shell carries
// explicit teardown against this on its own widgets and its comments call the
// stuck state "stranded".
//
// So the contract here is:
//
//   1. `editing` is DERIVED from real focus and never assigned. No code path
//      can set it true on its own.
//   2. Every exit blurs: Escape, Enter, cancel, click-outside, the tile going
//      inactive, and destruction.
//   3. A watchdog force-blurs after idleTimeoutMs even if something unforeseen
//      holds focus, so the failure mode is self-healing rather than stranding.
//   4. This component is only ever built inside a Loader that is unloaded when
//      not looking a word up, so the common case cannot hold focus at all.
Item {
    id: lookup

    property real s: 1
    property var service: null
    property bool busy: false
    property string resultText: ""
    property string errorText: ""

    // (1) DERIVED. Never write to this.
    readonly property bool editing: input.visible && input.activeFocus

    // (3) how long a focused-but-idle field is tolerated before it is dropped
    readonly property int idleTimeoutMs: 45000

    property bool canSave: false

    signal submitted(string word)
    signal saveRequested()
    signal closed()

    implicitWidth: parent ? parent.width : 240 * lookup.s
    implicitHeight: col.implicitHeight

    function focusField() {
        input.forceActiveFocus();
        watchdog.restart();
    }

    // (2) the single exit everything funnels through
    function release() {
        input.focus = false;
        input.text = "";
        watchdog.stop();
        lookup.closed();
    }

    // (2) the tile going inactive must not leave a grab behind
    onVisibleChanged: if (!visible) release()
    Component.onDestruction: input.focus = false

    // (3) the watchdog. Restarted by every keystroke; if the field sits focused
    // and untouched, it lets go rather than holding the desktop's keyboard.
    Timer {
        id: watchdog
        interval: lookup.idleTimeoutMs
        repeat: false
        onTriggered: if (input.activeFocus) lookup.release()
    }

    Column {
        id: col
        width: parent.width
        spacing: 8 * lookup.s

        Rectangle {
            width: parent.width
            height: 30 * lookup.s
            radius: 8 * lookup.s
            color: Scheme.role("secondaryContainer", Theme.sheen)
            border.width: 1
            border.color: input.activeFocus ? Theme.accent : Scheme.line

            TextInput {
                id: input
                anchors.fill: parent
                anchors.leftMargin: 10 * lookup.s
                anchors.rightMargin: 10 * lookup.s
                verticalAlignment: TextInput.AlignVCenter
                color: Scheme.role("onSecondaryContainer", Theme.bright)
                font.family: Theme.fontJp
                font.pixelSize: 14 * lookup.s
                selectByMouse: true
                clip: true
                renderType: Text.NativeRendering

                // every keystroke resets the watchdog
                onTextChanged: if (activeFocus) watchdog.restart()

                // (2) Enter submits and blurs; Escape just blurs
                onAccepted: {
                    const w = text.trim();
                    input.focus = false;
                    watchdog.stop();
                    if (w.length > 0)
                        lookup.submitted(w);
                }
                Keys.onEscapePressed: lookup.release()

                // belt and braces: if focus is lost by any route at all, the
                // watchdog must not keep running against a dead field
                onActiveFocusChanged: if (!activeFocus) watchdog.stop()

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text.length === 0 && !input.activeFocus
                    text: "type a word"
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 12 * lookup.s
                }
            }
        }

        Text {
            width: parent.width
            visible: lookup.busy || lookup.resultText.length > 0 || lookup.errorText.length > 0
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: lookup.busy ? "looking up…"
                 : lookup.errorText.length > 0 ? lookup.errorText
                 : lookup.resultText
            color: lookup.errorText.length > 0 ? Theme.accent : Theme.dim
            font.family: Theme.font
            font.pixelSize: 11 * lookup.s
        }

        // Offered only once a lookup actually matched something.
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: lookup.canSave && !lookup.busy
            width: 96 * lookup.s
            height: 24 * lookup.s
            radius: 7 * lookup.s
            readonly property color rest: Scheme.role("primaryContainer", Theme.threadBg)
            color: saveHover.containsPress ? Qt.darker(rest, 1.18)
                 : saveHover.hovered       ? Qt.lighter(rest, 1.14)
                                           : rest
            border.width: 1
            border.color: Scheme.line

            Text {
                anchors.centerIn: parent
                text: "save to deck"
                color: Scheme.role("onPrimaryContainer", Theme.bright)
                font.family: Theme.font
                font.pixelSize: 10 * lookup.s
            }

            HoverHandler { id: saveHover }
            TapHandler { onTapped: lookup.saveRequested() }
        }
    }

    // (2) a click anywhere outside the field blurs it. Sits BELOW the field in
    // z-order so it never eats the field's own clicks.
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: lookup.release()
    }
}
