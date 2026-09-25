pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

// Lock-state view for the MJW kit: the session-lock marker qylock touches
// while the screen is locked, polled on a timer (a plugin cannot read the
// shell's GlobalStates). Used only to dim or switch widget faces while locked.
Singleton {
    id: root

    property bool screenLocked: false
    // Spectrum frames for the visualizer tile: the plugin's own service writes
    // these from its cava process; singletons are per-plugin so tiles cannot
    // cross-feed each other.
    property list<real> visualizerPoints: []
    property bool settingsOpen: false
    property bool sessionOpen: false

    readonly property string marker: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp")
        + "/qylock.locked"

    Process {
        id: probe
        command: ["test", "-e", root.marker]
        onExited: (code) => root.screenLocked = (code === 0)
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }
}
