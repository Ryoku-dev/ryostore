import QtQuick
import Quickshell
import Quickshell.Wayland
import Ryoku.Ui.Singletons
import Quickshell.Io

// One transparent full-screen overlay per screen holding the island, its bubbles,
// banners and the Notification Center. Only those items take input (mask).
PanelWindow {
    id: win
    required property ShellScreen modelData
    screen: modelData
    readonly property string screenName: screen ? screen.name : ""
    readonly property bool focusedHere: Wm.focusedOutput === "" || Wm.focusedOutput === screenName

    // Hide everything while this monitor's workspace has a fullscreen window
    // (videos, games). Opening the island or the Notification Center still
    // works and brings it back until it is closed again.
    readonly property bool fullscreenHere: Wm.outputHasFullscreen(screenName)
    readonly property bool hiddenForFullscreen: fullscreenHere && !island.isExpanded && !island.isLauncher && !centerShown
    visible: !hiddenForFullscreen

    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true
    // the island itself always floats; space is reserved by `reserver` below
    exclusionMode: (Config.s.overlayBar || Config.s.reserveSpace) ? ExclusionMode.Ignore : ExclusionMode.Normal
    exclusiveZone: 0
    color: "transparent"

    readonly property bool centerShown: Notifs.centerOpen && Notifs.centerScreen === screenName
    readonly property bool interactive: island.isExpanded || island.isLauncher || centerShown || Notifs.replying || banners.hovered

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:island"
    WlrLayershell.keyboardFocus: interactive ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    mask: Region {
        item: island
        Region { item: island.bubble }
        Region { item: island.clockBubble }
        Region { item: banners.visible ? banners : null }
        Region { item: scrim.visible ? scrim : null }
        Region { item: clickAway.visible ? clickAway : null }
    }

    // ── Reserve a strip at the top (like a bar) so windows tile below the island ──
    // Invisible, takes no input. Zone = island bottom + 6px − the compositor's
    // outer gaps (a setting, since gaps are user config on both Hyprland and niri).
    property int gapsTop: Config.s.outerGaps
    PanelWindow {
        id: reserver
        screen: win.screen
        visible: Config.s.reserveSpace
        anchors.top: true
        anchors.left: true
        anchors.right: true
        implicitHeight: 1
        color: "transparent"
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: Math.max(0, Config.s.topMargin + 38 + 6 - win.gapsTop)
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "quickshell:island-reserve"
    }

    // Click-away without a compositor grab: while something is open the window
    // mask grows to the full screen and an underlay swallows the clicks, so a
    // press on the desktop closes the island instead of falling through.
    Rectangle {
        id: clickAway
        anchors.fill: parent
        color: "transparent"
        visible: win.interactive && scrim.opacity < 0.99
        z: 1
        MouseArea {
            anchors.fill: parent
            onPressed: {
                Hub.expanded = false;
                Notifs.centerOpen = false;
                Hub.launcherOpen = false;
                Notifs.replying = false;
            }
        }
    }

    // ── Notification Center backdrop: dims + (via the blur layerrule) frosts the desktop ──
    Rectangle {
        id: scrim
        anchors.fill: parent
        z: 2
        // dims the desktop behind the Notification Center (blur is a Hyprland layerrule upstream; here it is a plain dim)
        color: Theme.dark ? Qt.rgba(0, 0, 0, 0.46) : Qt.rgba(0.08, 0.08, 0.1, 0.40)
        opacity: win.centerShown ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Theme.reduced ? 1 : 220; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent; onClicked: Notifs.centerOpen = false }
    }

    NotificationCenter {
        id: center
        z: 3
        shown: win.centerShown
        screenName: win.screenName
        maxHeight: win.height - y - 16
        x: Math.round((win.width - width) / 2)
        y: Config.s.topMargin + 52
    }

    // Banners sit *under* the island so they appear to drop out of it
    BannerStack {
        id: banners
        z: 6
        active: Config.s.notifStyle !== "island" && win.focusedHere && !win.centerShown
        readonly property bool corner: Config.s.notifStyle === "corner"
        width: corner ? 370 : 400
        x: corner ? win.width - width - 14 : Math.round((win.width - width) / 2)
        y: corner ? (Config.s.overlayBar ? 48 : 10) : island.y + island.height + 10
        originY: corner ? 0 : -(island.height + 10)
        Behavior on y { enabled: !banners.corner; SpringAnimation { spring: Theme.spring; damping: Math.min(1, Theme.damping + 0.15) } }
    }

    Island {
        id: island
        z: 20
        screenName: win.screenName
        x: Math.round((win.width - width) / 2)
        y: Config.s.topMargin
    }
}
