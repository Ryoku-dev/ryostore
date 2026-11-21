import QtQuick
import Quickshell
import Quickshell.Wayland

// One transparent full-screen overlay per screen holding the island, its
// bubbles, banners and the Notification Center. Only those take input (mask).
PanelWindow {
    id: win
    required property ShellScreen modelData
    screen: modelData
    readonly property string screenName: screen ? screen.name : ""
    readonly property bool focusedHere: Platform.focusedOutput === "" || Platform.focusedOutput === screenName

    // Hide everything while this output shows a fullscreen window (videos,
    // games). Opening the island or the Notification Center still brings it
    // back until it is closed again.
    readonly property bool fullscreenHere: Platform.outputHasFullscreen(screenName)
    readonly property bool hiddenForFullscreen: fullscreenHere && !island.isExpanded && !island.isLauncher && !centerShown
    visible: !hiddenForFullscreen

    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: true
    exclusionMode: (Config.s.overlayBar || Config.s.reserveSpace) ? ExclusionMode.Ignore : ExclusionMode.Normal
    exclusiveZone: 0
    color: "transparent"

    readonly property bool centerShown: Notifs.centerOpen && Notifs.centerScreen === screenName
    readonly property bool open: island.isExpanded || island.isLauncher || centerShown
    // keyboard: taken while something is open or a reply is being typed;
    // offered on demand while a banner is under the pointer, so clicking its
    // reply field can focus it
    readonly property bool interactive: open || Notifs.replying || banners.hovered || island.holdingNotif

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:island"
    WlrLayershell.keyboardFocus: open || Notifs.replying ? WlrKeyboardFocus.Exclusive
                               : interactive ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    mask: Region {
        item: island
        Region { item: island.bubble }
        Region { item: island.clockBubble }
        Region { item: banners.visible ? banners : null }
        Region { item: clickAway.visible ? clickAway : null }
    }

    // ── Reserve a strip at the top (like a bar) so windows tile below the island ──
    // Invisible, takes no input. Zone = island bottom + 6 px − the compositor's outer gaps.
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
        exclusiveZone: Math.max(0, Config.s.topMargin + 38 + 6 - Platform.outerGaps)
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "quickshell:island-reserve"
    }

    // ── Click-away ──
    // While anything is open the mask grows to the whole output and this
    // underlay takes the click, so a press on the desktop closes the island.
    // No compositor focus grab: a grab is what used to collapse the island
    // the moment a tray menu or another popup took focus.
    MouseArea {
        id: clickAway
        anchors.fill: parent
        z: 1
        visible: win.open || Notifs.replying
        acceptedButtons: Qt.AllButtons
        onPressed: {
            Hub.collapse();
            Notifs.endReplies();
        }
    }

    // ── Notification Center backdrop: dims the desktop ──
    Rectangle {
        id: scrim
        anchors.fill: parent
        z: 2
        color: Qt.rgba(0, 0, 0, 0.55)
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
        screenName: win.screenName
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
