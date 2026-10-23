import QtQuick
import QtQuick.Layouts
import "../../../modules/common"
import "../../../modules/common/widgets"

// Pure UI (no Quickshell imports): Bar.qml feeds this Hyprland/clock
// data through plain properties and turns its signals into actions.
//
// The outer bar frame is drawn here now instead of stretching
// status_Bar_BG.png with a BorderImage — same three-layer look as
// Pill.qml (navy outline, pale inset ring, white fill) on the same
// flat hard shadow, just without a press state since the bar itself
// never gets clicked. Drawing it means no more 9-slice seams at
// screen widths the export wasn't tiled for. The workspace badges
// stay as your exports/component — those are correct and already
// stretch/animate properly. Active Window, Media, Weather, and Clock
// are rebuilt on Pill.qml instead of the fixed-width raster pills,
// so they actually resize to fit real content (a real window title
// is rarely exactly as wide as "Workspace 1").
Item {
    id: status_Bar

    property var modules: ({})
    property var occupiedWorkspaces: []
    property bool gameMode: false
    readonly property var gameModeModules: ["date", "clock", "weather"]

    function shows(name) {
        if (status_Bar.gameMode)
            return status_Bar.gameModeModules.indexOf(name) >= 0
        return status_Bar.modules[name] !== false
    }

    height: 61
    width: 1926

    property bool vertical: false
    property string barPosition: "top"

    readonly property int crossAlign: status_Bar.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
    readonly property real liftY: status_Bar.vertical ? 0 : -status_Bar.otherWidgetsLift
    readonly property real vGap: status_Bar.capsule ? Theme.capGap - Theme.shadowOffset : 8

    readonly property bool tightV: status_Bar.vertical && content.height < 1120
    readonly property bool tighterV: status_Bar.vertical && content.height < 880

    property bool utilFlyoutAlways: false
    readonly property bool utilFlyout: status_Bar.vertical && (status_Bar.tightV || status_Bar.utilFlyoutAlways)
    property bool utilPopupOpen: false

    property int activeWorkspace: 1
    property int workspaceCount: 5

    function othersHeight(zone) {
        let h = 0
        for (const id of (status_Bar.layout[zone] || [])) {
            if (id === "workspaces" || !status_Bar.shows(id))
                continue
            for (const it of status_Bar.itemsOf(id))
                h += Math.max(it.height, it.implicitHeight) + status_Bar.vGap
        }
        return h
    }

    readonly property real badgesRoom: {
        if (!status_Bar.vertical)
            return -1
        const H = content.height
        const z = status_Bar.zoneMap["workspaces"]
        if (z === "left")
            return H - rightGroup.height - 28 - status_Bar.othersHeight("left")
        if (z === "right")
            return H - leftGroup.height - 28 - status_Bar.othersHeight("right")
        return H - leftGroup.height - rightGroup.height - 28 - status_Bar.othersHeight("center")
    }
    property string clockText: "00:00 AM"
    property string dateText: ""
    property string windowApp: ""
    property string windowTitle: ""
    property string windowIcon: ""

    property bool mediaActive: false
    property bool mediaPlaying: false
    property string mediaTitle: ""
    property string mediaArtist: ""
    property string mediaArtUrl: ""
    property string mediaVisualizerStyle: "none"
    property var mediaPoints: []
    property bool mediaLeftOpensPanel: true
    property bool mediaVolumeAvailable: false

    property bool trayOpen: false

    property bool trayAvailable: true

    property var trayPinned: []

    property var trayMenuItem: null
    property var trayLeavingItem: null
    property bool trayAttention: false
    property bool trayScrollEnabled: true

    readonly property Item trayToggle: pinnedTray.toggleItem

    readonly property Item batteryToggle: batteryIndicator
    readonly property Item resourceToggle: resourceIndicator
    readonly property Item dateToggle: dateIndicator
    readonly property Item weatherToggle: weatherIndicator
    readonly property Item mediaToggle: media
    readonly property Item discordToggle: discordPill
    readonly property Item utilToggle: utilKeys.toggleItem
    readonly property Item utilSource: utilKeys

    property real scaleValue: 1

    // Where every module sits (BarLayoutService.qml, fed by Bar.qml):
    //   { left: [ids], center: [ids], right: [ids] }
    // in the order they run along the bar. Every module is named once; the
    // ids are the ones in BarLayoutService.modules. This is the default bar
    // (the same as BarLayoutService.defaults), until Bar.qml says otherwise.
    property var layout: ({
        left: ["activeWindow", "media", "tray"],
        center: ["status", "weather", "workspaces", "clock", "date"],
        right: ["utilButtons", "resources", "battery", "keyboardLayout", "privacy", "discord", "updates",
                "notifications"]
    })

    readonly property var slotMap: {
        const m = ({})
        for (const z of ["left", "center", "right"]) {
            let i = 0
            for (const id of (status_Bar.layout[z] || [])) {
                m[id] = i++
                if (id === "tray")
                    m["trayButton"] = i++
            }
        }
        return m
    }
    readonly property var zoneMap: {
        const m = ({})
        for (const z of ["left", "center", "right"]) {
            for (const id of (status_Bar.layout[z] || [])) {
                m[id] = z
                if (id === "tray")
                    m["trayButton"] = z
            }
        }
        return m
    }

    function slotOf(key) {
        const v = status_Bar.slotMap[key]
        return v === undefined ? 0 : v
    }

    function zoneItem(key) {
        const z = status_Bar.zoneMap[key]
        return z === "left" ? leftGroup : (z === "center" ? centerGroup : rightGroup)
    }

    readonly property real zoneGap: status_Bar.capsule ? Theme.capGap : 10 - badges.neighborShift

    property int barStyle: 0

    readonly property bool capsule: status_Bar.barStyle === 3
    readonly property bool capsuleBar: status_Bar.capsule
    readonly property bool capsuleVertical: status_Bar.capsule && status_Bar.vertical

    property real cpuPercent: 0
    property real memPercent: 0

    property bool batteryAvailable: false
    property int batteryPercentage: 0
    property bool batteryCharging: false
    property bool batteryLow: false

    property string keyboardLayoutCode: ""

    property string weatherTemperature: "--"
    property string weatherIconName: "cloud"

    property int notificationCount: 0
    property bool notificationsMuted: false

    property bool privacyMic: false
    property bool privacyScreen: false
    property string privacyDetail: ""

    property bool discordInCall: false
    property bool discordNeedsAuth: false
    property bool discordAuthorizing: false
    property string discordChannel: ""
    property var discordParticipants: []
    property bool discordMuted: false
    property bool discordDeafened: false
    property bool discordLeftOpensPanel: true
    property bool discordPanelOpen: false

    property bool statusNetworkShown: false
    property string statusNetworkIcon: "wifi_off"
    property string statusNetworkState: "off"
    property bool statusBluetoothShown: false
    property string statusBluetoothIcon: "bluetooth_disabled"
    property string statusBluetoothState: "off"
    property bool statusSpeakerShown: false
    property string statusSpeakerIcon: "volume_off"
    property string statusSpeakerState: "off"
    property string statusDetail: ""

    property int updatesCount: 0
    property bool updatesNudging: false
    property bool updatesShowZero: false
    property bool updatesBusy: false
    property bool updatesLoading: false
    property string updatesTip: ""

    // How wide the Active Window pill is allowed to grow before it
    // elides. Scales with the bar itself so it stays proportionate on a
    // small monitor, but never past `activeWindowCap` (design pixels): a long
    // window title (a browser tab, a terminal command) used to stretch it to
    // a fifth of the bar. Change the cap here to taste.
    readonly property real activeWindowCap: 260
    readonly property real maxActiveWindowWidth: Math.max(140, Math.min(status_Bar.activeWindowCap, status_Bar.width * 0.14))

    // Where the workspace badges actually sit, worked out from
    // WorkspaceBadges' own geometry: its wrapper is
    // activeSize+shadowOffset (46) tall and spans leftGroup's full
    // height (it's the tallest item there), so its top sits 23px
    // above bar-center. Inside that, the visible badge row is
    // idleSize+shadowOffset (40) tall and anchored bottomMargin (6)
    // up from the wrapper's bottom, landing it 3px above bar-center
    // overall. Active Window, Media, tray, Weather, and Clock are
    // otherwise dead-center by default, so lifting them by this same
    // amount lines them up with the badges. If WorkspaceBadges'
    // bottomMargin changes, update this to match: newOffset =
    // (activeSize + shadowOffset) / 2 - bottomMargin - (idleSize + shadowOffset) / 2.
    readonly property real otherWidgetsLift: status_Bar.capsule ? 0 : 3

    readonly property real mediaCap: 300
    readonly property real maxMediaWidth: {
        const z = status_Bar.zoneMap["media"]
        const half = content.width / 2
        let room
        if (z === "left") {
            room = content.width - rightGroup.width - 12 - status_Bar.othersWidth("left")
            if (centerGroup.width > 0)
                room = Math.min(room, half - centerGroup.width / 2 - 12 - status_Bar.othersWidth("left"))
        } else if (z === "right") {
            room = content.width - leftGroup.width - 12 - status_Bar.othersWidth("right")
            if (centerGroup.width > 0)
                room = Math.min(room, half - centerGroup.width / 2 - 12 - status_Bar.othersWidth("right"))
        } else {
            room = 2 * (Math.min(half - leftGroup.width, half - rightGroup.width) - 12)
                - status_Bar.othersWidth("center")
        }
        return Math.min(status_Bar.mediaCap, Math.max(0, room))
    }

    function itemsOf(id) {
        switch (id) {
        case "workspaces": return [badges]
        case "activeWindow": return [activeWindow]
        case "media": return [mediaSlot]
        case "privacy": return [privacyIndicator]
        case "discord": return [discordPill]
        case "updates": return [updatesBadge]
        case "utilButtons": return [utilKeys]
        case "resources": return [resourceIndicator]
        case "status": return [statusPill]
        case "battery": return [batteryIndicator]
        case "keyboardLayout": return [kbLayoutIndicator]
        case "notifications": return [notificationBell]
        case "tray": return [pinnedTray]
        case "weather": return [weatherIndicator]
        case "date": return [dateIndicator]
        case "clock": return [clockButton]
        }
        return []
    }

    function slotWidth(it) {
        if (it === pinnedTray)
            return pinnedTray.shownWidth
        if (it === privacyIndicator || it === updatesBadge || it === discordPill)
            return it.implicitWidth * it.reveal
        return it.implicitWidth
    }

    function othersWidth(zone) {
        let w = 0
        for (const id of (status_Bar.layout[zone] || [])) {
            if (id === "media")
                continue
            for (const it of status_Bar.itemsOf(id)) {
                if (it.visible)
                    w += status_Bar.slotWidth(it) + status_Bar.zoneGap
            }
        }
        return w
    }

    signal workspaceRequested(int workspace)
    signal mediaToggleRequested()
    signal mediaNextRequested()
    signal mediaPreviousRequested()
    signal mediaPanelRequested()
    signal mediaScrolled(int direction)
    signal trayToggleRequested()
    signal trayItemClicked(var item, int button, Item icon)
    signal trayItemScrolled(var item, real delta, bool horizontal)
    signal resourcesClicked()
    signal batteryClicked()
    signal utilClicked()
    signal statusClicked()
    signal keyboardLayoutClicked()
    signal dateClicked()
    signal weatherClicked()
    signal wallpapersToggleRequested()
    signal notificationsToggleRequested()
    signal updatesClicked()
    signal updatesRefreshRequested()
    signal discordMuteRequested()
    signal discordDeafenRequested()
    signal discordAuthorizeRequested()
    signal discordPanelRequested()

    // How round the bar and its modules are: 0 is square, 1 fully round.
    // Pill.qml reads this off the tree, so every module follows it.
    property real barRoundness: 1

    readonly property color bgRingColor: Theme.surfaceRing
    readonly property real bgRingWidth: Theme.outerRingWidth

    // Corner radius and how far the background reaches past the left and
    // right edges, per style. Both glide between styles instead of
    // snapping. Straight: radius 0, and the background is pushed out by
    // outline + ring (+1 so no seam shows) so the side outline and ring
    // land off screen and only the top and bottom edges are seen.
    property real bgRadius: status_Bar.barStyle === 0
        ? Theme.radiusOuter * status_Bar.barRoundness : 0
    property real bgBleed: status_Bar.barStyle === 1
        ? Theme.borderWidth + status_Bar.bgRingWidth + 1 : 0

    Behavior on bgRadius {
        NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
    }
    Behavior on bgBleed {
        NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
    }

    Item {
        id: bgLayer
        anchors.fill: parent
        opacity: (status_Bar.barStyle === 2 || status_Bar.capsule) ? 0 : 1
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
        }

        Rectangle {
            id: bgShadow
            anchors.fill: parent
            anchors.topMargin: Theme.shadowOffset - (status_Bar.vertical ? status_Bar.bgBleed : 0)
            anchors.bottomMargin: status_Bar.vertical ? -status_Bar.bgBleed : 0
            anchors.leftMargin: status_Bar.vertical ? 0 : -status_Bar.bgBleed
            anchors.rightMargin: status_Bar.vertical ? 0 : -status_Bar.bgBleed
            radius: status_Bar.bgRadius
            color: Theme.lineShadow
        }

        Rectangle {
            id: bgFace
            anchors.fill: parent
            anchors.topMargin: status_Bar.vertical ? -status_Bar.bgBleed : 0
            anchors.bottomMargin: Theme.shadowOffset - (status_Bar.vertical ? status_Bar.bgBleed : 0)
            anchors.leftMargin: status_Bar.vertical ? 0 : -status_Bar.bgBleed
            anchors.rightMargin: status_Bar.vertical ? 0 : -status_Bar.bgBleed
            radius: status_Bar.bgRadius
            color: status_Bar.bgRingColor
            border.width: Theme.borderWidth
            border.color: Theme.line
        }

        Rectangle {
            id: bgFill
            anchors.fill: bgFace
            anchors.margins: Theme.borderWidth + status_Bar.bgRingWidth
            radius: Math.max(0, status_Bar.bgRadius - Theme.borderWidth - status_Bar.bgRingWidth)
            color: Theme.surface
        }
    }

    Item {
        id: capsuleLayer
        anchors.fill: parent
        opacity: status_Bar.capsule ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
        }

        Rectangle {
            x: 0
            y: Theme.capShadowDy
            width: parent.width
            height: parent.height - Theme.capShadowDy
            radius: Math.min(width, height) / 2 * status_Bar.barRoundness
            color: Theme.capShade
            antialiasing: true
        }

        Rectangle {
            id: capFace
            width: parent.width
            height: parent.height - Theme.capShadowDy
            radius: Math.min(width, height) / 2 * status_Bar.barRoundness
            color: Theme.capRim
            antialiasing: true
        }

        Rectangle {
            anchors.fill: capFace
            anchors.margins: Theme.capRimWidth
            radius: Math.min(width, height) / 2 * status_Bar.barRoundness
            color: Theme.capBody
            antialiasing: true
        }
    }

    Item {
        id: content
        anchors.fill: parent
        anchors.leftMargin: status_Bar.vertical ? 0
            : (status_Bar.capsule ? Theme.capRimWidth + Theme.capPadX : Theme.barFloatInset)
        anchors.rightMargin: status_Bar.vertical ? 0
            : (status_Bar.capsule ? Theme.capRimWidth + Theme.capPadX : Theme.barFloatInset)
        anchors.topMargin: status_Bar.vertical
            ? (status_Bar.capsule ? Theme.capRimWidth + Theme.capVPadY : Theme.barFloatInset) : 0
        anchors.bottomMargin: status_Bar.vertical
            ? (status_Bar.capsule ? Theme.capRimWidth + Theme.capVPadY - 1 : Theme.barFloatInset)
            : (status_Bar.capsule ? Theme.capShadowDy : 0)


        GridLayout {
            id: leftGroup
            anchors.left: status_Bar.vertical ? undefined : parent.left
            anchors.top: status_Bar.vertical ? parent.top : undefined
            anchors.verticalCenter: status_Bar.vertical ? undefined : parent.verticalCenter
            anchors.horizontalCenter: status_Bar.vertical ? parent.horizontalCenter : undefined
            columns: status_Bar.vertical ? 1 : 100
            columnSpacing: status_Bar.zoneGap
            rowSpacing: status_Bar.vertical ? status_Bar.vGap : status_Bar.zoneGap
        }

        GridLayout {
            id: centerGroup
            anchors.centerIn: parent
            visible: !status_Bar.vertical
                || content.height > leftGroup.height + rightGroup.height + centerGroup.implicitHeight + 24
            columns: status_Bar.vertical ? 1 : 100
            columnSpacing: status_Bar.zoneGap
            rowSpacing: status_Bar.vertical ? status_Bar.vGap : status_Bar.zoneGap
        }

        GridLayout {
            id: rightGroup
            anchors.right: status_Bar.vertical ? undefined : parent.right
            anchors.bottom: status_Bar.vertical ? parent.bottom : undefined
            anchors.verticalCenter: status_Bar.vertical ? undefined : parent.verticalCenter
            anchors.horizontalCenter: status_Bar.vertical ? parent.horizontalCenter : undefined
            columns: status_Bar.vertical ? 1 : 100
            columnSpacing: status_Bar.zoneGap
            rowSpacing: status_Bar.vertical ? status_Bar.vGap : status_Bar.zoneGap
        }

        WorkspaceBadges {
            id: badges
            parent: status_Bar.zoneItem("workspaces")
            visible: status_Bar.shows("workspaces")
            Layout.row: status_Bar.vertical ? status_Bar.slotOf("workspaces") : 0
            Layout.column: status_Bar.vertical ? 0 : status_Bar.slotOf("workspaces")
            Layout.alignment: status_Bar.crossAlign
            Layout.rightMargin: status_Bar.vertical ? 0 : badges.neighborShift
            vertical: status_Bar.vertical
            roundness: status_Bar.barRoundness
            active: status_Bar.activeWorkspace
            count: status_Bar.workspaceCount
            maxLength: status_Bar.badgesRoom
            onRequested: workspace => status_Bar.workspaceRequested(workspace)
            occupied: status_Bar.occupiedWorkspaces
            ScrollHint {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 2
                anchors.rightMargin: -2
                glyph: "unfold_more"
                active: !status_Bar.capsule
            }
        }

        // Active Window: app name on top (bold), window title under
        // it (lighter) — same two-line treatment and text sizes as
        // the media pill. Ring is 5px like the media pill's rather
        // than the usual 8, since two lines don't fit in the
        // 20px-tall fill an 8px ring leaves.
        Pill {
            id: activeWindow
            parent: status_Bar.zoneItem("activeWindow")
            Layout.row: status_Bar.vertical ? status_Bar.slotOf("activeWindow") : 0
            Layout.column: status_Bar.vertical ? 0 : status_Bar.slotOf("activeWindow")
            // Two lines of text do not fit beside a screen edge: a standing
            // bar shows ActiveWindowKey (just below) instead.
            visible: !status_Bar.vertical && status_Bar.shows("activeWindow")
            Layout.alignment: status_Bar.crossAlign
            cornerRadius: Theme.radiusBadge
            ringWidth: 3

            readonly property bool hasWindow: status_Bar.windowApp !== "" || status_Bar.windowTitle !== ""

            readonly property string line1: !hasWindow
                ? "Workspace " + status_Bar.activeWorkspace
                : (status_Bar.windowApp !== "" ? status_Bar.windowApp : status_Bar.windowTitle)

            // Second line: the title, unless it would just repeat
            // line 1 (terminals often title themselves after the app).
            readonly property string line2: (hasWindow
                && status_Bar.windowApp !== ""
                && status_Bar.windowTitle !== ""
                && status_Bar.windowTitle.toLowerCase() !== status_Bar.windowApp.toLowerCase())
                ? status_Bar.windowTitle : ""

            implicitWidth: Math.min(status_Bar.maxActiveWindowWidth,
                Math.max(status_Bar.capsule ? 80 : 140,
                    Math.max(awLine1.implicitWidth, awLine2.visible ? awLine2.implicitWidth : 0) + (status_Bar.capsule ? 20 : 30)))
            transform: Translate { y: status_Bar.liftY }
            fillGradient: Gradient {
                GradientStop { position: 0.0; color: Theme.accentMint }
                GradientStop { position: 1.0; color: Theme.accentCyan }
            }

            Behavior on implicitWidth {
                NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
            }

            // Each line has a box of its own with a fixed line height. A title
            // with a symbol, emoji or CJK in it (a Discord channel, a browser
            // tab) is drawn with a fallback font whose lines are taller, which
            // used to make that line taller, so the Column grew and the centred
            // block slid up (the app name against the top edge) and the title
            // dropped. With fixed boxes the two lines stay put, whatever the
            // title holds, and a long one is cut with "...".
            Column {
                anchors.centerIn: parent
                width: parent.width - 20
                spacing: 1

                Text {
                    id: awLine1
                    width: parent.width
                    height: lineHeight
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    wrapMode: Text.NoWrap
                    textFormat: Text.PlainText
                    lineHeightMode: Text.FixedHeight
                    lineHeight: Math.round(font.pixelSize * 1.05)
                    text: activeWindow.line1.replace(/\s+/g, " ")
                    color: status_Bar.capsule ? Theme.capInk : Theme.inkOnAccent
                    font.family: Theme.fontFamily
                    font.pixelSize: status_Bar.capsule ? Theme.fontSizeInfo
                        : (activeWindow.hasWindow ? 13 : Theme.fontSizeIdle)
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                }

                Text {
                    id: awLine2
                    width: parent.width
                    height: lineHeight
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    wrapMode: Text.NoWrap
                    textFormat: Text.PlainText
                    lineHeightMode: Text.FixedHeight
                    lineHeight: Math.round(font.pixelSize * 1.05)
                    visible: activeWindow.line2 !== "" && !status_Bar.capsule
                    text: activeWindow.line2.replace(/\s+/g, " ")
                    color: Theme.inkOnAccent
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }
        }

        ActiveWindowKey {
            id: activeWindowKey
            parent: status_Bar.zoneItem("activeWindow")
            Layout.row: status_Bar.vertical ? status_Bar.slotOf("activeWindow") : 0
            Layout.column: status_Bar.vertical ? 0 : status_Bar.slotOf("activeWindow")
            Layout.alignment: status_Bar.crossAlign
            visible: status_Bar.vertical && status_Bar.shows("activeWindow")
            hasWindow: activeWindow.hasWindow
            app: status_Bar.windowApp !== "" ? status_Bar.windowApp : status_Bar.windowTitle
            title: status_Bar.windowApp !== "" ? status_Bar.windowTitle : ""
            icon: status_Bar.windowIcon
            workspace: status_Bar.activeWorkspace
            barPosition: status_Bar.barPosition
        }

        Item {
            id: mediaSlot
            parent: status_Bar.zoneItem("media")
            Layout.row: status_Bar.vertical ? status_Bar.slotOf("media") : 0
            Layout.column: status_Bar.vertical ? 0 : status_Bar.slotOf("media")
            Layout.alignment: status_Bar.crossAlign
            visible: status_Bar.shows("media")
            implicitWidth: media.width
            implicitHeight: media.implicitHeight
            transform: Translate { y: status_Bar.liftY }

            MediaPill {
                id: media
                vertical: status_Bar.vertical
                active: status_Bar.mediaActive
                playing: status_Bar.mediaPlaying
                title: status_Bar.mediaTitle
                artist: status_Bar.mediaArtist
                artUrl: status_Bar.mediaArtUrl
                visualizerStyle: status_Bar.mediaVisualizerStyle
                points: status_Bar.mediaPoints

                maxWidth: status_Bar.maxMediaWidth
                minWidth: Math.min(220, status_Bar.maxMediaWidth)

                leftOpensPanel: status_Bar.mediaLeftOpensPanel
                volumeAvailable: status_Bar.mediaVolumeAvailable
                onToggleRequested: status_Bar.mediaToggleRequested()
                onNextRequested: status_Bar.mediaNextRequested()
                onPreviousRequested: status_Bar.mediaPreviousRequested()
                onPanelRequested: status_Bar.mediaPanelRequested()
                onScrolled: direction => status_Bar.mediaScrolled(direction)
            }
        }

        PrivacyIndicator {
            id: privacyIndicator
            parent: status_Bar.zoneItem("privacy")
            Layout.row: status_Bar.vertical ? status_Bar.slotOf("privacy") : 0
            Layout.column: status_Bar.vertical ? 0 : status_Bar.slotOf("privacy")
            Layout.alignment: status_Bar.crossAlign
            Layout.preferredWidth: status_Bar.vertical ? privacyIndicator.implicitWidth : privacyIndicator.implicitWidth * privacyIndicator.reveal
            Layout.preferredHeight: status_Bar.vertical ? privacyIndicator.implicitHeight * privacyIndicator.reveal : -1
            Layout.leftMargin: status_Bar.vertical ? 0 : -status_Bar.zoneGap * (1 - privacyIndicator.reveal)
            Layout.topMargin: status_Bar.vertical ? -status_Bar.vGap * (1 - privacyIndicator.reveal) : 0
            transform: Translate { y: status_Bar.liftY }
            vertical: status_Bar.vertical
            barPosition: status_Bar.barPosition
            micLive: status_Bar.privacyMic && status_Bar.shows("privacy")
            screenLive: status_Bar.privacyScreen && status_Bar.shows("privacy")
            detailText: status_Bar.privacyDetail
        }

        DiscordPill {
            id: discordPill
            parent: status_Bar.zoneItem("discord")
            Layout.row: status_Bar.vertical ? status_Bar.slotOf("discord") : 0
            Layout.column: status_Bar.vertical ? 0 : status_Bar.slotOf("discord")
            Layout.alignment: status_Bar.crossAlign
            Layout.preferredWidth: status_Bar.vertical ? discordPill.implicitWidth : discordPill.implicitWidth * discordPill.reveal
            Layout.preferredHeight: status_Bar.vertical ? discordPill.implicitHeight * discordPill.reveal : -1
            Layout.leftMargin: status_Bar.vertical ? 0 : -status_Bar.zoneGap * (1 - discordPill.reveal)
            Layout.topMargin: status_Bar.vertical ? -status_Bar.vGap * (1 - discordPill.reveal) : 0
            transform: Translate { y: status_Bar.liftY }
            vertical: status_Bar.vertical
            barPosition: status_Bar.barPosition
            allowed: status_Bar.shows("discord")
            inCall: status_Bar.discordInCall
            needsAuth: status_Bar.discordNeedsAuth
            authorizing: status_Bar.discordAuthorizing
            channelName: status_Bar.discordChannel
            participants: status_Bar.discordParticipants
            muted: status_Bar.discordMuted
            deafened: status_Bar.discordDeafened
            leftOpensPanel: status_Bar.discordLeftOpensPanel
            panelOpen: status_Bar.discordPanelOpen
            onMuteRequested: status_Bar.discordMuteRequested()
            onDeafenRequested: status_Bar.discordDeafenRequested()
            onAuthorizeRequested: status_Bar.discordAuthorizeRequested()
            onPanelRequested: status_Bar.discordPanelRequested()
        }

        UpdatesBadge {
            id: updatesBadge
            parent: status_Bar.zoneItem("updates")
            Layout.row: status_Bar.vertical ? status_Bar.slotOf("updates") : 0
            Layout.column: status_Bar.vertical ? 0 : status_Bar.slotOf("updates")
            Layout.alignment: status_Bar.crossAlign
            Layout.preferredWidth: status_Bar.vertical ? updatesBadge.implicitWidth : updatesBadge.implicitWidth * updatesBadge.reveal
            Layout.preferredHeight: status_Bar.vertical ? updatesBadge.implicitHeight * updatesBadge.reveal : -1
            Layout.leftMargin: status_Bar.vertical ? 0 : -status_Bar.zoneGap * (1 - updatesBadge.reveal)
            Layout.topMargin: status_Bar.vertical ? -status_Bar.vGap * (1 - updatesBadge.reveal) : 0
            transform: Translate { y: status_Bar.liftY }
            barPosition: status_Bar.barPosition
            count: status_Bar.updatesCount
            nudging: status_Bar.updatesNudging
            showZero: status_Bar.updatesShowZero
            busy: status_Bar.updatesBusy
            loading: status_Bar.updatesLoading
            tipText: status_Bar.updatesTip
            allowed: status_Bar.shows("updates")
            onClicked: status_Bar.updatesClicked()
            onRefreshRequested: status_Bar.updatesRefreshRequested()
        }

        UtilButtons {
            id: utilKeys
            parent: status_Bar.zoneItem("utilButtons")
            Layout.row: status_Bar.vertical ? status_Bar.slotOf("utilButtons") : 0
            Layout.column: status_Bar.vertical ? 0 : status_Bar.slotOf("utilButtons")
            visible: status_Bar.shows("utilButtons")
            vertical: status_Bar.vertical
            compact: status_Bar.utilFlyout
            popupOpen: status_Bar.utilPopupOpen
            onToggleRequested: status_Bar.utilClicked()
            Layout.alignment: status_Bar.crossAlign
            onWallpapersRequested: status_Bar.wallpapersToggleRequested()
            transform: Translate { y: status_Bar.liftY }
        }

        ResourceIndicator {
            id: resourceIndicator
            parent: status_Bar.zoneItem("resources")
            Layout.row: status_Bar.vertical ? status_Bar.slotOf("resources") : 0
            Layout.column: status_Bar.vertical ? 0 : status_Bar.slotOf("resources")
            visible: !status_Bar.tighterV && status_Bar.shows("resources")
            vertical: status_Bar.vertical
            Layout.alignment: status_Bar.crossAlign
            transform: Translate { y: status_Bar.liftY }
            cpuPercent: status_Bar.cpuPercent
            memPercent: status_Bar.memPercent
            onClicked: status_Bar.resourcesClicked()
        }

        StatusPill {
            id: statusPill
            parent: status_Bar.zoneItem("status")
            Layout.row: status_Bar.vertical ? status_Bar.slotOf("status") : 0
            Layout.column: status_Bar.vertical ? 0 : status_Bar.slotOf("status")
            Layout.alignment: status_Bar.crossAlign
            transform: Translate { y: status_Bar.liftY }
            vertical: status_Bar.vertical
            barPosition: status_Bar.barPosition
            networkShown: status_Bar.statusNetworkShown && status_Bar.shows("status")
            networkIcon: status_Bar.statusNetworkIcon
            networkState: status_Bar.statusNetworkState
            bluetoothShown: status_Bar.statusBluetoothShown && status_Bar.shows("status")
            bluetoothIcon: status_Bar.statusBluetoothIcon
            bluetoothState: status_Bar.statusBluetoothState
            speakerShown: status_Bar.statusSpeakerShown && status_Bar.shows("status")
            speakerIcon: status_Bar.statusSpeakerIcon
            speakerState: status_Bar.statusSpeakerState
            detailText: status_Bar.statusDetail
            onClicked: status_Bar.statusClicked()
        }

        BatteryIndicator {
            id: batteryIndicator
            parent: status_Bar.zoneItem("battery")
            Layout.row: status_Bar.vertical ? status_Bar.slotOf("battery") : 0
            Layout.column: status_Bar.vertical ? 0 : status_Bar.slotOf("battery")
            visible: available && status_Bar.shows("battery")
            vertical: status_Bar.vertical
            Layout.alignment: status_Bar.crossAlign
            transform: Translate { y: status_Bar.liftY }
            available: status_Bar.batteryAvailable
            percentage: status_Bar.batteryPercentage
            isCharging: status_Bar.batteryCharging
            isLow: status_Bar.batteryLow
            onClicked: status_Bar.batteryClicked()
        }

        KeyboardLayoutIndicator {
            id: kbLayoutIndicator
            parent: status_Bar.zoneItem("keyboardLayout")
            Layout.row: status_Bar.vertical ? status_Bar.slotOf("keyboardLayout") : 0
            Layout.column: status_Bar.vertical ? 0 : status_Bar.slotOf("keyboardLayout")
            visible: layoutCode !== "" && status_Bar.shows("keyboardLayout")
            Layout.alignment: status_Bar.crossAlign
            transform: Translate { y: status_Bar.liftY }
            layoutCode: status_Bar.keyboardLayoutCode
            onClicked: status_Bar.keyboardLayoutClicked()
        }

        NotificationBadge {
            id: notificationBell
            parent: status_Bar.zoneItem("notifications")
            Layout.row: status_Bar.vertical ? status_Bar.slotOf("notifications") : 0
            Layout.column: status_Bar.vertical ? 0 : status_Bar.slotOf("notifications")
            visible: status_Bar.shows("notifications")
            Layout.alignment: status_Bar.crossAlign
            transform: Translate { y: status_Bar.liftY }
            count: status_Bar.notificationCount
            doNotDisturb: status_Bar.notificationsMuted
            onClicked: status_Bar.notificationsToggleRequested()
        }

        TrayCollection {
            id: pinnedTray
            parent: status_Bar.zoneItem("tray")
            Layout.row: status_Bar.vertical ? status_Bar.slotOf("tray") : 0
            Layout.column: status_Bar.vertical ? 0 : status_Bar.slotOf("tray")
            Layout.alignment: status_Bar.crossAlign
            Layout.preferredWidth: status_Bar.vertical ? pinnedTray.fullWidth : pinnedTray.shownWidth
            Layout.preferredHeight: status_Bar.vertical ? pinnedTray.shownHeight : -1
            Layout.leftMargin: status_Bar.vertical ? 0 : -status_Bar.zoneGap * (1 - pinnedTray.reveal)
            Layout.topMargin: status_Bar.vertical ? -status_Bar.vGap * (1 - pinnedTray.reveal) : 0
            transform: Translate { y: status_Bar.liftY }

            compact: true
            vertical: status_Bar.vertical
            showToggle: status_Bar.trayAvailable
            toggleOpen: status_Bar.trayOpen
            toggleAttention: status_Bar.trayAttention
            glyphRotation: !status_Bar.vertical ? 0 : (status_Bar.barPosition === "left" ? -90 : 90)
            texel: status_Bar.scaleValue * Screen.devicePixelRatio
            onToggleRequested: status_Bar.trayToggleRequested()
            present: count > 0 || showToggle
            visible: (present || shownWidth > 0.5 || shownHeight > 0.5) && status_Bar.shows("tray")
            model: status_Bar.trayPinned
            activeItem: status_Bar.trayMenuItem
            leavingItem: status_Bar.trayLeavingItem
            onItemClicked: (item, button, icon) => status_Bar.trayItemClicked(item, button, icon)
            onItemScrolled: (item, delta, horizontal) => status_Bar.trayItemScrolled(item, delta, horizontal)
            scrollEnabled: status_Bar.trayScrollEnabled
        }

        WeatherIndicator {
            id: weatherIndicator
            parent: status_Bar.zoneItem("weather")
            Layout.row: status_Bar.vertical ? status_Bar.slotOf("weather") : 0
            Layout.column: status_Bar.vertical ? 0 : status_Bar.slotOf("weather")
            visible: !status_Bar.tighterV && status_Bar.shows("weather")
            vertical: status_Bar.vertical
            Layout.alignment: status_Bar.crossAlign
            transform: Translate { y: status_Bar.liftY }
            text: status_Bar.weatherTemperature
            iconName: status_Bar.weatherIconName
            onClicked: status_Bar.weatherClicked()
        }

        DateIndicator {
            id: dateIndicator
            parent: status_Bar.zoneItem("date")
            Layout.row: status_Bar.vertical ? status_Bar.slotOf("date") : 0
            Layout.column: status_Bar.vertical ? 0 : status_Bar.slotOf("date")
            visible: status_Bar.shows("date")
            vertical: status_Bar.vertical
            Layout.alignment: status_Bar.crossAlign
            transform: Translate { y: status_Bar.liftY }
            text: status_Bar.dateText
            onClicked: status_Bar.dateClicked()
        }

        Item {
            id: clockButton
            parent: status_Bar.zoneItem("clock")
            Layout.row: status_Bar.vertical ? status_Bar.slotOf("clock") : 0
            Layout.column: status_Bar.vertical ? 0 : status_Bar.slotOf("clock")
            visible: status_Bar.shows("clock")
            Layout.alignment: status_Bar.crossAlign
            implicitWidth: clockPill.implicitWidth
            implicitHeight: clockPill.implicitHeight
            transform: Translate { y: status_Bar.liftY }

            Pill {
                id: clockPill
                anchors.fill: parent
                cornerRadius: Theme.radiusBadge
                fillColor: Theme.chipFill
                ringWidth: 6
                implicitWidth: status_Bar.vertical ? clockPill.barVWidth : cLabel.implicitWidth + (status_Bar.capsule ? 20 : 28)
                implicitHeight: status_Bar.vertical ? clockColumn.implicitHeight + (clockPill.capsule ? 16 : 24) : Theme.pillHeight + Theme.shadowOffset

                Column {
                    id: clockColumn
                    visible: status_Bar.vertical
                    anchors.centerIn: parent

                    Repeater {
                        model: status_Bar.clockText.split(" ")
                        Text {
                            required property string modelData
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData
                            color: Theme.chipInk
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeInfo
                            font.weight: Font.ExtraBold
                            font.styleName: Theme.fontStyleBold
                        }
                    }
                }

                Text {
                    id: cLabel
                    visible: !status_Bar.vertical
                    anchors.centerIn: parent
                    text: status_Bar.clockText
                    color: Theme.chipInk
                    font.family: Theme.fontFamily
                    font.pixelSize: status_Bar.capsule ? Theme.capClockSize : Theme.fontSizeInfo
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                }
            }
        }
    }
}
