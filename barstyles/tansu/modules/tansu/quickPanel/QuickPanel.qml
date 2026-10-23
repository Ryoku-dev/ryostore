import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import Ryoku.Ui.Singletons
import shell.services as Ryoku
import "../../../services"
import "../../common/functions/PhoneMath.js" as PM
import "../../common/functions/FlipMath.js" as FM
import "PhoneRoute.js" as PR
import "../../../modules/common"
import "../../../modules/tansu/launcher"
import "../../../modules/tansu/phone"
import "../../../modules/tansu/settings"

// The Quick Panel: a phone-shaped panel (PhoneBody.qml around
// QuickPanelFace.qml) that comes up from the bottom-center of the screen,
// like a phone being pulled out of a pocket, and stays there with its
// lower part still below the screen edge (see `peek`).
//
// Like Bar.qml, this is one of the files that talks to the system. The
// two files it's built from stay pure UI; this feeds QuickPanelFace what
// QuickSource.qml knows and turns its signals into actions.
//
// Ways to open it:
//   - a keybind, e.g. SUPER + N — bind it to the command
//         qs -c tansu ipc call quickpanel toggle
//     (also `show` and `hide`); pressing it again closes the panel
//   - push the mouse into the bottom-center of the screen (the hot edge)
//   - click the notification bell in the bar (Bar.qml -> toggleOn)
//
// Ways to close it (however it was opened):
//   - click anywhere outside it (same as the tray dropdown)
//   - or press the keybind again
// Moving the mouse away does NOT close it.
//
// It opens on the monitor you pointed at (the focused one for the
// keybind), scaled down to fit that monitor's height.
//
// It's also the notification alert (there's no separate popup): when
// something arrives (and do-not-disturb is off, or it's critical) the
// phone comes up on the focused monitor if it isn't already, buzzes, and
// drops the new notification in as a card at the top of its screen for a
// few seconds (see NotificationSource.qml / QuickPanelFace's heads-up).
// It only rises as far as that card (just the top of the phone shows, see
// alertLift), not the whole `peek`, and it doesn't grab the keyboard or
// the pointer; it goes back down by itself. Touch it (any click on it, or
// the keybind / hot edge) and it slides up to the full panel and stays
// open like normal.
//
// The gear on the header turns the phone into the Settings (SettingsStage.qml)
// instead of opening another panel: the phone rolls a quarter turn
// anticlockwise, rises to the middle of the monitor, and its screen dissolves
// into the Settings', keeping the same body (see FlipMath.js). The Settings' X
// (or Escape on their menu) turns it back. The Settings also come up on their
// own, with no Quick Panel to turn out of:
//     qs -c tansu ipc call settings toggle   (also `show`, `hide`, and
//     `page <quick|general|bar|desktop|hyprland|about>`)
// Everything lives in this one window: its size is worked out once, up front,
// to hold the whole turn (see `flipRoom`), because a window that is resized
// while it animates stutters.
//
// This is also the ONE phone's front door (Concept D, "Phone + Stage"):
//   - Quick is the first screen, with Rashin (AskFace.qml) to its right: a pull
//     left brings the agent in, a pull right goes back. Apps (LauncherFace.qml)
//     is not a page: typing a letter, Super+A or a jump slides it in over Quick.
//     Settings keep their turn.
//   - Back undoes the steps you took and never invents one (PhoneRoute.js): Escape
//     or the Back chip goes back one screen; at the screen the phone was opened on
//     it closes. Ctrl+1..4 jump (1 Quick, 2 Apps, 3 Wallpapers, 4 Settings).
//   - the now-playing card opens the Lyrics tab (LyricsFace.qml). Its push-pin
//     turns the phone into the corner player, bottom left (Back, or the pin
//     again, brings it back).
//   - one IPC target for all of it:  qs -c tansu ipc call phone toggle | show | hide
//     | go <quick|apps|wallpapers|settings> | back | home
//     (`quickpanel`, `launcherphone` and `settings` keep working).
//   - The Wallpapers share the Settings' phone: same landscape body, same 2.5D pose,
//     same turn out of this phone and back (SettingsStage.qml hosts both screens).
//     From the Settings the gallery just cross-fades in on the same phone; Back
//     goes to whichever screen it came from.
Scope {
    id: root

    required property var source

    required property var notificationSource

    property var mediaSource: null

    property var barWindows: []


    property bool open: false
    property bool coverCheat: false
    readonly property bool onScreen: win.visible

    property var appSource: null
    property var launcher: null
    // PhoneRoute.js: the stack of screens, Quick at the bottom unless the phone was
    // opened on another one. Reset to just Quick whenever the phone goes away.
    property var phoneRoute: PR.open("quick")
    readonly property string faceScreen: {
        const st = root.phoneRoute.stack
        for (let i = st.length - 1; i >= 0; i--) {
            if (st[i] === "apps" || st[i] === "quick" || st[i] === "ai")
                return st[i]
        }
        return "quick"
    }
    // Rashin is one face right of Quick. Apps is not a page at all (see
    // appsLayer); the pager is one face wide per page, so a page is always a
    // whole face and the neighbours stay outside the screen.
    readonly property bool routing: slideAnim.running || pager.moving

    property var picker: null

    property bool settingsOpen: false

    // The lyrics tab, opened from the now-playing card.
    property bool lyricsShown: false

    // The corner player (Settings > Quick Panel for its size and opacity).
    property bool pinned: false
    property real pinScale: SettingsService.get("quick.pinScale", 58) / 100
    property real pinOpacity: SettingsService.get("quick.pinOpacity", 100) / 100
    property int pinMs: 560
    // How much of the phone hangs past the screen's edges, of its own size.
    property real pinPeekX: 0.12
    property real pinPeekY: 0.07

    property string landscape: "settings"
    property bool wallpapersStraight: true
    readonly property bool wallpapersOpen: settingsOpen && landscape === "wallpapers"

    // The Settings' X / Escape has started turning the phone back into the Quick
    // Panel and it hasn't fully settled yet. While it is true the panel keeps its
    // keyboard focus and ignores a click-away grab that clears by itself: with
    // nothing mapped on the workspace, dropping the Settings' keyboard focus
    // makes Hyprland clear the grab (there is no window to hand focus to), and
    // that used to close the whole panel in the middle of the turn.
    property bool turningBack: false

    readonly property bool settingsShown: settingsOpen || sstage.shownOpacity > 0.001

    property int flipMs: 200
    readonly property var flipCurve: [0.30, 0.0, 0.20, 1.0, 1.0, 1.0]
    // Before anything moves, the phone is redrawn on the light settings and with room to be
    // rolled (PhoneBody `turnRoll`, `moving`): that redraw is heavy and used to land on the
    // first frames of the turn. The turn now waits until this many frames have really been
    // drawn (and never longer than flipPrepMaxMs), so it starts on a phone that is ready
    // instead of jumping ahead by however long the redraw took.
    property int flipPrepFrames: 2
    property int flipPrepMaxMs: 260
    readonly property bool launching: faceScreen === "apps" && !settingsShown
    property int launchInMs: 340
    property int launchTiltMs: 460
    property int launchOutMs: 300
    readonly property var launchCurve: [0.32, 0.72, 0, 1, 1, 1]
    readonly property var launchOutCurve: [0.5, 0, 0.7, 0.35, 1, 1]
    property int wallpapersEnterMs: 200
    // Build the gallery while the Apps screen is up, so it is ready when you tap
    // the Wallpapers tile (a little work whenever Apps is on screen). false = build
    // it after the tap, which leaves the screen blank for a moment after the turn.
    property bool wallpapersWarm: true
    property int warmDelayMs: 900
    property bool warmReady: false
    readonly property bool warmWanted: wallpapersWarm && open && faceScreen === "apps"
    onWarmWantedChanged: {
        if (warmWanted) {
            warmDelay.restart()
        } else {
            warmDelay.stop()
            warmReady = false
        }
    }
    Timer {
        id: warmDelay
        interval: root.warmDelayMs
        onTriggered: {
            if (!root.warmWanted)
                return
            if (enterAnim.running || root.routing || phone.moving)
                warmDelay.restart()
            else
                root.warmReady = true
        }
    }
    readonly property real enterSpeed: settingsOpen && landscape === "wallpapers" && flipAnim.to > 0.5
                                       ? wallpapersEnterMs / flipMs : 1
    property real flipDip: 0.12
    property real flipWobble: 2.5
    property int flipRingMs: 380
    property real ringSign: 1

    property bool alertUp: false

    property bool alertMode: false

    // The phone is up, for either reason. QuickSource follows this so the
    // tiles are fresh whenever it's showing.
    readonly property bool up: open || alertUp

    property var targetScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    property url bannerSource: ""
    property url avatarSource: ""

    property bool hotEdge: SettingsService.flag("panel.hotEdge")
    readonly property bool clickOutside: SettingsService.flag("panel.clickOutside")
    property real hotWidth: 360
    property real hotHeight: 4
    property int hotDwell: SettingsService.get("panel.hotDwell")

    // The screen corners that call the phone up, and whether it comes up there.
    readonly property var hotCorners: {
        const on = {
            topLeft: SettingsService.flag("panel.hotCornerTopLeft"),
            topRight: SettingsService.flag("panel.hotCornerTopRight"),
            bottomLeft: SettingsService.flag("panel.hotCornerBottomLeft"),
            bottomRight: SettingsService.flag("panel.hotCornerBottomRight")
        }
        return ["topLeft", "topRight", "bottomLeft", "bottomRight"].filter(c => on[c])
    }
    readonly property bool hotCornerFollow: SettingsService.flag("panel.hotCornerFollow")
    property real hotCornerSize: 12

    // The corner the phone is placed at ("" = the bottom centre it always used).
    // Only a hot corner sets it, and only while "Open near the corner" is on.
    property string corner: ""
    property string nextCorner: ""

    property real peek: SettingsService.get("panel.peek") / 100

    readonly property real peekEff: flat2d ? Math.min(1, peek * 1.10) : peek

    property real barHeight: 63
    property real edgeMargin: 10
    // 1 = never bigger than the Figma frame; it only ever shrinks to fit.
    property real maxScale: 1

    property real bounce: 34
    property real headroom: 44
    property real railGap: flat2d ? 26 : 60
    readonly property bool flat2d: Theme.quickFlat
    property real tiltRoll: flat2d ? 0 : 12
    property real tiltPitch: flat2d ? 0 : 10
    property real tiltYaw: flat2d ? 0 : -6

    property real alertMargin: 26

    property real buzzAmount: SettingsService.flag("notify.buzz") ? 9 : 0
    property real buzzHz: 15
    property int buzzPulses: 2
    property int buzzBurstMs: 340
    property int buzzGapMs: 130
    property int buzzRiseMs: 700

    property double hotBlockedUntil: 0

    function focusedScreen() {
        const name = Wm.focusedOutput || ""
        for (const s of Quickshell.screens) {
            if (s.name === name)
                return s
        }
        return Quickshell.screens[0]
    }

    function stopRing() {
        ring.stop()
        stage.wob = 0
    }

    // A hot corner: the phone comes up from that corner, not the bottom centre.
    function openAt(screen, at) {
        nextCorner = hotCornerFollow ? (at || "") : ""
        openOn(screen)
    }

    // `entry` is the screen it comes up on ("quick" unless asked otherwise). The
    // route is set before `open` flips so the face is already there on the first
    // frame instead of sliding in during the pull-out.
    function openOn(screen, entry) {
        stopRing()
        if (!open) {
            setRoute(PR.open(entry || "quick"))
            // A fresh pull-out starts on Quick, in the middle, whatever the last
            // visit left behind.
            root.lyricsShown = false
            root.pinned = false
            stage.pin = 0
        }
        if (settingsOpen) {
            if (open && (!screen || screen === targetScreen)) {
                turningBack = true
                backSettle.stop()
                settingsOpen = false
                setRoute(PR.go(phoneRoute, faceScreen))
                turnTo(0)
            } else if (!open && (!screen || screen === targetScreen) && stage.flip > 0.5 && win.visible) {
                turningBack = true
                backSettle.stop()
                settingsEnter.stop()
                settingsExit.stop()
                settingsOpen = false
                stage.sPop = 1
                stage.sAlpha = 1
                stage.sTilt = 0
                skipEnter = true
                turnTo(0)
            } else {
                settingsOpen = false
                settingsEnter.stop()
                settingsExit.stop()
                stage.flip = 0
            }
        }
        if (screen)
            targetScreen = screen
        root.corner = root.nextCorner
        root.nextCorner = ""
        open = true
    }

    property bool skipEnter: false

    function close() {
        alertUp = false
        turningBack = false
        open = false
        closeSettings()
    }

    // ===== the lyrics tab =====
    // The shell's interpolated clock plus LyricsService's per-track offset,
    // stepped at 30Hz: the words and the wave don't need 60, and every step
    // re-renders the phone's screen.
    readonly property real lyricTime: Math.round((Ryoku.Music.position
        + LyricsService.syncTotal / 1000) * 30) / 30
    readonly property real lyricDuration: Ryoku.Music.length
    readonly property string lyricSource: LyricsService.source !== ""
        ? LyricsService.providerName(LyricsService.source) : ""

    // Opening the tab again is the retry after a miss: LyricsService keeps a
    // miss for ten minutes, but here the listener is asking on purpose.
    function syncLyrics() {
        if (!root.mediaSource)
            return
        const retry = LyricsService.status === "none" || LyricsService.status === "offline"
        LyricsService.request(root.mediaSource.artist, root.mediaSource.title,
                              root.mediaSource.album, root.mediaSource.length,
                              root.mediaSource.url, retry)
    }

    function openLyrics() {
        if (!root.open || root.settingsShown || root.lyricsShown)
            return
        closeQuickDialogs()
        root.lyricsShown = true
        root.focusPhoneKeys()
    }

    function closeLyrics() {
        if (!root.lyricsShown)
            return
        root.lyricsShown = false
        root.setPinned(false)
    }

    function setPinned(on) {
        if (root.pinned === on)
            return
        root.pinned = on
        stage.setPin(on)
    }

    onLyricsShownChanged: {
        Ryoku.Music.hold(root, root.lyricsShown && root.open)
        if (root.lyricsShown)
            root.syncLyrics()
    }

    Connections {
        target: root.mediaSource
        ignoreUnknownSignals: true
        function onTitleChanged() {
            if (root.lyricsShown)
                root.syncLyrics()
        }
    }

    function openSettings(screen) {
        openLandscape("settings", screen, "")
    }

    function openWallpapers(screen, which) {
        if (EditMode.active)
            return
        openLandscape("wallpapers", screen, which === "lock" ? "lock" : "desktop")
    }

    // The bar's wallpaper key: closes the Wallpapers if they are what is up (on
    // that side, when a side is asked for), otherwise opens them.
    function toggleWallpapersOn(screen, which) {
        const same = !screen || screen === targetScreen
        const side = which === "lock" ? "lock" : "desktop"
        const now = sstage.wallpaperFace ? sstage.wallpaperFace.target : sstage.initialTarget
        if (wallpapersOpen && same && (which === undefined || side === now))
            close()
        else
            openWallpapers(screen, which)
    }

    function showLandscape(kind) {
        if (landscape === kind)
            return
        landscape = kind
        landscapeFocus.restart()
    }

    function swapLandscape(kind, side) {
        if (kind === "wallpapers")
            sstage.setTarget(side || "desktop")
        if (landscape !== kind) {
            setRoute(PR.go(phoneRoute, kind))
            showLandscape(kind)
        }
    }

    function openLandscape(kind, screen, side) {
        if (settingsOpen) {
            swapLandscape(kind, side)
            return
        }
        turningBack = false
        backSettle.stop()
        stopRing()
        landscape = kind
        if (kind === "wallpapers") {
            sstage.setTarget(side || "desktop")
            sstage.dealIfWarm()
        }
        landscapeFocus.restart()
        if (open && (!screen || screen === targetScreen)) {
            panelFace.powerMenuOpen = false
            panelFace.networkDialogOpen = false
            panelFace.bluetoothDialogOpen = false
            panelFace.nightLightDialogOpen = false
            panelFace.audioDialogKind = ""
            setRoute(PR.go(phoneRoute, kind))
            settingsOpen = true
            // What Hyprland says now, in case a reload or a hand edit changed it.
            HyprlandSettings.refresh()
            settingsExit.stop()
            stage.sPop = 1
            stage.sAlpha = 1
            stage.sTilt = 0
            turnTo(1)
        } else {
            if (open)
                close()
            alertUp = false
            if (screen)
                targetScreen = screen
            setRoute(PR.open(kind))
            settingsOpen = true
            HyprlandSettings.refresh()
            settingsExit.stop()
            flipPrep.stop()
            flipAnim.stop()
            if (!win.visible) {
                stage.sPop = 0
                stage.sTilt = 1
                stage.sAlpha = 0
            }
            stage.flip = 1
            settingsEnter.restart()
        }
    }

    function turnTo(p) {
        stopRing()
        flipAnim.stop()
        flipAnim.to = p
        armPrep(flipPrep)
    }

    property real prepSince: 0
    FrameAnimation {
        id: prepFrames

        property int count: 0

        running: flipPrep.running
        onTriggered: count++
    }

    function armPrep(timer) {
        prepFrames.count = 0
        prepSince = Date.now()
        timer.restart()
    }

    function prepReady() {
        return prepFrames.count >= flipPrepFrames || Date.now() - prepSince >= flipPrepMaxMs
    }

    // The Settings' X, or Escape on their menu: the phone turns back into the
    // Quick Panel if that is where it came from, otherwise they just go away.
    function settingsBack() {
        if (!settingsOpen)
            return
        const r = PR.back(phoneRoute)
        if (!r.closed) {
            const next = PR.top(r.state)
            if (next === "settings" || next === "wallpapers") {
                setRoute(r.state)
                showLandscape(next)
                return
            }
        }
        if (!open) {
            closeSettings()
            return
        }
        turningBack = true
        backSettle.stop()
        settingsOpen = false
        if (!r.closed)
            setRoute(r.state)
        turnTo(0)
    }

    function closeSettings() {
        if (!settingsOpen)
            return
        turningBack = false
        backSettle.stop()
        stopRing()
        settingsOpen = false
        flipPrep.stop()
        flipAnim.stop()
        if (stage.flip > 0.5) {
            stage.flip = 1
            settingsEnter.stop()
            settingsExit.restart()
        } else {
            stage.flip = 0
        }
    }

    function alert() {
        const wasUp = up
        if (!wasUp) {
            targetScreen = focusedScreen()
            alertMode = true
            alertUp = true
        }
        buzzTimer.interval = wasUp ? 0 : buzzRiseMs
        buzzTimer.restart()
    }

    function claim() {
        if (alertUp && !open)
            open = true
    }

    function toggleOn(screen) {
        if (settingsOpen && (!screen || screen === targetScreen)) {
            if (open)
                setRoute(PR.home(phoneRoute))
            openOn(screen)
            return
        }
        if (open && (!screen || screen === targetScreen))
            close()
        else
            openOn(screen)
    }

    function setRoute(state) {
        phoneRoute = state
    }

    // The strip follows the route: it slides while the window is up and just
    // snaps while it is hidden.
    function syncFace() {
        slideAnim.stop()
        const target = (faceScreen === "ai" ? 1 : 0) * phone.faceWidth
        if (!win.visible) {
            pager.contentX = target
            return
        }
        if (Math.abs(pager.contentX - target) < 0.5) {
            pager.contentX = target
            focusPhoneKeys()
            return
        }
        slideAnim.to = target
        slideAnim.start()
    }

    // The pull has stopped: take the page it came to rest on. Only Quick and
    // Rashin page: the Apps screen slides in on its own, never as a page.
    function settleSwipe() {
        const page = Math.round(pager.contentX / phone.faceWidth)
        if (page >= 1 && faceScreen !== "ai")
            goAsk()
        else if (page <= 0 && faceScreen !== "quick")
            homeNow()
        else
            syncFace()
    }
    onFaceScreenChanged: syncFace()

    function closeQuickDialogs() {
        panelFace.closeDialogs()
    }

    function goApps(seed) {
        if (!open || settingsShown)
            return
        if (faceScreen === "apps") {
            if (seed)
                appsFace.appendText(seed)
            return
        }
        closeQuickDialogs()
        appsFace.reset()
        if (seed)
            appsFace.appendText(seed)
        setRoute(PR.go(phoneRoute, "apps"))
    }

    function goAsk() {
        if (!open || settingsShown || faceScreen === "ai")
            return
        closeQuickDialogs()
        setRoute(PR.go(phoneRoute, "ai"))
    }

    function openAskOn(screen) {
        if (open && !settingsShown && (!screen || screen === targetScreen)) {
            goAsk()
            return
        }
        const wasOpen = open
        openOn(screen, "ai")
        if (wasOpen)
            setRoute(PR.open("ai"))
    }

    function openAppsOn(screen) {
        if (open && !settingsShown && (!screen || screen === targetScreen)) {
            goApps("")
            return
        }
        const wasOpen = open
        appsFace.reset()
        openOn(screen, "apps")
        if (wasOpen)
            setRoute(PR.open("apps"))
    }

    // The Apps screen as a toggle: up on Apps -> away, otherwise open on Apps. This
    // is the old launcher phone's `toggleOn`, for the keys that still say
    // "launcher" (the dock's Search key; `ipc call launcherphone toggle` does the
    // same).
    function toggleAppsOn(screen) {
        if (open && !settingsShown && faceScreen === "apps" && (!screen || screen === targetScreen))
            close()
        else
            openAppsOn(screen)
    }

    readonly property var appsModes: ({
        calc: "calc ", clip: "clip ", color: "color ", emoji: "emoji ", web: "web "
    })

    function openAppsMode(screen, name, toggle) {
        const key = String(name || "").trim().toLowerCase()
        const seed = appsModes[key] || ""
        const here = open && !settingsShown && faceScreen === "apps" && (!screen || screen === targetScreen)
        if (here) {
            if (toggle && seed !== "" && appsFace.query.toLowerCase().indexOf(key) === 0) {
                close()
                return
            }
            appsFace.setText(seed)
            return
        }
        openAppsOn(screen)
        if (seed !== "")
            appsFace.appendText(seed)
    }

    function homeNow() {
        if (!open)
            return
        setRoute(PR.home(phoneRoute))
        if (settingsOpen)
            settingsBack()
    }

    function back() {
        if (settingsOpen) {
            settingsBack()
            return
        }
        if (root.lyricsShown) {
            root.closeLyrics()
            return
        }
        if (!open) {
            close()
            return
        }
        const r = PR.back(phoneRoute)
        if (r.closed) {
            close()
            return
        }
        setRoute(r.state)
    }

    function jump(n) {
        const name = PR.byNumber(n)
        if (name === "quick")
            homeNow()
        else if (name === "apps")
            goApps("")
        else if (name === "settings")
            openSettings(targetScreen)
        else if (name === "wallpapers")
            openWallpapers(targetScreen)
        else if (name === "ai")
            goAsk()
    }

    function runBuiltin(id) {
        if (id === "settings") {
            openSettings(targetScreen)
            return
        }
        if (id === "wallpapers")
            openWallpapers(targetScreen)
    }

    function goOn(screen, name) {
        if (name === "quick") {
            if (open && (!screen || screen === targetScreen))
                homeNow()
            else
                openOn(screen)
        } else if (name === "apps") {
            openAppsOn(screen)
        } else if (name === "settings") {
            openSettings(screen)
        } else if (name === "wallpapers") {
            openWallpapers(screen)
        } else if (name === "ai") {
            openAskOn(screen)
        }
    }

    function quickKeyPressed(event) {
        if (!open || settingsShown)
            return
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0
        const alt = (event.modifiers & Qt.AltModifier) !== 0
        const meta = (event.modifiers & Qt.MetaModifier) !== 0
        if (ctrl && event.key >= Qt.Key_1 && event.key <= Qt.Key_4) {
            root.jump(event.key - Qt.Key_0)
            event.accepted = true
            return
        }
        if (faceScreen === "apps") {
            if (event.key === Qt.Key_Escape) {
                appsFace.back()
                event.accepted = true
            } else if (PR.startsSearch(event.text, ctrl, alt, meta)) {
                appsFace.appendText(event.text)
                event.accepted = true
            }
            return
        }
        if (event.key === Qt.Key_Escape) {
            if (panelFace.powerMenuOpen || panelFace.networkDialogOpen || panelFace.bluetoothDialogOpen
                    || panelFace.nightLightDialogOpen || panelFace.audioDialogKind !== "")
                closeQuickDialogs()
            else
                root.back()
            event.accepted = true
        } else if (!root.lyricsShown && SettingsService.flag("panel.typeToSearch")
                   && PR.startsSearch(event.text, ctrl, alt, meta)) {
            root.goApps(event.text)
            event.accepted = true
        }
    }

    function focusPhoneKeys() {
        if (!open || routing)
            return
        if (settingsOpen || turningBack)
            keys.forceActiveFocus()
        else if (faceScreen === "apps")
            appsFace.focusSearch()
        else if (faceScreen === "ai")
            askFace.focusDraft()
        else
            keys.forceActiveFocus()
    }

    // Not while pinned: a corner player leaves the keyboard where it is.
    readonly property bool phoneKeysWanted: open && !settingsShown && !pinned

    Timer {
        id: focusTimer
        // The keys must work at once on the Apps screen.
        interval: root.faceScreen === "apps" ? 20 : 140
        onTriggered: root.focusPhoneKeys()
    }

    function focusLandscape() {
        if (!settingsOpen && !turningBack)
            return
        if (landscape === "wallpapers" && sstage.wallpaperFace)
            sstage.focusWallpapers()
        else
            keys.forceActiveFocus()
    }

    Timer {
        id: landscapeFocus
        interval: 120
        onTriggered: root.focusLandscape()
    }

    NumberAnimation {
        id: slideAnim
        target: pager
        property: "contentX"
        duration: 240
        easing.type: Easing.OutCubic
        // A turn later, so routing is already false and the keys are not handed
        // out while the page is still moving.
        onFinished: Qt.callLater(root.focusPhoneKeys)
    }

    Timer {
        id: settleTimer
        interval: 50
        repeat: true
        onTriggered: {
            if (pager.moving || pager.flicking)
                return
            stop()
            root.settleSwipe()
        }
    }

    onOpenChanged: {
        // Settings > Keys may have paused every shortcut to record one: a panel
        // that goes away must never leave them paused.
        if (!open)
            KeybindService.resume()
        if (open) {
            focusTimer.restart()
            alertUp = false
            alertMode = false
        }
    }

    onUpChanged: {
        if (up) {
            exitDelay.stop()
            exitAnim.stop()
            if (root.skipEnter) {
                root.skipEnter = false
                enterAnim.stop()
                stage.lift = 0
                stage.tilt = 0
                return
            }
            if (stage.lift > stage.enterFrom)
                stage.lift = stage.enterFrom
            enterAnim.restart()
        } else {
            enterAnim.stop()
            panelFace.powerMenuOpen = false
            panelFace.networkDialogOpen = false
            panelFace.bluetoothDialogOpen = false
            panelFace.nightLightDialogOpen = false
            panelFace.audioDialogKind = ""
            hotBlockedUntil = Date.now() + 1200
            if (stage.flip > 0.5) {
                stage.lift = stage.hiddenLift
                return
            }
            // A small pull up first, unless it's still on its way up.
            const rising = stage.lift > 20
            stage.exitPeak = rising ? stage.lift : -bounce * 0.7
            stage.exitPeakMs = rising ? 1 : 130
            if (phone.crisp && !root.launching)
                exitDelay.restart()
            else
                exitAnim.restart()
        }
    }

    // The Refresh button (QuickPanelFace's header row): reload the shell.
    // Quickshell.reload(true) is a hard reload (every window is rebuilt, not
    // reused), so it also clears out a window that got stuck.

    Timer {
        id: editDelay
        interval: 300
        onTriggered: EditMode.open(root.targetScreen ? root.targetScreen.name : "")
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        enabled: win.visible
    }

    readonly property real perfLogMs: {
        const v = parseFloat(Quickshell.env("TANSU_PERF") ?? "")
        return isNaN(v) ? 0 : (v > 1 ? v : 22)
    }

    FrameAnimation {
        id: perfTick

        running: root.perfLogMs > 0 && win.visible

        property int total: 0
        property int slow: 0
        readonly property string phase: stage.flipping ? "turn"
            : enterAnim.running ? "enter"
            : exitAnim.running ? "exit"
            : ring.running ? "ring"
            : (settingsEnter.running || settingsExit.running) ? "pop"
            : "idle"

        onTriggered: {
            total++
            const ms = frameTime * 1000
            if (ms > root.perfLogMs) {
                slow++
                console.log("[perf] " + phase + ": " + ms.toFixed(1) + " ms frame")
            }
        }

        onRunningChanged: {
            if (!running && total > 0) {
                console.log("[perf] panel hidden: " + total + " frames, " + slow
                            + " over " + root.perfLogMs + " ms")
                total = 0
                slow = 0
            }
        }
    }

    Timer {
        id: exitDelay
        interval: 40
        onTriggered: {
            if (!root.up)
                exitAnim.restart()
        }
    }

    Connections {
        target: root.notificationSource

        function onAlerted(entry) {
            root.alert()
        }

        function onToastActiveChanged() {
            if (!root.notificationSource.toastActive && root.alertUp && !root.open)
                root.alertUp = false
        }
    }

    Timer {
        id: buzzTimer
        onTriggered: buzzAnim.restart()
    }

    ParallelAnimation {
        id: enterAnim

        SequentialAnimation {
            NumberAnimation {
                target: stage
                property: "lift"
                to: root.launching ? 0 : -root.bounce
                duration: root.launching ? root.launchInMs : 340
                easing.type: root.launching ? Easing.BezierSpline : Easing.OutCubic
                easing.bezierCurve: root.launchCurve
            }
            // The settle never goes below the resting spot (lift > 0 would
            // push the phone down and drag its lower part under the
            // screen edge for a moment, which read as the bottom being
            // clipped). It lands on the rest spot, then hops back up a
            // little and comes down again, so the bounce stays upward only.
            NumberAnimation {
                target: stage
                property: "lift"
                to: 0
                duration: root.launching ? 0 : 170
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: stage
                property: "lift"
                to: root.launching ? 0 : -root.bounce * 0.14
                duration: root.launching ? 0 : 110
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: stage
                property: "lift"
                to: 0
                duration: root.launching ? 0 : 110
                easing.type: Easing.InQuad
            }
        }

        NumberAnimation {
            target: stage
            property: "tilt"
            to: 0
            duration: root.launching ? root.launchTiltMs : 820
            easing.type: root.launching ? Easing.BezierSpline : Easing.OutElastic
            easing.bezierCurve: root.launchCurve
            easing.amplitude: 1
            easing.period: 0.4
        }
    }

    ParallelAnimation {
        id: exitAnim

        SequentialAnimation {
            NumberAnimation {
                target: stage
                property: "lift"
                to: root.launching ? stage.lift : stage.exitPeak
                duration: root.launching ? 1 : stage.exitPeakMs
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: stage
                property: "lift"
                to: stage.hiddenLift
                duration: root.launching ? root.launchOutMs : 340
                easing.type: root.launching ? Easing.BezierSpline : Easing.InCubic
                easing.bezierCurve: root.launchOutCurve
            }
        }

        NumberAnimation {
            target: stage
            property: "tilt"
            to: 1
            duration: root.launching ? root.launchOutMs : 440
            easing.type: root.launching ? Easing.BezierSpline : Easing.InQuad
            easing.bezierCurve: root.launchOutCurve
        }
    }

    NumberAnimation {
        id: buzzAnim
        target: stage
        property: "buzzT"
        from: 0
        to: 1
        duration: root.buzzPulses * root.buzzBurstMs + Math.max(0, root.buzzPulses - 1) * root.buzzGapMs
        onFinished: stage.buzzT = 0
    }

    Timer {
        id: flipPrep
        interval: 16
        onTriggered: {
            if (!root.prepReady()) {
                flipPrep.restart()
                return
            }
            root.ringSign = flipAnim.to > 0.5 ? -1 : 1
            flipAnim.restart()
            ring.restart()
        }
    }

    SequentialAnimation {
        id: ring

        PauseAnimation {
            duration: Math.round(root.flipMs * 0.62 * root.enterSpeed)
        }

        NumberAnimation {
            target: stage
            property: "wob"
            to: root.ringSign * root.flipWobble
            duration: root.flipRingMs * 0.42 * root.enterSpeed
            easing.type: Easing.InOutSine
        }

        NumberAnimation {
            target: stage
            property: "wob"
            to: -root.ringSign * root.flipWobble * 0.1
            duration: root.flipRingMs * 0.38 * root.enterSpeed
            easing.type: Easing.InOutSine
        }

        NumberAnimation {
            target: stage
            property: "wob"
            to: 0
            duration: root.flipRingMs * 0.2 * root.enterSpeed
            easing.type: Easing.InOutSine
        }
    }

    NumberAnimation {
        id: flipAnim
        target: stage
        property: "flip"
        to: 1
        duration: Math.round(root.flipMs * root.enterSpeed)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root.flipCurve
        onFinished: {
            if (!root.settingsOpen) {
                backSettle.restart()
            }
        }
    }

    Timer {
        id: backSettle
        interval: 450
        onTriggered: {
            root.turningBack = false
            root.focusPhoneKeys()
        }
    }

    ParallelAnimation {
        id: settingsEnter

        NumberAnimation {
            target: stage
            property: "sPop"
            to: 1
            duration: 560
            easing.type: Easing.OutBack
            easing.overshoot: 1.5
        }

        NumberAnimation {
            target: stage
            property: "sTilt"
            to: 0
            duration: 900
            easing.type: Easing.OutElastic
            easing.amplitude: 1
            easing.period: 0.45
        }

        NumberAnimation {
            target: stage
            property: "sAlpha"
            to: 1
            duration: 140
            easing.type: Easing.OutQuad
        }
    }

    ParallelAnimation {
        id: settingsExit

        onFinished: {
            stage.flip = 0
        }

        NumberAnimation {
            target: stage
            property: "sPop"
            to: 0
            duration: 340
            easing.type: Easing.InOutCubic
        }

        NumberAnimation {
            target: stage
            property: "sAlpha"
            to: 0
            duration: 290
            easing.type: Easing.InOutQuad
        }

        NumberAnimation {
            target: stage
            property: "sTilt"
            to: 0.8
            duration: 340
            easing.type: Easing.InOutQuad
        }
    }

    readonly property var grabList: {
        const list = [win]
        for (let i = 0; i < barWindows.length; i++)
            list.push(barWindows[i])
        return list
    }

    // Not while a file chooser is open (avatar / banner picking): it takes
    // focus, which would count as a click away and close the panel.
    // (`open`, not `up`: a phone that only came up for an alert must not
    // take focus from whatever you're typing into.)
    //
    // Not on the Apps screen either: the launcher has a search box that must get the
    // keyboard the moment it opens, wherever the mouse is. Hyprland gives the keyboard
    // to one window of a focus grab when it starts (the panel or a bar, its pick), so
    // with the grab on, typing only worked after the mouse moved onto the phone. The
    // Apps screen has no grab: it takes the keyboard Exclusive (see keyboardFocus
    // below) and `catcher` (further down) closes it when you click anywhere else.
    //
    // Not while the cheatsheet board is up either: it holds the keyboard Exclusive on
    // its own full-screen window, which is not in `grabList`, so with the grab on the
    // compositor counted every press on the phone as focus leaving the grab and the
    // phone closed itself. Without the grab the phone just works over the board (it is
    // drawn above it, see `coverCheat`); the board's own click-away still closes the
    // board, and the grab comes back when the board is gone.
    readonly property bool grabWanted: (open || settingsOpen) && win.visible && !PanelImages.busy
                                       && !root.useCatcher && !root.coverCheat

    onGrabWantedChanged: {
        if (grabWanted) {
            grabDelay.restart()
        } else {
            grabDelay.stop()
            grab.active = false
        }
    }

    Timer {
        id: grabDelay
        interval: 80
        onTriggered: grab.active = root.grabWanted
    }

    Connections {
        target: WallpaperService

        function onFolderPickingChanged() {
            if (WallpaperService.folderPicking && (root.wallpapersOpen || root.settingsOpen))
                root.close()
        }
    }

    Connections {
        target: IconCursorService

        function onPickingChanged() {
            if (IconCursorService.picking && root.settingsOpen)
                root.close()
        }
    }

    HyprlandFocusGrab {
        id: grab
        windows: root.grabList
        onCleared: {
            if (!root.clickOutside || root.turningBack || stage.flipping) {
                grab.active = false
                grabDelay.restart()
                return
            }
            root.close()
        }
    }

    // A pinned phone is a corner player: a click on the desktop beside it must
    // not close it, so the click-away holds off while it is pinned.
    readonly property bool useCatcher: open && !root.pinned && (launching || root.clickOutside)

    PanelWindow {
        id: catcher

        screen: root.targetScreen
        visible: root.useCatcher && win.visible
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "tansu-quickpanel-clickaway"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors {
            left: true
            right: true
            top: true
            bottom: true
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: root.close()
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: hot

            required property var modelData

            screen: modelData
            visible: root.hotEdge
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            anchors {
                bottom: true
            }
            implicitWidth: root.hotWidth
            implicitHeight: root.hotHeight

            property bool armed: true

            Item {
                anchors.fill: parent

                HoverHandler {
                    onHoveredChanged: {
                        if (!hovered) {
                            hot.armed = true
                            dwell.stop()
                        } else if (root.open || root.settingsOpen || Date.now() < root.hotBlockedUntil) {
                            hot.armed = false
                        } else if (hot.armed) {
                            dwell.restart()
                        }
                    }
                }
            }

            Timer {
                id: dwell
                interval: Math.max(1, root.hotDwell)
                onTriggered: {
                    hot.armed = false
                    root.openOn(hot.modelData)
                }
            }
        }
    }

    // Overlay, so a bar on that edge can't swallow the hover; gone while the
    // phone is up, so it never takes a click meant for the click-away.
    Variants {
        model: {
            const out = []
            for (const s of Quickshell.screens)
                for (const c of root.hotCorners)
                    out.push({ screen: s, corner: c })
            return out
        }

        PanelWindow {
            id: hotCorner

            required property var modelData

            readonly property bool atTop: modelData.corner === "topLeft" || modelData.corner === "topRight"
            readonly property bool atRight: modelData.corner === "topRight" || modelData.corner === "bottomRight"

            screen: modelData.screen
            visible: !root.open && !root.settingsOpen && !root.alertUp
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "tansu-quickpanel-hotcorner"
            implicitWidth: root.hotCornerSize
            implicitHeight: root.hotCornerSize
            anchors {
                left: !hotCorner.atRight
                right: hotCorner.atRight
                top: hotCorner.atTop
                bottom: !hotCorner.atTop
            }

            property bool armed: true

            HoverHandler {
                onHoveredChanged: {
                    if (!hovered) {
                        hotCorner.armed = true
                        cornerDwell.stop()
                    } else if (root.open || root.settingsOpen || Date.now() < root.hotBlockedUntil) {
                        hotCorner.armed = false
                    } else if (hotCorner.armed) {
                        cornerDwell.restart()
                    }
                }
            }

            Timer {
                id: cornerDwell
                interval: Math.max(1, root.hotDwell)
                onTriggered: {
                    hotCorner.armed = false
                    root.openAt(hotCorner.modelData.screen, hotCorner.modelData.corner)
                }
            }
        }
    }

    PanelWindow {
        id: win

        screen: root.targetScreen
        visible: root.up || stage.lift < stage.hiddenLift || root.settingsShown
        color: "transparent"

        exclusionMode: ExclusionMode.Ignore
        // The Settings (like they always were) go over everything, fullscreen
        // windows included.
        // Also the notification alert: a fullscreen window is above Top, and the
        // whole point of the phone rising is to be seen.
        // Also while Apps is up: the click-away window (`catcher`) is on Top, so the phone
        // must be above it.
        // Also while Edit Desktop is on: its shelf and guides windows are on Overlay, and
        // the phone is opened after them, so on the same layer it is drawn over them.
        WlrLayershell.layer: (BarPositionService.position === "bottom" || root.settingsShown
                              || root.alertMode || root.useCatcher || root.coverCheat
                              || EditMode.active || root.pinned) ? WlrLayer.Overlay
                                                  : WlrLayer.Top
        readonly property bool atTop: root.corner === "topLeft" || root.corner === "topRight"
        readonly property bool atRight: root.corner === "topRight" || root.corner === "bottomRight"
        readonly property bool atLeft: root.corner === "topLeft" || root.corner === "bottomLeft"

        anchors {
            bottom: true
            left: win.atLeft
            right: win.atRight
        }

        // The window reaches `bleed` px *past* the bottom of the screen
        // (a negative bottom margin, and the same amount added to
        // implicitHeight below, so the phone sits exactly where it did).
        // In a screen recording the bottom of the phone stopped ~7px short
        // of the screen edge for a few frames at the top of the bounce,
        // with the desktop showing under it: the timing (starts ~170ms
        // in, peaks ~230ms, gone by ~350ms) matches the compositor's own
        // layer-open animation overshooting, i.e. the whole surface being
        // lifted a few px off the edge, which nothing inside the window
        // can fix. With the surface extending past the edge, a lift of up
        // to `bleed` px still leaves it covering the screen's last row.
        // 4% of the part that shows (so it grows with a bigger monitor /
        // scale, where the lift would too), never under 24px.
        readonly property real bleed: Math.max(24, Math.ceil((topRoom + shownHeight) * 0.04))
        margins.bottom: -Math.ceil(bleed)
        WlrLayershell.namespace: "tansu-quickpanel"

        // The panel never wants keyboard input for itself (every other
        // tile is a click or a drag) — except the Wi-Fi password field
        // in NetworkDialog.qml, the one text entry anywhere in the Quick
        // Panel. OnDemand rather than Exclusive (what Overview.qml
        // uses for its always-visible search box): it only actually
        // takes the keyboard while that field itself holds focus, so
        // typing anywhere else on the desktop is unaffected the rest of
        // the time the panel's open.
        // The Settings take it too (Escape, the arrow keys, 1-7).
        // The Apps screen's search box and typing a letter on Quick take it too
        // (Settings > General > Quick Panel > Type to search).
        //
        // The Apps screen (the app launcher) is the exception: it is a search box
        // that must work the moment it opens, wherever the mouse is. OnDemand only
        // hands the keyboard over once the compositor focuses the window (pointer
        // over it / a click), so with the mouse elsewhere nothing could be typed.
        // While Apps is up it takes the keyboard Exclusive, like the Overview.
        // (Settings > Keys records combinations without it: the focus grab already
        // keeps the keyboard on the phone, and Exclusive would clear the grab,
        // which closes the phone.)
        WlrLayershell.keyboardFocus: (root.open && root.launching) ? WlrKeyboardFocus.Exclusive
                                   : (panelFace.networkDialogOpen || root.settingsOpen || root.turningBack
                                      || root.phoneKeysWanted) ? WlrKeyboardFocus.OnDemand
                                                               : WlrKeyboardFocus.None

        // Pinned, only the push-pin takes a click: the rest of the window is
        // click-through, so whatever is under the phone still works.
        mask: Region {
            item: hitRect
            Region { item: railHost }
            Region { item: setHit }
            Region {
                x: Math.floor(stage.pinKeyBox.x)
                y: Math.floor(stage.pinKeyBox.y)
                width: Math.ceil(stage.pinKeyBox.w)
                height: Math.ceil(stage.pinKeyBox.h)
            }
        }

        // Click away, from inside the phone's own window. On some setups the
        // compositor keeps the pointer on the window that holds the keyboard
        // Exclusive (the Apps screen does), so a click beside the phone never
        // reaches `catcher`: it arrives here instead, at a place far outside
        // this small window. This area is far bigger than the window and sits
        // under everything; a press that is not on the phone, or the rail beside
        // it, closes the launcher.
        MouseArea {
            id: awayArea
            enabled: root.useCatcher
            x: -20000
            y: -20000
            width: 40000
            height: 40000
            z: -1000
            acceptedButtons: Qt.AllButtons

            function over(item, px, py) {
                const p = awayArea.mapToItem(item, px, py)
                return p.x >= 0 && p.y >= 0 && p.x <= item.width && p.y <= item.height
            }

            onPressed: mouse => {
                if (over(hitRect, mouse.x, mouse.y) || over(railHost, mouse.x, mouse.y)
                        || over(setHit, mouse.x, mouse.y)) {
                    mouse.accepted = false
                    return
                }
                root.close()
            }
        }

        readonly property real uiScale: ShellScale.forScreen(root.targetScreen)

        // Shrink to fit the screen's height (never grow past maxScale) —
        // that is `natural`, and at a scale of 1 it is the whole answer.
        // The monitor's scale multiplies it, so 1.25 makes the phone
        // 25% bigger and 0.8 makes it 20% smaller, except that a phone
        // made bigger still may not outgrow the screen: `cap` is the size
        // at which the window (headroom + the part of the phone that
        // shows, or the Power rail if that reaches lower) would just
        // touch the bottom of the bar. Built only from static numbers
        // (never from `fit` itself) so it can't loop.
        readonly property real fit: {
            const h = root.targetScreen ? root.targetScreen.height : 1080
            const room = h - root.barHeight - 4 - root.edgeMargin - root.headroom
            const natural = Math.max(0.3, Math.min(root.maxScale, room / phone.implicitHeight))
            const tall = phone.swing.top + Math.max(
                phone.implicitHeight * Math.min(1, Math.max(0.2, root.peekEff)), railMaxY)
            const cap = (h - (root.barHeight + root.headroom) * uiScale) / Math.max(1, tall)
            return Math.max(0.3, Math.min(natural * uiScale, Math.max(natural, cap)))
        }

        readonly property real leftExtent: root.flat2d
            ? Math.max((phone.screenCenterX + phone.swing.left) * fit, rightExtent)
            : (phone.screenCenterX + phone.swing.left) * fit

        readonly property real railRawX: phone.faceWidth + root.railGap
        readonly property real railRawY: root.flat2d ? 197 : 276

        readonly property var railStaticBounds: {
            const x1 = railRawX + powerRail.pillFixedRight
            const x0 = x1 - powerRail.pillWidth
            const y0 = railRawY, y1 = railRawY + powerRail.implicitHeight
            let minX = 1e9, maxX = -1e9, minY = 1e9, maxY = -1e9
            for (const k of [1, 0.5, -0.4]) {
                const b = PM.baseFor(phone.faceWidth, phone.faceHeight, phone.thickness,
                                     phone.yaw + root.tiltYaw * k,
                                     phone.pitch + root.tiltPitch * k,
                                     phone.roll + root.tiltRoll * k,
                                     phone.perspective, phone.pose)
                for (const c of [[x0, y0], [x1, y0], [x0, y1], [x1, y1]]) {
                    const p = PM.apply(b, c[0], c[1], 0)
                    minX = Math.min(minX, p.x); maxX = Math.max(maxX, p.x)
                    minY = Math.min(minY, p.y); maxY = Math.max(maxY, p.y)
                }
            }
            return { minX: minX, maxX: maxX, minY: minY, maxY: maxY }
        }
        readonly property real railMinX: railStaticBounds.minX
        readonly property real railMaxX: railStaticBounds.maxX
        readonly property real railMinY: railStaticBounds.minY
        readonly property real railMaxY: railStaticBounds.maxY

        readonly property real rightExtent: (Math.max(phone.implicitWidth + phone.swing.right, railMaxX)
                                             - phone.screenCenterX) * fit

        // Room above the resting spot for the bounce (and for the turned
        // phone's top corner). Assumes the rail's own projected top
        // (railMinY) never lands above y = 0 for reasonable railRawY /
        // railGap values — true for the defaults above; push this out
        // further if you change them enough to flip that.
        readonly property real topRoom: root.headroom * uiScale + phone.swing.top * fit

        readonly property real shownHeight: Math.max(
            phone.implicitHeight * fit * Math.min(1, Math.max(0.2, root.peekEff)),
            railMaxY * fit)

        // A top corner sits fully on screen, clear of a bar on that edge; the
        // window has to grow up to the screen's top edge to draw it there, which
        // is what `cornerShiftY` (its rest, from the screen top) accounts for.
        readonly property real cornerInset: Math.max(root.headroom * uiScale,
            BarPositionService.position === "top" ? root.barHeight + 6 * uiScale : 0)
        readonly property real cornerShiftY: atTop ? cornerInset - root.headroom * uiScale : 0
        readonly property real cornerRoom: atTop
            ? Math.max(0, Math.ceil(monitorH - (topRoom + shownHeight))) : 0

        // Where the bottom of the monitor cuts the phone off, in the flat
        // 654x1214 design's own y coordinates (the ones QuickPanelFace.qml
        // is drawn in) at design column x. The phone is posed in 3D and
        // only `peek` of it shows, so this is NOT simply peek * faceHeight:
        // it's found by working out which design row lands on the cutoff
        // line. The cutoff is level on the monitor but slanted on the face
        // (the tilt makes it lower on the left than on the right), so it
        // depends on x. QuickPanelFace uses the two ends below to size the
        // notification list so it runs right down to the screen edge and
        // scrolls instead of its lower cards hanging below where you can't
        // reach them. Static on purpose (resting pose, not the live
        // drawBase) for the same reason as railStaticBounds above.
        //
        // `extraPx` is how far (px on screen) the phone is raised above
        // its resting spot: the monitor edge then reaches that much
        // further down the face (see faceRevealLeft below).
        //
        // `turn` is how far the phone is still turned toward its pocket
        // pose (stage.tilt: 0 = upright, the default). Only the reveal
        // below needs it — see faceRevealLeft.
        function faceCutoffAt(x, extraPx, turn) {
            const k = turn || 0
            const m = PM.baseFor(phone.faceWidth, phone.faceHeight, phone.thickness,
                                 phone.yaw + root.tiltYaw * k,
                                 phone.pitch + root.tiltPitch * k,
                                 phone.roll + root.tiltRoll * k,
                                 phone.perspective, phone.pose)
            const Y = (atTop ? phone.implicitHeight : shownHeight + (extraPx || 0)) / fit
            const den = Y * m[13] - m[5]
            if (Math.abs(den) < 1e-9)
                return phone.faceHeight
            return Math.min(phone.faceHeight, (m[4] * x + m[7] - Y * (m[12] * x + m[15])) / den)
        }
        readonly property real faceCutoffLeftY: faceCutoffAt(0)
        readonly property real faceCutoffRightY: faceCutoffAt(phone.faceWidth)

        readonly property real faceRevealLeft: {
            let reach = faceCutoffLeftY
            for (const k of [0, 0.05, 0.1, 0.15])
                reach = Math.max(reach, faceCutoffAt(0, root.bounce, k))
            return Math.max(0, reach - faceCutoffLeftY)
        }

        readonly property real alertLift: {
            if (atTop)
                return 0
            const m = PM.baseFor(phone.faceWidth, phone.faceHeight, phone.thickness,
                                 phone.yaw, phone.pitch, phone.roll,
                                 phone.perspective, phone.pose)
            let low = 0
            for (const x of [47, 607])
                low = Math.max(low, PM.apply(m, x, 204, 0).y)
            return Math.max(0, shownHeight - (low * fit + root.alertMargin * uiScale))
        }

        onVisibleChanged: {
            if (!visible) {
                root.alertMode = false
                slideAnim.stop()
                root.setRoute(PR.open("quick"))
                pager.contentX = 0
                appsFace.reset()
                root.lyricsShown = false
                root.pinned = false
                stage.pin = 0
            }
        }

        readonly property real monitorW: root.targetScreen ? root.targetScreen.width : 1920
        readonly property real monitorH: root.targetScreen ? root.targetScreen.height : 1080
        readonly property real baseW: Math.ceil(leftExtent + rightExtent)
        readonly property real baseH: Math.ceil(topRoom + shownHeight) + Math.ceil(bleed)

        // The Settings phone's scale: the Quick Panel's own (so a pill is the
        // same size on screen in both), never so big that it wouldn't fit the
        // monitor.
        readonly property real sFit: {
            const cap = Math.min((monitorW - 24) / (2 * sstage.halfW * sstage.grow),
                                 (monitorH - 24) / (2 * sstage.halfH * sstage.grow))
            return Math.max(0.3, Math.min(fit, cap))
        }

        readonly property var flipRoom: {
            const sp = sstage.phone
            const qcx = phone.screenCenterX, qcy = phone.screenCenterY
            const scx = sp.screenCenterX, scy = sp.screenCenterY
            const x0 = leftExtent - baseW / 2
            const u0 = baseH + cornerRoom - (topRoom + cornerShiftY + qcy * fit)
            const u1 = Math.ceil(bleed) + monitorH / 2
            let needU = u0, needHalfW = Math.abs(x0)
            for (let i = -4; i <= 24; i++) {
                const p = i / 20
                const A = FM.quickScale(p, fit, sFit, root.flipDip)
                const As = A / FM.SIZE_RATIO
                const x = Math.abs(x0 * (1 - p))
                const u = u0 + (u1 - u0) * p
                const yw = phone.yaw + (sstage.yaw - phone.yaw) * p
                const pt = phone.pitch + (sstage.pitch - phone.pitch) * p
                const bq = PM.boundsFor(phone.faceWidth, phone.faceHeight, phone.thickness, phone.cornerRadius,
                                        yw, pt, phone.roll + FM.quickRoll(p), phone.perspective, phone.pose)
                const bs = PM.boundsFor(sp.faceWidth, sp.faceHeight, sp.thickness, sp.cornerRadius,
                                        yw, pt, sp.roll + FM.settingsRoll(p), sp.perspective, sp.pose)
                needU = Math.max(needU, u + (qcy - bq.minY) * A, u + (scy - bs.minY) * As)
                needHalfW = Math.max(needHalfW,
                                     x + Math.max(qcx - bq.minX, bq.maxX - qcx) * A,
                                     x + Math.max(scx - bs.minX, bs.maxX - scx) * As)
            }
            needU = Math.max(needU, u1 + sstage.halfH * sFit * sstage.grow)
            needHalfW = Math.max(needHalfW, sstage.halfW * sFit * sstage.grow)
            return { u: Math.min(needU + 4, monitorH + Math.ceil(bleed)),
                     halfW: Math.min(needHalfW + 4, monitorW / 2) }
        }
        // The window is as wide as the monitor, so the phone can be pinned
        // into a corner without the layer surface being moved or resized (a
        // live resize is what stutters).
        readonly property real turnPadX: Math.max(0, Math.ceil(flipRoom.halfW - baseW / 2))
        readonly property real padX: Math.max(turnPadX, Math.ceil((monitorW - baseW) / 2))
        // A hot corner now shifts the phone inside the window instead of the
        // window itself, which lands it exactly where anchoring used to.
        readonly property real cornerDX: win.atLeft ? turnPadX - padX
            : win.atRight ? monitorW - baseW - turnPadX - padX : 0
        readonly property real padTop: Math.max(0, Math.ceil(flipRoom.u) - baseH - cornerRoom)

        readonly property real setMidX: implicitWidth / 2
        readonly property real setMidY: implicitHeight - Math.ceil(bleed) - monitorH / 2

        readonly property real dpr: root.targetScreen ? root.targetScreen.devicePixelRatio : 1
        implicitWidth: Math.min(monitorW, root.flat2d ? 2 * Math.ceil((baseW + 2 * padX) / 2)
                                                      : baseW + 2 * padX)
        implicitHeight: baseH + padTop + cornerRoom

        FocusScope {
            id: keys
            anchors.fill: parent
            focus: root.open || root.settingsOpen

            Keys.onPressed: event => root.quickKeyPressed(event)
        }

        Item {
            id: stage
            anchors.fill: parent

            property real lift: 100000
            property real tilt: 1

            // +1 rises out of the bottom edge, -1 (a top corner) drops in from
            // above. `lift` is a distance along it, so the bounce keeps its shape.
            readonly property int dir: win.atTop ? -1 : 1

            property real flip: 0
            property real wob: 0
            property real sPop: 1
            property real sAlpha: 1
            property real sTilt: 0

            readonly property bool flipping: flipPrep.running || flipAnim.running

            // The Quick Panel's phone takes the mouse (and the click-away's
            // eyes) unless the Settings have settled in its place.
            readonly property bool quickInput: !(root.settingsOpen && flip >= 1 && !flipping)

            readonly property real quickScale: FM.quickScale(flip, win.fit, win.sFit, root.flipDip)
            readonly property real quickAlpha: FM.quickAlpha(flip)
            readonly property real quickCX: restRect.x + phone.screenCenterX * win.fit
            readonly property real quickCY: restRect.y + phone.screenCenterY * win.fit
            readonly property real flipCX: quickCX + (win.setMidX - quickCX) * flip
            readonly property real flipCY: quickCY + (win.setMidY - quickCY) * flip

            // ===== the pin =====
            // 0 = the phone where it always is, 1 = the corner player. Only
            // the pose changes (a redraw in the cheap moving quality, like the
            // pull-out); the move and the size are item transforms.
            property real pin: 0
            property bool pinMoving: false
            readonly property real pinZoom: 1 - pin * (1 - root.pinScale)
            readonly property real pinFade: 1 - pin * (1 - root.pinOpacity)
            // Turned the other way round, so the screen looks into the desktop
            // (at rest it is turned out of it). Absolute, because the resting
            // pose is whatever the pull-out left behind.
            property real pinYawTarget: -33
            property real pinRollTarget: 0
            readonly property real pinYaw: (pinYawTarget - phone.yaw - tilt * root.tiltYaw) * pin
            readonly property real pinRoll: (pinRollTarget - tilt * root.tiltRoll) * pin

            // The body is a 3D shape inside the pose box, so the corner is
            // measured on the body itself in the pinned pose.
            readonly property real pinS: win.fit * root.pinScale
            readonly property var pinBounds: PM.boundsFor(phone.faceWidth, phone.faceHeight,
                                                          phone.thickness, phone.cornerRadius,
                                                          phone.yaw + pinYawTarget, phone.pitch,
                                                          phone.roll + pinRollTarget,
                                                          phone.perspective, phone.pose)
            // boundsFor answers in the item's own coordinates already.
            readonly property real pinBodyLeft: pinBounds.minX
            readonly property real pinBodyTop: pinBounds.minY
            readonly property real pinBodyW: pinBounds.maxX - pinBounds.minX
            readonly property real pinBodyH: pinBounds.maxY - pinBounds.minY
            // The left and bottom edges hang past the monitor: tucked in.
            readonly property real pinCX: (phone.screenCenterX - pinBodyLeft - root.pinPeekX * pinBodyW) * pinS
            readonly property real pinCY: (win.implicitHeight - Math.ceil(win.bleed))
                                          + (root.pinPeekY * pinBodyH
                                             - (pinBodyTop + pinBodyH - phone.screenCenterY)) * pinS

            // The push-pin is the only thing a pinned phone takes a click on,
            // so the input mask is this box: the key's corners through the same
            // projection the screen uses, then the phone's own move and scale.
            readonly property var pinKeyBox: {
                const r = lyricsFace.pinRect
                const inset = phone.screenInset
                let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9
                for (const c of [[r.x, r.y], [r.x + r.width, r.y],
                                 [r.x, r.y + r.height], [r.x + r.width, r.y + r.height]]) {
                    const p = PM.apply(phone.drawBase, c[0] - inset, c[1] - inset, 0)
                    x0 = Math.min(x0, p.x); x1 = Math.max(x1, p.x)
                    y0 = Math.min(y0, p.y); y1 = Math.max(y1, p.y)
                }
                const s = stage.quickScale * stage.pinZoom
                return { x: restRect.x + phone.x + x0 * s, y: restRect.y + phone.y + y0 * s,
                         w: (x1 - x0) * s, h: (y1 - y0) * s }
            }

            readonly property real phoneCX: flipCX + (pinCX - flipCX) * pin
            readonly property real phoneCY: flipCY + (pinCY - flipCY) * pin
            // The pose box, wherever the phone is: what the click mask covers.
            readonly property real poseX: phoneCX - phone.screenCenterX * quickScale * pinZoom
            readonly property real poseY: phoneCY - phone.screenCenterY * quickScale * pinZoom

            function setPin(on) {
                pinAnim.stop()
                pinAnim.to = on ? 1 : 0
                pinMoving = true
                pinAnim.start()
            }

            NumberAnimation {
                id: pinAnim
                target: stage
                property: "pin"
                duration: root.pinMs
                easing.type: Easing.InOutCubic
                onStopped: stage.pinMoving = false
            }

            property real rise: root.alertMode ? win.alertLift : 0
            Behavior on rise {
                enabled: win.visible
                NumberAnimation {
                    duration: 320
                    easing.type: Easing.OutCubic
                }
            }

            property real buzzT: 0
            readonly property real buzzX: buzzOffset(0)
            readonly property real buzzY: buzzOffset(1) * 0.35

            readonly property bool direct: root.flat2d && phone.flat && flip === 0 && wob === 0 && pin === 0
            readonly property real faceMidX: buzzX + flipCX
            readonly property real faceMidY: lift * dir + rise + buzzY + flipCY
            readonly property real faceLeftDev: ((win.monitorW - win.implicitWidth) / 2 + faceMidX) * win.dpr
                                                - phone.directW / 2
            readonly property real faceTopDev: (win.monitorH + Math.ceil(win.bleed) - win.implicitHeight + faceMidY) * win.dpr
                                               - phone.directH / 2
            readonly property real snapX: direct ? (Math.round(faceLeftDev) - faceLeftDev) / win.dpr : 0
            readonly property real snapY: direct ? (Math.round(faceTopDev) - faceTopDev) / win.dpr : 0

            function buzzOffset(axis) {
                if (buzzT <= 0 || root.buzzAmount === 0)
                    return 0
                const total = root.buzzPulses * root.buzzBurstMs
                            + Math.max(0, root.buzzPulses - 1) * root.buzzGapMs
                let t = buzzT * total
                const period = root.buzzBurstMs + root.buzzGapMs
                const local = t % period
                if (local >= root.buzzBurstMs)
                    return 0
                const k = local / root.buzzBurstMs
                const env = 1 - 0.55 * k * k
                const phase = 2 * Math.PI * root.buzzHz * local / 1000
                return root.buzzAmount * env * Math.sin(phase + axis * 1.3)
            }

            readonly property real enterFrom: win.shownHeight + 2

            readonly property real exitTail: Math.ceil(win.shownHeight * 0.3 + phone.swing.top * win.fit)
            readonly property real hiddenLift: enterFrom + exitTail

            // `lift` is a plain pixel count, but hiddenLift is as big as
            // the window, which follows this monitor's scale (and which
            // monitor the panel is on). A phone that was put away when
            // the window was small therefore sat at the *old* hiddenLift;
            // make the window bigger (scaling 80% -> 100%) and that old
            // number is suddenly less than the new one, which is exactly
            // what `win.visible` reads as "still on its way out" — so the
            // window came back and showed the phone. While it's put away
            // and nothing is animating, keep it at the current
            // hiddenLift so a resize can't leave it stranded above it.
            //
            // Not while `lift` still has its start-up value (100000 = never
            // shown, far off the screen already; onUpChanged pulls it down
            // to hiddenLift the first time the phone comes up). The first
            // hiddenLift comes out while win.visible is being worked out,
            // and writing `lift` from in here - which win.visible reads -
            // is what Qt logged as "Binding loop detected for property
            // visible" on every start.
            onHiddenLiftChanged: {
                if (stage.lift >= 100000)
                    return
                if (!root.up && !exitAnim.running && !exitDelay.running)
                    stage.lift = stage.hiddenLift
            }

            property real exitPeak: 0
            property real exitPeakMs: 130

            Item {
                id: hitRect
                readonly property real drop: root.alertMode ? win.alertLift : 0
                readonly property real zoom: stage.quickScale * stage.pinZoom
                readonly property real full: phone.implicitHeight * zoom
                // Follows the phone into the corner. Pinned it is empty: the
                // phone is click-through, see pinKeyBox and the window's mask.
                x: root.pinned ? 0 : stage.poseX
                y: root.pinned ? 0 : stage.poseY + drop
                width: stage.quickInput && !root.pinned
                    ? phone.implicitWidth * zoom + (root.flat2d ? phone.powerStick : phone.buttonStick) * win.fit : 0
                height: stage.quickInput && !root.pinned
                    ? Math.max(0, Math.max(win.atTop ? full : restRect.height, full) - drop) : 0
            }

            Item {
                id: setHit
                x: win.setMidX - sstage.phone.screenCenterX * win.sFit
                y: win.setMidY - sstage.phone.screenCenterY * win.sFit
                width: root.settingsOpen ? sstage.phone.implicitWidth * win.sFit : 0
                height: root.settingsOpen ? sstage.phone.implicitHeight * win.sFit : 0
            }

            Item {
                id: restRect

                x: win.padX + win.cornerDX + win.leftExtent - phone.screenCenterX * win.fit
                y: win.padTop + win.topRoom + win.cornerShiftY
                width: phone.implicitWidth * win.fit
                height: win.shownHeight

                PhoneBody {
                    id: phone

                    powerButton: true
                    powerOn: panelFace.powerMenuOpen
                    onPowerClicked: panelFace.togglePowerMenu()
                    yaw: root.flat2d ? 0 : 33
                    pitch: root.flat2d ? 0 : 18
                    flat: root.flat2d && stage.flip === 0 && !stage.flipping
                    plain: root.flat2d
                    faceDirect: stage.direct

                    x: stage.buzzX + stage.phoneCX - restRect.x - phone.screenCenterX * stage.quickScale * stage.pinZoom + stage.snapX
                    y: stage.lift * stage.dir + stage.rise + stage.buzzY + stage.phoneCY - restRect.y - phone.screenCenterY * stage.quickScale * stage.pinZoom + stage.snapY
                    transformOrigin: Item.TopLeft
                    scale: stage.quickScale * stage.pinZoom

                    opacity: stage.quickAlpha * stage.pinFade
                    visible: opacity > 0.001
                    enabled: stage.flip === 0 && !stage.flipping

                    windowShown: win.visible

                    // Not root.routing: a page slide only moves the face inside
                    // the phone, and switching the body to its moving samples
                    // reallocates every layer mid-swipe (that was the stutter).
                    moving: enterAnim.running || exitAnim.running
                            || exitDelay.running || !win.visible || stage.flipping || ring.running
                            || stage.pinMoving
                    busy: PanelActivity.busy

                    turnRoll: stage.flipping ? -90 : 0

                    rollOffset: stage.tilt * root.tiltRoll + FM.quickRoll(stage.flip) + stage.wob + stage.pinRoll
                    pitchOffset: stage.tilt * root.tiltPitch + (sstage.pitchEnd - phone.pitch) * stage.flip + stage.wob * 0.5
                    yawOffset: stage.tilt * root.tiltYaw + (sstage.yawEnd - phone.yaw) * stage.flip
                               + stage.pinYaw

                    swingRoll: root.tiltRoll
                    swingPitch: root.tiltPitch
                    swingYaw: root.tiltYaw

                    // Draw the screen at the size it ends up on the monitor.
                    // Don't raise this to the plain pixel ratio: the GPU
                    // then shrinks a bigger texture without mipmaps and
                    // the edges come out jagged (see PhoneBody.renderScale).
                    renderScale: win.fit * (root.targetScreen ? root.targetScreen.devicePixelRatio : 1)

                    // Everything on the screen is cut to the phone's shape here,
                    // once: the pages move under a fixed mask, so a page's own
                    // corners can't cross the bezel while it slides.
                    Item {
                        id: faceClip

                        x: phone.screenInset
                        y: phone.screenInset
                        width: phone.faceWidth - 2 * phone.screenInset
                        height: phone.faceHeight - 2 * phone.screenInset
                        clip: true

                        layer.enabled: true
                        layer.smooth: true
                        layer.textureSize: Qt.size(Math.ceil(width * phone.renderScale * 2),
                                                   Math.ceil(height * phone.renderScale * 2))
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: screenMask
                        }

                        // Quick | Rashin, one face wide per page. The faces are
                        // wider than the screen by the bezel on each side, so
                        // each sits inset inside its page.
                        Flickable {
                            id: pager

                            anchors.fill: parent
                            contentWidth: 2 * phone.faceWidth
                            contentHeight: height
                            flickableDirection: Flickable.HorizontalFlick
                            boundsBehavior: Flickable.DragAndOvershootBounds
                            maximumFlickVelocity: 2000
                            flickDeceleration: 2500
                            interactive: root.open && !root.settingsShown && !stage.flipping
                                       && root.faceScreen !== "apps" && !root.lyricsShown
                            clip: true

                            Component.onCompleted: contentX = 0
                            onMovementStarted: slideAnim.stop()
                            // MovementEnded comes at the release, before the
                            // fling has run, so the page is only chosen once the
                            // content has actually stopped (settleTimer).
                            onMovementEnded: settleTimer.restart()

                            QuickPanelFace {
                                id: panelFace

                                x: -phone.screenInset
                                y: -phone.screenInset

                                enabled: root.faceScreen === "quick" && root.open
                                renderScale: phone.renderScale
                                bannerSource: PanelImages.banner !== "" ? PanelImages.banner : root.bannerSource
                                avatarSource: PanelImages.avatar !== "" ? PanelImages.avatar : root.avatarSource
                                onBannerPickRequested: PanelImages.pick("banner")
                                onAvatarPickRequested: PanelImages.pick("avatar")
                                onBannerResetRequested: PanelImages.clear("banner")
                                onAvatarResetRequested: PanelImages.clear("avatar")

                                clockText: Qt.formatDateTime(clock.date, SettingsService.flag("time.use24h") ? "HH:mm" : "hh:mmAP")
                                dateText: Qt.formatDate(clock.date, "ddd, d  MMM")
                                userName: root.source.userName
                                hostName: root.source.hostName

                                downloadBps: root.source.downloadBps
                                uploadBps: root.source.uploadBps

                                networkKind: root.source.networkKind
                                networkOn: root.source.networkOn
                                networkDetail: root.source.networkDetail
                                bluetoothOn: root.source.bluetoothOn
                                bluetoothConnected: root.source.bluetoothDevice !== ""
                                bluetoothDetail: root.source.bluetoothDetail
                                microphoneOn: root.source.microphoneOn
                                speakerOn: root.source.speakerOn
                                microphoneVolume: root.source.microphoneVolume
                                speakerVolume: root.source.speakerVolume
                                brightness: root.source.brightness
                                gamma: root.source.gamma
                                keepAwakeOn: root.source.keepAwakeOn
                                notificationsOn: root.source.notificationsOn
                                editing: root.source.editing
                                nightLightOn: root.source.nightLightOn
                                nightLightTemperature: root.source.nightLightTemperature
                                nightLightAuto: root.source.nightLightAuto
                                nightLightAutoFrom: root.source.nightLightAutoFrom
                                nightLightAutoTo: root.source.nightLightAutoTo
                                gameModeOn: root.source.gameModeOn
                                darkModeOn: root.source.darkModeOn
                                darkModeName: root.source.darkModeName
                                easyEffectsOn: root.source.easyEffectsOn
                                warpOn: root.source.warpOn
                                warpConnecting: root.source.warpConnecting
                                warpInstalled: root.source.warpInstalled
                                keyboardOn: root.source.keyboardOn
                                powerProfileName: root.source.powerProfileName
                                musicListening: root.source.musicListening
                                antiFlashbangOn: root.source.antiFlashbangOn
                                antiFlashbangLevel: root.source.antiFlashbangLevel
                                tiles: root.source.tiles
                                tileColumns: root.source.tileColumns
                                mediaOn: SettingsService.flag("quick.media")
                                mediaPresent: root.mediaSource ? root.mediaSource.present : false
                                mediaPlaying: root.mediaSource ? root.mediaSource.playing : false
                                mediaTitle: root.mediaSource ? root.mediaSource.title : ""
                                mediaArtist: root.mediaSource ? root.mediaSource.artist : ""
                                mediaArt: root.mediaSource ? root.mediaSource.artUrl : ""
                                onLyricsRequested: root.openLyrics()
                                onMediaToggleRequested: if (root.mediaSource) root.mediaSource.togglePlaying()
                                onMediaPreviousRequested: if (root.mediaSource) root.mediaSource.previous()
                                onMediaNextRequested: if (root.mediaSource) root.mediaSource.next()
                                notifications: root.notificationSource.entries
                                alertEntry: root.notificationSource.toast
                                alertShown: root.notificationSource.toastActive
                                visibleBottomLeft: win.faceCutoffLeftY
                                visibleBottomRight: win.faceCutoffRightY
                                visibleExtra: win.faceRevealLeft

                                wifiNetworks: root.source.wifiNetworks
                                wifiScanning: root.source.wifiScanning
                                wifiManualScanning: root.source.wifiManualScanning
                                wifiConnectingSsid: root.source.wifiConnectingSsid
                                wifiConnectError: root.source.wifiConnectError
                                bluetoothDevices: root.source.bluetoothDevices
                                bluetoothScanning: root.source.bluetoothScanning
                                bluetoothManualScanning: root.source.bluetoothManualScanning
                                bluetoothConnectingAddress: root.source.bluetoothConnectingAddress
                                bluetoothConnectError: root.source.bluetoothConnectError

                                speakerDevices: root.source.speakerDevices
                                microphoneDevices: root.source.microphoneDevices
                                speakerStreams: root.source.speakerStreams
                                microphoneStreams: root.source.microphoneStreams
                                audioDevicesScanning: root.source.audioDevicesScanning
                                audioDevicesManualScanning: root.source.audioDevicesManualScanning
                                audioDeviceSelectingId: root.source.audioDeviceSelectingId

                                onNetworkToggled: root.source.toggleNetwork()
                                onBluetoothToggled: root.source.toggleBluetooth()
                                onMicrophoneToggled: root.source.toggleMicrophone()
                                onSpeakerToggled: root.source.toggleSpeaker()
                                onMicrophoneVolumeMoved: value => root.source.setMicrophoneVolume(value)
                                onSpeakerVolumeMoved: value => root.source.setSpeakerVolume(value)
                                onBrightnessMoved: value => root.source.setBrightness(value)
                                onGammaMoved: value => root.source.setGamma(value)
                                onKeepAwakeToggled: root.source.toggleKeepAwake()
                                onNotificationsToggled: root.source.toggleNotifications()
                                onEditToggled: root.source.toggleEditing()
                                onNightLightToggled: root.source.toggleNightLight()
                                onNightLightTemperatureMoved: kelvin => root.source.setNightLightTemperature(kelvin)
                                onNightLightAutoRequested: on => root.source.setNightLightAuto(on)
                                onNightLightScheduleRequested: (from, to) => root.source.setNightLightSchedule(from, to)
                                onGameModeToggled: root.source.toggleGameMode()
                                onDarkModeToggled: root.source.toggleDarkMode()
                                onEasyEffectsToggled: root.source.toggleEasyEffects()
                                onWarpToggled: root.source.toggleWarp()
                                onKeyboardToggled: root.source.toggleKeyboard()
                                onPowerProfileCycled: root.source.cyclePowerProfile()
                                onMusicRecognitionToggled: root.source.toggleMusicRecognition()
                                onAntiFlashbangToggled: root.source.toggleAntiFlashbang()
                                onTileActionRequested: id => root.source.runTileAction(id)
                                onTileMoveRequested: (from, to) => root.source.moveTile(from, to)
                                onTileResizeRequested: index => root.source.resizeTile(index)
                                onTileRemoveRequested: index => root.source.removeTile(index)
                                onTileAddRequested: id => root.source.addTile(id)
                                onTileColumnsRequested: columns => root.source.setTileColumns(columns)
                                onRefreshRequested: Quickshell.reload(true)
                                onSettingsRequested: root.openSettings(root.targetScreen)
                                // claim() first: hideToast() makes toastActive false,
                                // and onToastActiveChanged lowers a phone that is only
                                // up for the alert. A click never hit this (its press
                                // had already claimed the phone), but a hover has no
                                // press, so the phone was lowered before it was claimed.
                                onAlertActivated: {
                                    root.claim()
                                    root.notificationSource.hideToast()
                                }
                                onAlertDismissRequested: key => {
                                    root.claim()
                                    root.notificationSource.dismiss(key)
                                    root.notificationSource.hideToast()
                                }
                                onAlertClicked: key => {
                                    if (root.notificationSource.activate(key)) {
                                        root.notificationSource.hideToast()
                                        root.close()
                                    } else {
                                        root.claim()
                                        root.notificationSource.hideToast()
                                    }
                                }
                                onNotificationActivated: key => {
                                    if (root.notificationSource.activate(key))
                                        root.close()
                                    else
                                        root.notificationSource.dismiss(key)
                                }
                                onNotificationDismissed: key => root.notificationSource.dismiss(key)
                                onNotificationsDismissed: keys => root.notificationSource.dismissMany(keys)
                                onNotificationsCleared: root.notificationSource.clearAll()
                                onPanelCloseRequested: root.close()

                                onNetworkDialogOpenChanged: {
                                    root.source.networkDialogOpen = networkDialogOpen
                                    if (networkDialogOpen)
                                        root.source.scanWifi(false)
                                }
                                onBluetoothDialogOpenChanged: {
                                    root.source.bluetoothDialogOpen = bluetoothDialogOpen
                                    if (bluetoothDialogOpen)
                                        root.source.scanBluetooth()
                                }
                                onWifiScanRequested: root.source.scanWifi(true, true)
                                onWifiAdvancedRequested: {
                                    root.source.openNetworkSettings()
                                    panelFace.networkDialogOpen = false
                                    root.close()
                                }
                                onWifiConnectRequested: (ssid, password) => root.source.connectWifi(ssid, password)
                                onWifiDisconnectRequested: ssid => root.source.disconnectWifi(ssid)
                                onBluetoothScanRequested: root.source.scanBluetooth(true)
                                onBluetoothAdvancedRequested: {
                                    root.source.openBluetoothSettings()
                                    panelFace.bluetoothDialogOpen = false
                                    root.close()
                                }
                                onBluetoothConnectRequested: address => root.source.connectBluetoothDevice(address)
                                onBluetoothDisconnectRequested: address => root.source.disconnectBluetoothDevice(address)

                                onAudioDialogKindChanged: {
                                    root.source.audioMixerActive = (audioDialogKind !== "")
                                    if (audioDialogKind !== "")
                                        root.source.scanAudioDevices()
                                }
                                onAudioDeviceScanRequested: root.source.scanAudioDevices(true)
                                onSpeakerDeviceSelected: id => root.source.setDefaultSink(id)
                                onMicrophoneDeviceSelected: id => root.source.setDefaultSource(id)
                                onSpeakerStreamVolumeChanged: (id, value) => root.source.setStreamVolume("sink-input", id, value)
                                onSpeakerStreamMuteToggled: (id, muted) => root.source.setStreamMuted("sink-input", id, muted)
                                onMicrophoneStreamVolumeChanged: (id, value) => root.source.setStreamVolume("source-output", id, value)
                                onMicrophoneStreamMuteToggled: (id, muted) => root.source.setStreamMuted("source-output", id, muted)
                                onSpeakerStreamDragStarted: id => root.source.beginStreamDrag("sink-input", id)
                                onSpeakerStreamDragEnded: id => root.source.endStreamDrag("sink-input", id)
                                onMicrophoneStreamDragStarted: id => root.source.beginStreamDrag("source-output", id)
                                onMicrophoneStreamDragEnded: id => root.source.endStreamDrag("source-output", id)
                            }

                            AskFace {
                                id: askFace

                                x: phone.faceWidth - phone.screenInset
                                y: -phone.screenInset

                                enabled: root.faceScreen === "ai" && root.open
                                active: root.faceScreen === "ai" && root.open
                                renderScale: phone.renderScale
                                screenInset: phone.screenInset
                            }
                        }

                        // The Apps screen is not a page: it slides in over Quick
                        // from the left, and Back slides it out.
                        Item {
                            id: appsLayer

                            x: (root.faceScreen === "apps" ? 0 : -phone.faceWidth) - phone.screenInset
                            y: -phone.screenInset
                            width: phone.faceWidth
                            height: phone.faceHeight
                            z: 1

                            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                            LauncherFace {
                                id: appsFace

                                anchors.fill: parent

                                enabled: root.faceScreen === "apps" && root.open

                                source: root.appSource
                                renderScale: phone.renderScale
                                screenName: root.targetScreen ? root.targetScreen.name : ""
                                visibleBottom: Math.min(win.faceCutoffLeftY, win.faceCutoffRightY)
                                visibleReach: Math.max(win.faceCutoffLeftY, win.faceCutoffRightY) + win.faceRevealLeft
                                clockText: panelFace.clockText
                                dateText: panelFace.dateText
                                downloadBps: root.source.downloadBps
                                uploadBps: root.source.uploadBps

                                onAppActivated: app => {
                                    root.close()
                                    if (root.appSource && typeof root.appSource.launch === "function")
                                        root.appSource.launch(app)
                                    else if (app && typeof app.execute === "function")
                                        app.execute()
                                }
                                onCloseRequested: root.back()
                                onJumpRequested: n => root.jump(n)
                                onDoneRequested: root.close()
                                onPickerRequested: root.close()
                                onColorPickedBack: hex => {
                                    root.openAppsOn(root.focusedScreen())
                                    appsFace.setText("color " + hex)
                                }
                            }
                        }

                        // The lyrics tab, sliding up from under the screen.
                        Item {
                            id: lyricsLayer

                            x: -phone.screenInset
                            y: (root.lyricsShown ? 0 : phone.faceHeight) - phone.screenInset
                            width: phone.faceWidth
                            height: phone.faceHeight
                            z: 2

                            Behavior on y {
                                NumberAnimation {
                                    duration: 260
                                    easing.type: Easing.OutCubic
                                }
                            }

                            LyricsFace {
                                id: lyricsFace

                                anchors.fill: parent

                                enabled: root.lyricsShown && root.open

                                renderScale: phone.renderScale
                                visibleBottom: Math.min(win.faceCutoffLeftY, win.faceCutoffRightY)

                                title: panelFace.mediaTitle
                                artist: panelFace.mediaArtist
                                art: panelFace.mediaArt
                                playing: panelFace.mediaPlaying

                                lines: LyricsService.lines
                                status: LyricsService.status
                                sourceKind: LyricsService.sourceKind
                                sourceName: root.lyricSource

                                time: root.lyricTime
                                duration: root.lyricDuration

                                pinned: root.pinned
                                live: root.lyricsShown

                                onCloseRequested: root.closeLyrics()
                                onPinToggled: root.setPinned(!root.pinned)
                                onToggleRequested: if (root.mediaSource) root.mediaSource.togglePlaying()
                                onSeekRequested: seconds => Ryoku.Music.seek(seconds)
                                onRetryRequested: LyricsService.refresh()
                            }
                        }
                    }

                    Item {
                        id: screenMask

                        width: faceClip.width
                        height: faceClip.height
                        visible: false
                        layer.enabled: true
                        layer.smooth: true
                        layer.textureSize: Qt.size(Math.ceil(width * phone.renderScale * 2),
                                                   Math.ceil(height * phone.renderScale * 2))

                        Rectangle {
                            anchors.fill: parent
                            radius: phone.cornerRadius - phone.screenInset
                            color: "black"
                            antialiasing: true
                        }
                    }
                }

                Item {
                    id: railHost

                    // Static, the same way restRect above is: sized to
                    // hold the rail through the whole stage.lift bounce
                    // without tracking it frame by frame either — every
                    // frame of that would mean re-sending the window's
                    // input region to the compositor for the whole
                    // ~700ms bounce, on top of the resize this file used
                    // to also cause. restRect gets away with never
                    // following phone.y because topRoom already reserves
                    // room above it for the bounce; padding by
                    // root.bounce on both sides here does the same for
                    // the rail, which rises and falls by exactly that
                    // much too (railTilt.y: phone.y, below) but — unlike
                    // restRect — isn't itself pinned to a resting spot
                    // the bounce moves away from.
                    x: win.railMinX * win.fit
                    y: win.railMinY * win.fit - root.bounce * win.fit
                       + (root.alertMode ? win.alertLift : 0)
                    width: stage.quickInput && !root.pinned ? (win.railMaxX - win.railMinX) * win.fit : 0
                    height: stage.quickInput && !root.pinned
                        ? (win.railMaxY - win.railMinY) * win.fit + root.bounce * win.fit * 2 : 0
                }

                Item {
                    id: railTilt
                    visible: stage.flip === 0
                    x: phone.x
                    y: phone.y
                    transformOrigin: Item.TopLeft
                    scale: win.fit

                    PowerMenu {
                        id: powerRail
                        transform: Matrix4x4 {
                            matrix: phone.matrix(PM.trans(win.railRawX, win.railRawY, 0))
                        }
                        // Same value, same reason, as phone's own renderScale
                        // just above — see PowerMenu's own layer for why it
                        // needs it too now.
                        renderScale: phone.renderScale

                        open: panelFace.powerMenuOpen
                        onDismissRequested: panelFace.powerMenuOpen = false
                        onPowerOffRequested: root.source.powerOff()
                        onRebootRequested: root.source.reboot()
                        onLogoutRequested: root.source.logout()
                        onLockRequested: {
                            root.close()
                            root.source.lock()
                        }
                        onSleepRequested: {
                            root.close()
                            root.source.sleep()
                        }
                        onHibernateRequested: {
                            root.close()
                            root.source.hibernate()
                        }
                        onFirmwareRequested: root.source.firmwareReboot()
                        onSystemMonitorRequested: root.source.openSystemMonitor()
                    }
                }

                // Any press on a phone that only came up for a notification
                // makes it stay (claim()) — then lets the press carry on to
                // whatever button / slider is under it, so that click still
                // does its job. Off the moment the phone is a normal open
                // one, so it never gets in the way after that.
                MouseArea {
                    anchors.fill: parent
                    enabled: root.alertUp && !root.open
                    propagateComposedEvents: true
                    onPressed: mouse => {
                        root.claim()
                        mouse.accepted = false
                    }
                }
            }

            SettingsStage {
                id: sstage

                source: root.source
                notificationSource: root.notificationSource
                screenName: root.targetScreen ? root.targetScreen.name : ""
                clockText: panelFace.clockText
                dateText: panelFace.dateText
                active: root.settingsShown
                content: root.landscape
                straightOn: root.wallpapersStraight
                warmWallpapers: root.wallpapersWarm && root.warmReady && root.open && !root.settingsOpen && root.faceScreen === "apps"
                pixelRatio: root.targetScreen ? root.targetScreen.devicePixelRatio : 1
                gridOffsetX: root.flat2d ? (win.monitorW - win.implicitWidth) / 2 : 0
                gridOffsetY: root.flat2d ? win.monitorH + Math.ceil(win.bleed) - win.implicitHeight : 0

                fit: win.sFit
                centerX: stage.flipCX
                centerY: stage.flipCY
                flip: stage.flip
                quickFit: win.fit
                quickYaw: phone.yaw
                quickPitch: phone.pitch
                dipDepth: root.flipDip
                pop: stage.sPop
                alpha: stage.sAlpha
                tilt: stage.sTilt
                wob: stage.wob

                moving: settingsEnter.running || settingsExit.running || stage.flipping || ring.running || !win.visible
                busy: PanelActivity.busy
                turning: stage.flipping

                enabled: root.settingsOpen && stage.flip >= 1 && !stage.flipping

                onCloseRequested: root.settingsBack()

                onWallpapersRequested: root.swapLandscape("wallpapers", "desktop")

                onLockWallpapersRequested: root.swapLandscape("wallpapers", "lock")

                onWallpapersCloseRequested: root.settingsBack()

                onSearchLeft: root.focusLandscape()

                onWallpapersLoaded: landscapeFocus.restart()

                onDesktopEditRequested: {
                    root.close()
                    editDelay.restart()
                }
            }
        }
    }

}
