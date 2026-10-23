import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import Ryoku.Ui.Singletons
import "../../../services"
import "../../../modules/common"
import "../../../modules/common/widgets"
import "../../../modules/tansu/mediaControls"

// One of the files that talk to the system (the others: MediaSource.qml
// for MPRIS, TraySource.qml + TrayPopups.qml for the tray,
// NotificationSource.qml for notifications).
// Status_Bar.qml stays pure UI: this feeds it Hyprland + clock + media
// + tray data and turns its signals into actions.
PanelWindow {
    id: win

    // One entry of shell.qml's bar model: { screen, position }. The edge is
    // part of the entry on purpose — this window is built for one edge and
    // never moves: when the bar is moved, the entry changes, this window
    // is dropped and a fresh one is built on the new edge (see the
    // comment on `bars` in shell.qml).
    required property var modelData
    screen: modelData.screen

    required property var traySource

    required property var quickPanel

    required property var picker

    readonly property string barPosition: modelData.position
    readonly property bool vertical: win.barPosition === "left" || win.barPosition === "right"
    anchors {
        top: win.barPosition !== "bottom"
        bottom: win.barPosition !== "top"
        left: win.barPosition !== "right"
        right: win.barPosition !== "left"
    }
    readonly property real uiScale: ShellScale.forScreen(win.screen) * ShellScale.barScale
    readonly property real thickness: BarPositionService.thicknessFor(win.barPosition)
    readonly property real stripSize: Math.round((win.barStyle === 3 ? (win.vertical ? Theme.capStripV : Theme.capStrip)
    : win.thickness) * win.uiScale)

    readonly property bool editing: false
    // The window is only the strip plus a few pixels of room, except while this monitor is in
    // Edit Desktop (EditStage below shrinks the whole picture into a card and needs the
    // whole screen). Why: a Qt window reports its whole surface as changed whenever it
    // draws, so a screen-sized transparent bar made Hyprland re-composite (and re-blur, if
    // blur is on) the entire screen for every frame the bar drew, and kept it busy at idle
    // (measured: Hyprland ~22 % of the iGPU with the bar, ~3 % without it, qs itself <1 %).
    // The window stays anchored to its edge and to both neighbouring edges, so the strip is
    // in the same place on screen and every position in this file (mask, popupX / popupY,
    // the status bar's x / y) keeps working in window pixels: they are all measured from
    // the edge the bar sits on. The room is for the popups' anchor points, which sit a few
    // pixels past the strip. `ipc call options set bar.compactWindow false` goes back to
    // the screen-sized window.
    //
    // Only for a bar on the TOP or LEFT edge. A layer-shell window anchored to the bottom or the
    // right edge that changes size shows its old picture at the new surface's top-left corner for
    // a frame or two, so a bottom bar jumped to the top of the screen (and a right bar to the
    // left) every time Edit Desktop started or ended and the window grew / shrank. A top or left
    // window grows away from its own origin, so the old picture is still in the right place.
    // The bottom and right edges therefore keep the screen-sized window (see EditMode.qml's
    // header: the same reason the bar and the dock never resized before this).
    readonly property bool growsFromOrigin: win.barPosition === "top" || win.barPosition === "left"
    readonly property bool compactWindow: SettingsService.flag("bar.compactWindow") && !win.editing && win.growsFromOrigin
    // (Only the popups' anchor points and the hover tags' anchor boxes sit past the strip, and
    // those are separate popup windows now, so a few pixels is enough. Smaller = less for
    // Hyprland to composite; if a popup ever looks mis-placed, raise the 8.)
    readonly property real windowRoom: Math.ceil(8 * win.uiScale)
    implicitHeight: win.vertical ? 0 : (win.screen
    ? (win.compactWindow ? Math.min(Math.round(win.screen.height), win.stripSize + win.windowRoom)
    : Math.round(win.screen.height))
    : win.stripSize)
    implicitWidth: win.vertical ? (win.screen
    ? (win.compactWindow ? Math.min(Math.round(win.screen.width), win.stripSize + win.windowRoom)
    : Math.round(win.screen.width))
    : win.stripSize) : 0
    // An auto-hiding bar never holds space: the windows take it and the bar
    // floats over them while it is up.
    exclusionMode: win.autoHide ? ExclusionMode.Ignore : ExclusionMode.Normal
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // Transparent style: the pills sit straight on the wallpaper, so the space
    // under (or beside) them should be small. Two things are taken off what the
    // bar reserves:
    //  - Hyprland's `general.gaps_out`, which it adds between the reserved strip
    //    and the windows. The pills are centred in the strip, so this alone
    //    makes the gap to the windows equal to the gap to the screen edge.
    //  - `transparentExtraGap` more, so the windows sit a little closer than
    //    that. Make this number bigger for a smaller gap, 0 for the equal one.
    // Float and Straight keep the full strip (the bar is a visible object
    // there). Follows the Hyprland setting live.
    readonly property real transparentExtraGap: 5
    readonly property real transparentTrim: win.barStyle === 2
        ? Math.min(Math.round(win.transparentExtraGap * win.uiScale), Math.round(win.stripSize * 0.6))
        : 0
    exclusiveZone: win.autoHide ? 0 : win.stripSize - win.transparentTrim
    color: "transparent"

    readonly property bool gameMode: false
    readonly property bool passive: win.editing || win.gameMode

    // Auto-hide: the bar slides off its edge, reserves no space, and comes back
    // when the pointer reaches the edge. A popup of its own keeps it out.
    readonly property bool autoHide: SettingsService.flag("bar.autohide") && !win.passive
    property bool autoReveal: false
    readonly property bool popupsOpen: win.trayOpen || win.mediaPopupOpen || win.batteryPopupOpen
        || win.resourcePopupOpen || win.calendarPopupOpen || win.weatherPopupOpen || win.utilPopupOpen
    readonly property bool barOut: PresetMotion.barOut || (win.autoHide && !win.autoReveal)
    // While it is away only a thin strip of the edge takes input, so clicks and
    // the desktop reach the screen; the strip is what brings it back.
    readonly property real maskThickness: win.autoHide && !win.autoReveal
        ? Math.max(2, Math.round(3 * win.uiScale)) : win.stripSize

    onAutoHideChanged: if (!win.autoHide) win.autoReveal = false
    onBarOutChanged: win.syncSlide()
    onPopupsOpenChanged: {
        if (win.popupsOpen) {
            win.autoReveal = true
            hideTimer.stop()
        } else {
            hideTimer.restart()
        }
    }

    function syncSlide() {
        if (win.barOut) {
            slideIn.stop()
            slideOut.restart()
        } else {
            slideOut.stop()
            slideIn.restart()
        }
    }
    readonly property var gameLayout: ({ left: [], center: ["date", "clock", "weather"], right: [] })

    // Only the strip takes input, and nothing while editing or in Game Mode (1 px
    // in the corner, which is never part of the card).
    // A bar on the bottom edge also gives up the Quick Panel's hot edge (the strip at the
    // bottom centre, QuickPanel.qml): that spot is cut out of the bar's input region, so the
    // pointer reaches the hot-edge window under it. (Same width / height / centring as that
    // window; the bar's pills never reach the last 4 px of the strip.)
    mask: Region {
        item: barMask
        regions: [ Region { item: hotCut; intersection: Intersection.Subtract } ]
    }
    Item {
        id: hotCut
        readonly property bool on: win.barPosition === "bottom" && !win.passive
        && win.quickPanel !== null && win.quickPanel.hotEdge
        width: on ? Math.min(win.width, win.quickPanel.hotWidth) : 0
        height: on ? win.quickPanel.hotHeight : 0
        x: (win.width - width) / 2
        y: win.height - height
    }
    Item {
        id: barMask
        x: win.passive ? 0 : (win.barPosition === "right" ? win.width - win.maskThickness : 0)
        y: win.passive ? 0 : (win.barPosition === "bottom" ? win.height - win.maskThickness : 0)
        width: win.passive ? 1 : (win.vertical ? win.maskThickness : win.width)
        height: win.passive ? 1 : (win.vertical ? win.height : win.maskThickness)
    }

    readonly property real popupGap: win.barStyle === 3 ? 0 : 4
    function popupX(cx, cy, w, h) {
        if (win.vertical)
            return win.barPosition === "left" ? win.stripSize + win.popupGap : win.width - win.stripSize - win.popupGap
            const maxX = win.width - w - 8
            return Math.max(8, Math.min(cx - w / 2, maxX))
    }
    function popupY(cx, cy, w, h) {
        if (!win.vertical)
            return win.barPosition === "bottom" ? win.height - win.stripSize : win.stripSize
            const maxY = win.height - h - 8
            return Math.max(8, Math.min(cy - h / 2, maxY))
    }
    readonly property int popupGravity: {
        if (win.vertical)
            return win.barPosition === "left" ? (Edges.Bottom | Edges.Right)
            : (Edges.Bottom | Edges.Left)
            return win.barPosition === "bottom" ? (Edges.Top | Edges.Right)
            : (Edges.Bottom | Edges.Right)
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Timer {
        id: hideTimer
        interval: 550
        onTriggered: {
            if (win.autoHide && !win.popupsOpen && !barHover.hovered)
                win.autoReveal = false
        }
    }

    property bool trayOpen: false

    readonly property bool trayAvailable: traySource.unpinnedItems.length > 0
    onTrayAvailableChanged: {
        if (!trayAvailable)
            trayOpen = false
    }

    TrayPopups {
        id: trayPopups
        parentWindow: win
        source: win.traySource
        toggleAnchor: statusBar.trayToggle
        open: win.trayOpen
        onCloseRequested: win.trayOpen = false
    }

    MediaSource {
        id: mediaSource
    }

    ResourceSource {
        id: resourceSource
        wanted: statusBar.shows("resources") || win.resourcePopupOpen
    }

    QtObject {
        id: statusDemand

        property bool counted: false
        readonly property bool want: statusBar.shows("status")

        onWantChanged: statusDemand.sync()

        function sync() {
            if (statusDemand.want === statusDemand.counted)
                return
                statusDemand.counted = statusDemand.want
                StatusIconsService.watch(statusDemand.want ? 1 : -1)
        }

        Component.onCompleted: statusDemand.sync()
        Component.onDestruction: {
            if (statusDemand.counted) {
                statusDemand.counted = false
                StatusIconsService.watch(-1)
            }
        }
    }

    BatterySource {
        id: batterySource
    }

    WeatherSource {
        id: weatherSource
    }

    // Whether the battery / resource popup is open. Same pattern as
    // trayOpen above: owned here, the indicator asks to flip it, the
    // popup's own click-away sets it back to false. Opening one closes
    // the other so they don't stack.
    property bool batteryPopupOpen: false
    property bool resourcePopupOpen: false
    property bool calendarPopupOpen: false
    property bool weatherPopupOpen: false
    property bool mediaPopupOpen: false
    property bool utilPopupOpen: false

    function toggleMediaPopup() {
        batteryPopupOpen = false
        utilPopupOpen = false
        resourcePopupOpen = false
        calendarPopupOpen = false
        weatherPopupOpen = false
        mediaPopupOpen = !mediaPopupOpen
    }

    function toggleBatteryPopup() {
        mediaPopupOpen = false
        resourcePopupOpen = false
        calendarPopupOpen = false
        weatherPopupOpen = false
        utilPopupOpen = false
        batteryPopupOpen = !batteryPopupOpen
    }
    function toggleResourcePopup() {
        mediaPopupOpen = false
        batteryPopupOpen = false
        utilPopupOpen = false
        calendarPopupOpen = false
        weatherPopupOpen = false
        resourcePopupOpen = !resourcePopupOpen
    }
    function toggleCalendarPopup() {
        mediaPopupOpen = false
        batteryPopupOpen = false
        utilPopupOpen = false
        resourcePopupOpen = false
        weatherPopupOpen = false
        calendarPopupOpen = !calendarPopupOpen
    }
    function toggleWeatherPopup() {
        mediaPopupOpen = false
        batteryPopupOpen = false
        utilPopupOpen = false
        resourcePopupOpen = false
        calendarPopupOpen = false
        weatherPopupOpen = !weatherPopupOpen
    }
    function toggleUtilPopup() {
        mediaPopupOpen = false
        batteryPopupOpen = false
        resourcePopupOpen = false
        calendarPopupOpen = false
        weatherPopupOpen = false
        utilPopupOpen = !utilPopupOpen
    }

    LazyLoader {
        id: mediaPopupLazy
        property bool want: win.mediaPopupOpen
        property bool seen: false
        onWantChanged: if (want) seen = true
        active: seen

        MediaPopup {
            property bool ready: false
            Component.onCompleted: Qt.callLater(() => ready = true)
            open: mediaPopupLazy.want && ready
            parentWindow: win
            anchorItem: statusBar.mediaToggle
            source: mediaSource
            onCloseRequested: win.mediaPopupOpen = false
        }
    }

    LazyLoader {
        id: batteryPopupLazy
        property bool want: win.batteryPopupOpen
        property bool seen: false
        onWantChanged: if (want) seen = true
        active: seen

        BatteryPopup {
            property bool ready: false
            Component.onCompleted: Qt.callLater(() => ready = true)
            open: batteryPopupLazy.want && ready
            parentWindow: win
            anchorItem: statusBar.batteryToggle
            onCloseRequested: win.batteryPopupOpen = false

            percentage: batterySource.percentage
            statusLabel: batterySource.statusLabel
            timeRemaining: batterySource.timeRemaining
        }
    }

    LazyLoader {
        id: utilPopupLazy
        property bool want: win.utilPopupOpen
        property bool seen: false
        onWantChanged: if (want) seen = true
        active: seen

        UtilPopup {
            property bool ready: false
            Component.onCompleted: Qt.callLater(() => ready = true)
            open: utilPopupLazy.want && ready
            parentWindow: win
            anchorItem: statusBar.utilToggle
            source: statusBar.utilSource
            onCloseRequested: win.utilPopupOpen = false
        }
    }

    Connections {
        target: statusBar
        function onUtilFlyoutChanged() {
            if (!statusBar.utilFlyout)
                win.utilPopupOpen = false
        }
    }

    LazyLoader {
        id: calendarPopupLazy
        property bool want: win.calendarPopupOpen
        property bool seen: false
        onWantChanged: if (want) seen = true
        active: seen

        CalendarPopup {
            property bool ready: false
            Component.onCompleted: Qt.callLater(() => ready = true)
            open: calendarPopupLazy.want && ready
            parentWindow: win
            anchorItem: statusBar.dateToggle
            today: clock.date
            onCloseRequested: win.calendarPopupOpen = false
        }
    }

    LazyLoader {
        id: weatherPopupLazy
        property bool want: win.weatherPopupOpen
        property bool seen: false
        onWantChanged: if (want) seen = true
        active: seen

        WeatherPopup {
            property bool ready: false
            Component.onCompleted: Qt.callLater(() => ready = true)
            open: weatherPopupLazy.want && ready
            parentWindow: win
            anchorItem: statusBar.weatherToggle
            source: weatherSource
            onCloseRequested: win.weatherPopupOpen = false
        }
    }

    LazyLoader {
        id: resourcePopupLazy
        property bool want: win.resourcePopupOpen
        property bool seen: false
        onWantChanged: if (want) seen = true
        active: seen

        ResourcePopup {
            property bool ready: false
            Component.onCompleted: Qt.callLater(() => ready = true)
            open: resourcePopupLazy.want && ready
            parentWindow: win
            anchorItem: statusBar.resourceToggle
            onCloseRequested: win.resourcePopupOpen = false

            cpuPercent: resourceSource.cpuPercent
            memPercent: resourceSource.memPercent
            memUsedLabel: resourceSource.memUsedLabel
            memTotalLabel: resourceSource.memTotalLabel
        }
    }

    // Keyboard layout, workspaces and the focused window all come from
    // Ryoku's window-manager seam (Wm), never a compositor-specific module.
    readonly property string xkbLayoutName: Wm.keyboardLayout
    readonly property int xkbLayoutCount: (Wm.keyboardLayouts || []).length
    readonly property string xkbLayoutCode: xkbLayoutCount > 1 && xkbLayoutName !== ""
        ? xkbLayoutName.slice(0, 2).toUpperCase() : ""

    function cycleKeyboardLayout() {
        Wm.cycleKeyboardLayout()
    }

    readonly property var screenWorkspaces: (Wm.workspaces || []).filter(w =>
        !w.special && (!win.screen || !w.output || w.output === win.screen.name))

    readonly property int activeWorkspace: {
        for (const w of win.screenWorkspaces)
            if (w.active)
                return parseInt(w.name, 10) || 1
        const f = Wm.focusedWorkspace
        return f ? (parseInt(f.name, 10) || 1) : 1
    }

    readonly property var occupiedWorkspaces: win.screenWorkspaces
        .filter(w => w.occupied)
        .map(w => parseInt(w.name, 10))
        .filter(n => !isNaN(n))

    readonly property var focusedWindow: {
        const w = Wm.focusedWindow
        if (!w)
            return null
        if (win.screen && w.output && w.output !== win.screen.name)
            return null
        return w
    }

    readonly property string windowClass: win.focusedWindow ? (win.focusedWindow.appId || "") : ""

    function appDisplayName(cls) {
        if (cls === "")
            return ""
            try {
                const entry = DesktopEntries.heuristicLookup(cls)
                if (entry && entry.name)
                    return entry.name
            } catch (e) {}
            const last = cls.split(".").pop()
            return last.charAt(0).toUpperCase() + last.slice(1)
    }

    readonly property string windowIconSource: {
        if (win.windowClass === "")
            return ""
            try {
                const entry = DesktopEntries.heuristicLookup(win.windowClass)
                if (entry && entry.icon)
                    return IconCursorService.path(entry.icon, "application-x-executable")
            } catch (e) {}
            return ""
    }

    function pad(n) {
        return ("0" + n).slice(-2)
    }

    function formatClock(d) {
        if (SettingsService.flag("time.use24h"))
            return pad(d.getHours()) + ":" + pad(d.getMinutes())
            const h = d.getHours()
            const h12 = h % 12 === 0 ? 12 : h % 12
            return pad(h12) + ":" + pad(d.getMinutes()) + " " + (h < 12 ? "AM" : "PM")
    }

    function formatDate(d) {
        return d.toLocaleDateString(Qt.locale(), "ddd, MMM d")
    }

    readonly property int barStyle: BarStyleService.index
    // How round the bar and its modules are: 0 is square, 1 fully round.
    readonly property real barRoundness: Math.max(0, Math.min(100,
        Number(SettingsService.get("bar.roundness", 100)))) / 100
    Item {
        id: geometry
        property real sideInset: (win.barStyle === 0 || win.barStyle === 3) ? Theme.barFloatInset : 0
        Behavior on sideInset {
            NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
        }

        property real slide: 0
        NumberAnimation {
            id: slideOut
            target: geometry
            property: "slide"
            to: 1
            duration: PresetMotion.outMs
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            id: slideIn
            target: geometry
            property: "slide"
            to: 0
            duration: PresetMotion.inMs
            easing.type: Easing.OutBack
            easing.overshoot: 1.1
        }
        Component.onCompleted: {
            if (PresetMotion.barBusy) {
                geometry.slide = 1
                if (!win.barOut)
                    slideIn.restart()
            } else if (win.barOut) {
                geometry.slide = 1
            }
        }
    }

    Item {
        id: stage
        anchors.fill: parent
        clip: true

        // The pointer over the bar keeps it up; leaving it starts the countdown.
        // On the stage, so it still sees the pointer when the content is away
        // and only the thin edge strip of the window takes input.
        HoverHandler {
            id: barHover
            enabled: win.autoHide
            onHoveredChanged: {
                if (hovered) {
                    win.autoReveal = true
                    hideTimer.stop()
                } else {
                    hideTimer.restart()
                }
            }
        }

        ScaleHost {
            anchors.fill: parent
            factor: win.uiScale

            Status_Bar {
                id: statusBar
                vertical: win.vertical
                barPosition: win.barPosition
                readonly property real edgeGap: win.barStyle === 1 ? 0 : (win.barStyle === 3 ? Theme.capEdgeGap : 1)
                readonly property real slideDist: (win.vertical ? width : height) + edgeGap + 20
                readonly property real slideBy: geometry.slide * statusBar.slideDist
                x: win.vertical
                ? (win.barPosition === "right" ? parent.width - width - edgeGap + slideBy : edgeGap - slideBy)
                : geometry.sideInset
                y: win.vertical
                ? geometry.sideInset
                : (win.barPosition === "bottom" ? parent.height - height - edgeGap + slideBy : edgeGap - slideBy)
                width: win.vertical ? (win.barStyle === 3 ? Theme.capVBarFace : Theme.barVBody) : parent.width - 2 * geometry.sideInset
                height: win.vertical ? parent.height - 2 * geometry.sideInset : (win.barStyle === 3 ? Theme.capBarHeight : 61)
                barStyle: win.barStyle
                barRoundness: win.barRoundness

                activeWorkspace: win.activeWorkspace
                occupiedWorkspaces: win.occupiedWorkspaces
                workspaceCount: Math.max(1, Math.min(10, Math.round(Number(SettingsService.get("bar.workspaceCount")) || 5)))
                gameMode: win.gameMode
                modules: BarLayoutService.modulesFor(win.screen ? win.screen.name : "")
                clockText: win.formatClock(clock.date)
                dateText: win.formatDate(clock.date)
                onDateClicked: win.toggleCalendarPopup()
                scaleValue: win.uiScale
                layout: BarLayoutService.layoutFor(win.screen ? win.screen.name : "")
                onWallpapersToggleRequested: win.picker.toggleOn(win.screen)

                mediaActive: mediaSource.present
                mediaPlaying: mediaSource.playing
                mediaTitle: mediaSource.title
                mediaArtist: mediaSource.artist
                mediaArtUrl: mediaSource.artUrl
                mediaVisualizerStyle: VisualizerService.pillStyle
                mediaPoints: PcCavaService.points
                mediaLeftOpensPanel: SettingsService.get("media.leftClick") === "panel"
                mediaVolumeAvailable: mediaSource.volumeAvailable
                onMediaPanelRequested: win.toggleMediaPopup()
                onMediaScrolled: direction => mediaSource.changeVolume(direction)
                onMediaToggleRequested: mediaSource.togglePlaying()
                onMediaNextRequested: mediaSource.next()
                onMediaPreviousRequested: mediaSource.previous()

                onNotificationsToggleRequested: win.quickPanel.toggleOn(win.screen)

                cpuPercent: resourceSource.cpuPercent
                memPercent: resourceSource.memPercent
                onResourcesClicked: win.toggleResourcePopup()

                weatherTemperature: weatherSource.temperatureText !== "" ? weatherSource.temperatureText : "--"
                weatherIconName: weatherSource.iconName
                onWeatherClicked: win.toggleWeatherPopup()

                batteryAvailable: batterySource.available
                batteryPercentage: batterySource.percentage
                batteryCharging: batterySource.isCharging
                batteryLow: batterySource.isLow
                onBatteryClicked: win.toggleBatteryPopup()
                utilPopupOpen: win.utilPopupOpen
                onUtilClicked: win.toggleUtilPopup()

                statusNetworkShown: StatusIconsService.networkShown
                statusNetworkIcon: StatusIconsService.networkIcon
                statusNetworkState: StatusIconsService.networkState
                statusBluetoothShown: StatusIconsService.bluetoothShown
                statusBluetoothIcon: StatusIconsService.bluetoothIcon
                statusBluetoothState: StatusIconsService.bluetoothState
                statusSpeakerShown: StatusIconsService.speakerShown
                statusSpeakerIcon: StatusIconsService.speakerIcon
                statusSpeakerState: StatusIconsService.speakerState
                statusDetail: StatusIconsService.detail
                onStatusClicked: win.quickPanel.toggleOn(win.screen)

                keyboardLayoutCode: win.xkbLayoutCode
                onKeyboardLayoutClicked: win.cycleKeyboardLayout()

                notificationCount: win.quickPanel.notificationSource.count
                notificationsMuted: !win.quickPanel.source.notificationsOn

                privacyMic: PrivacyService.micLive
                privacyScreen: PrivacyService.screenLive
                privacyDetail: {
                    const lines = []
                    if (PrivacyService.screenLive)
                        lines.push("Screen shared with: " + PrivacyService.screenApps.join(", "))
                        if (PrivacyService.micLive)
                            lines.push("Microphone in use by: " + PrivacyService.micApps.join(", "))
                            return lines.join("\n")
                }

                updatesCount: PackageUpdatesService.total
                updatesNudging: PackageUpdatesService.nudging
                updatesShowZero: SettingsService.flag("updates.showZero")
                updatesBusy: PackageUpdatesService.status === "checking" || PackageUpdatesService.upgrading
                updatesLoading: PackageUpdatesService.loadingBadge
                updatesTip: PackageUpdatesService.breakdown
                + (PackageUpdatesService.total > 0 ? " — click to update, right-click to recheck" : " — right-click to recheck")
                onUpdatesClicked: PackageUpdatesService.runUpdate()
                onUpdatesRefreshRequested: PackageUpdatesService.refresh(true)

                trayOpen: win.trayOpen
                trayAvailable: win.trayAvailable
                trayMenuItem: trayPopups.menuItem
                trayLeavingItem: trayPopups.leavingItem
                trayAttention: win.traySource.unpinnedAttention
                trayScrollEnabled: SettingsService.flag("tray.scroll")
                onTrayItemScrolled: (item, delta, horizontal) => trayPopups.handleScroll(item, delta, horizontal)
                onTrayToggleRequested: win.trayOpen = !win.trayOpen
                trayPinned: win.traySource.pinnedItems
                onTrayItemClicked: (item, button, icon) => trayPopups.handleClick(item, button, icon, false)

                windowApp: win.appDisplayName(win.windowClass)
                windowTitle: win.focusedWindow?.title ?? ""
                windowIcon: win.windowIconSource

                onWorkspaceRequested: workspace => Wm.focusWorkspace(workspace)
            }
        }
    }
}
