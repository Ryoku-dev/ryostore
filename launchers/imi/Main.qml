//@ pragma UseQApplication

import QtQuick
import Quickshell
import "modules"
import "services"

// The imi launcher: the barstyle's overview search (SearchWidget and its panels), ported to run as a Ryoku store launcher.
Scope {
    id: root

    // ===== the launcher contract =====
    // `shown` stays true while the fade-out plays, then settles false once
    // the surface says it has finished closing (with a timer as the fallback
    // for a hide before the first frame).
    property bool openRequested: false
    property string monitor: ""
    property bool closing: false
    readonly property bool shown: root.openRequested || root.closing

    readonly property var hostScreen: {
        const list = Quickshell.screens
        if (root.monitor) {
            for (const s of list) {
                if (s.name === root.monitor)
                    return s
            }
        }
        return Quickshell.primaryScreen ?? (list.length > 0 ? list[0] : null)
    }

    function show(mon) {
        if (mon)
            root.monitor = mon
        surface.active = true
        root.closing = false
        root.openRequested = true
    }

    function hide() {
        if (!root.openRequested && !root.closing)
            return
        // `shown` is their OR: flip `closing` first so the window is never
        // unmapped for the turn between the two assignments.
        root.closing = true
        root.openRequested = false
    }

    function toggle(mon) {
        if (root.openRequested || root.closing)
            root.hide()
        else
            root.show(mon)
    }

    function stateDump() {
        return { open: root.openRequested, query: LauncherSearch.query }
    }

    // The surface clears `closing` when its fade-out finishes; this settles
    // the host anyway if the surface never got to play it.
    Timer {
        id: closeSettler
        interval: 300
        onTriggered: root.closing = false
    }

    onClosingChanged: {
        if (root.closing)
            closeSettler.restart()
        else
            closeSettler.stop()
    }

    // Built with the shell, not on the first key press: building it inside
    // show() would cost the opening animation its first frames. Maps nothing
    // until `shown` goes true.
    Loader {
        id: surface

        active: true
        asynchronous: true
        sourceComponent: Component {
            LauncherSurface {
                host: root
                onFinishedClosing: root.closing = false
            }
        }
    }
}
