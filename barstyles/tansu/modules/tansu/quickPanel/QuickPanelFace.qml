import QtQuick
import QtQuick.Effects
import "../../common/functions/QuickTiles.js" as QT
import "../../../modules/common"
import "../../../modules/common/widgets"
import "../../../modules/tansu/phone"

// The Quick Panel's screen: everything that sits inside the phone, drawn
// natively from the Figma frame "Quick Panel Placeholder 2D" (654x1214,
// coordinates are that frame's). PhoneBody.qml supplies the bezel, notch
// and the 2.5D pose; this is the part you tap.
//
// Pure UI (no Quickshell imports): QuickPanel.qml feeds it data through
// plain properties (from QuickSource.qml) and turns its signals into
// actions.
//
// The banner and avatar: click one to pick a picture for it (right-click to
// reset). With no image set they
// show the "empty" look from the Figma template (grey with an account
// icon). Point bannerSource / avatarSource at any image and it's cropped
// to fit.
//
// The list under the "Notifications" tag shows what it's given in
// `notifications` (see NotificationSource.qml): swipe one left or right
// (or tap it) to dismiss it,
// hover the tag and tap it to clear them all. With nothing to show it's
// the grey empty template from Figma.
//
// The heads-up card: when a notification arrives, QuickPanel.qml hands it
// in through `alertEntry` / `alertShown` and it drops in at the top of the
// screen, over the banner and just under the clock row — the phone's own
// "new notification" (there's no separate popup any more). Click it to keep
// the phone up, right-click to dismiss that notification for good.
//
// Right-clicking the Network or Bluetooth tile drops NetworkDialog.qml
// / BluetoothDialog.qml down over the rest of the screen — a Wi-Fi
// network picker and a paired-device list, respectively. Right-clicking
// either volume slider does the same with VolumeMixerDialog.qml, for a
// compact default-device dropdown plus a per-app volume mixer instead.
Item {
    id: face

    readonly property bool classicPanel: true

    // Texels per design unit at the size the phone ends up on screen —
    // the same number as PhoneBody.renderScale, fed by QuickPanel.qml.
    // The banner / avatar masks below are layers of their own, and a
    // layer is drawn at its item's design size unless told otherwise, so
    // without this their round edges were made at 1x and then stretched
    // (or squeezed) to whatever size the phone is at, which is what went
    // soft when the scale changed.
    property real renderScale: 1

    width: 654
    height: 1214

    property string clockText: "00:00AM"
    property string dateText: "Sun, 20  Sep"
    property real downloadBps: 0
    property real uploadBps: 0
    property string userName: "user"
    property string hostName: "host"
    property url bannerSource: ""
    property url avatarSource: ""

    property string networkKind: "wifi"
    property bool networkOn: false
    property string networkDetail: "OFF"

    property bool bluetoothOn: false
    property bool bluetoothConnected: false
    property string bluetoothDetail: "OFF"

    property bool microphoneOn: false
    property bool speakerOn: false
    property real microphoneVolume: 0
    property real speakerVolume: 0
    property real brightness: 100
    property real gamma: 100
    property bool keepAwakeOn: false
    property bool notificationsOn: true
    property bool mediaOn: true
    property bool mediaPresent: false
    property bool mediaPlaying: false
    property string mediaTitle: ""
    property string mediaArtist: ""
    property url mediaArt: ""
    property bool editing: false
    // Night Light / Game Mode, read back from Hyprland by QuickSource.qml.
    property bool nightLightOn: false
    property bool gameModeOn: false
    property bool darkModeOn: false
    property string darkModeName: "light"
    property bool easyEffectsOn: false
    property bool warpOn: false
    property bool warpConnecting: false
    property bool warpInstalled: true
    property bool keyboardOn: false
    property string powerProfileName: "balanced"
    property bool musicListening: false
    property bool antiFlashbangOn: false
    property int antiFlashbangLevel: 0
    property bool nightLightDialogOpen: false
    property int nightLightTemperature: 4500
    property bool nightLightAuto: false
    property int nightLightAutoFrom: 20
    property int nightLightAutoTo: 6
    property var tiles: QT.defaultTiles
    property int tileColumns: QT.defaultColumns

    property bool networkDialogOpen: false
    property bool bluetoothDialogOpen: false
    property var wifiNetworks: []
    property bool wifiScanning: false
    property bool wifiManualScanning: false
    property string wifiConnectingSsid: ""
    property string wifiConnectError: ""
    property var bluetoothDevices: []
    property bool bluetoothScanning: false
    property bool bluetoothManualScanning: false
    property string bluetoothConnectingAddress: ""
    property string bluetoothConnectError: ""

    signal wifiScanRequested()
    signal wifiAdvancedRequested()
    signal wifiConnectRequested(string ssid, string password)
    signal wifiDisconnectRequested(string ssid)
    signal bluetoothScanRequested()
    signal bluetoothAdvancedRequested()
    signal bluetoothConnectRequested(string address)
    signal bluetoothDisconnectRequested(string address)
    signal mediaToggleRequested()
    signal mediaPreviousRequested()
    signal mediaNextRequested()
    signal lyricsRequested()

    property string audioDialogKind: ""

    // `audioDialogKind` clears to "" the instant the dialog is asked to
    // close, but the dialog itself (VolumeMixerDialog.qml) then spends
    // 220ms fading out rather than vanishing immediately. Everything
    // that picks the dialog's title/devices/streams below used to
    // branch on `audioDialogKind` directly, which meant the moment you
    // closed, say, the Microphone mixer, every one of those ternaries
    // fell through to its speaker branch (the "else") for that whole
    // 220ms — the dialog visibly swapped to the Speaker mixer's content
    // while it was still fading out. This instead remembers whichever
    // kind was last actually open, and that's what picks the dialog's
    // content, so closing one never flashes the other on its way out.
    // It doesn't need resetting back to "" on close: the moment the
    // dialog opens again, a fresh non-empty kind arrives right away
    // (see the two onRightClicked handlers below) and overwrites it
    // before anything reads it.
    property string _audioDialogShownKind: ""
    Connections {
        target: face
        function onAudioDialogKindChanged() {
            if (face.audioDialogKind !== "")
                face._audioDialogShownKind = face.audioDialogKind
        }
    }
    readonly property string audioDialogShownKind: audioDialogKind !== "" ? audioDialogKind : _audioDialogShownKind

    property var speakerDevices: []
    property var microphoneDevices: []
    property var speakerStreams: []
    property var microphoneStreams: []
    property bool audioDevicesScanning: false
    property bool audioDevicesManualScanning: false
    property string audioDeviceSelectingId: ""

    signal audioDeviceScanRequested()
    signal speakerDeviceSelected(string id)
    signal microphoneDeviceSelected(string id)
    signal speakerStreamVolumeChanged(string id, real value)
    signal speakerStreamMuteToggled(string id, bool muted)
    signal microphoneStreamVolumeChanged(string id, real value)
    signal microphoneStreamMuteToggled(string id, bool muted)
    signal speakerStreamDragStarted(string id)
    signal speakerStreamDragEnded(string id)
    signal microphoneStreamDragStarted(string id)
    signal microphoneStreamDragEnded(string id)

    property bool powerMenuOpen: false

    property var notifications: []

    property var alertEntry: null
    property bool alertShown: false

    // The y (in this file's 654x1214 coordinates) where the bottom of the
    // monitor cuts the phone off — only part of it shows (QuickPanel's
    // `peek`). QuickPanel.qml works it out and passes it in. Because the
    // phone is tilted the cutoff is slanted on the face: lower at the
    // left edge, higher at the right. The notification list runs down to
    // the lower (left) one — whatever hangs past the monitor at the
    // right is simply not drawn — so it fills the screen right to the
    // edge, and scrolls once there are more cards than fit. Left at the
    // full height it behaves as before (the list fills its card).
    property real visibleBottomLeft: 1214
    property real visibleBottomRight: 1214
    property real visibleExtra: 0

    property real listBottomPad: Theme.quickFlat ? 46 : 40

    property double nowMs: Date.now()

    signal networkToggled()
    signal bluetoothToggled()
    signal microphoneToggled()
    signal speakerToggled()
    signal microphoneVolumeMoved(real value)
    signal speakerVolumeMoved(real value)
    signal brightnessMoved(real value)
    signal gammaMoved(real value)
    signal keepAwakeToggled()
    signal notificationsToggled()
    signal editToggled()
    signal nightLightToggled()
    signal nightLightTemperatureMoved(int kelvin)
    signal nightLightAutoRequested(bool on)
    signal nightLightScheduleRequested(int from, int to)
    signal gameModeToggled()
    signal darkModeToggled()
    signal easyEffectsToggled()
    signal warpToggled()
    signal keyboardToggled()
    signal powerProfileCycled()
    signal musicRecognitionToggled()
    signal antiFlashbangToggled()
    signal tileActionRequested(string id)
    signal tileMoveRequested(int from, int to)
    signal tileResizeRequested(int index)
    signal tileRemoveRequested(int index)
    signal tileAddRequested(string id)
    signal tileColumnsRequested(int columns)
    // The Refresh button in the header row (next to Edit / Power):
    // QuickPanel.qml reloads Hyprland's config, then this shell.
    signal refreshRequested()
    signal settingsRequested()
    signal notificationDismissed(var key)
    signal notificationActivated(var key)
    signal notificationsDismissed(var keys)
    signal notificationsCleared()
    signal alertActivated()
    signal alertDismissRequested(var key)
    signal alertClicked(var key)
    signal panelCloseRequested()

    signal bannerPickRequested()
    signal avatarPickRequested()
    signal bannerResetRequested()
    signal avatarResetRequested()

    readonly property color placeholderGrey: Theme.pSurfaceHover

    property bool bannerDarkLeft: false
    property bool bannerDarkRight: false
    readonly property bool bannerHasImage: bannerImage.status === Image.Ready
    readonly property color bannerInkLeft: bannerHasImage
        ? (bannerDarkLeft ? "#ffffff" : Theme.colBorder) : Theme.pInk
    readonly property color bannerInkRight: bannerHasImage
        ? (bannerDarkRight ? "#ffffff" : Theme.colBorder) : Theme.pInk

    Item {
        id: banner
        x: 26
        y: 26
        width: 602
        height: 240

        Rectangle {
            anchors.fill: parent
            color: face.placeholderGrey
            topLeftRadius: 74
            topRightRadius: 74
            bottomLeftRadius: 50
            bottomRightRadius: 50
            visible: bannerImage.status !== Image.Ready
        }

        Image {
            id: bannerImage
            anchors.fill: parent
            source: face.bannerSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            // This Image lives for the whole session (QuickPanel is
            // created once in shell.qml and never torn down), so an
            // unbounded decode of whatever photo was picked stays
            // resident the entire time. Cap it to the 602x240 banner
            // slot at 2x for hidpi.
            sourceSize: Qt.size(1204, 480)
            visible: false
        }

        // Measures the banner's brightness under the clock/date and under the
        // speed readout. Invisible (opacity 0, never shown), 60x24 = the
        // banner at 1/10 size, so a paint costs next to nothing and only
        // happens when the picture changes.
        Canvas {
            id: bannerSampler
            width: 60
            height: 24
            opacity: 0
            renderTarget: Canvas.Image
            renderStrategy: Canvas.Immediate

            readonly property url src: bannerImage.status === Image.Ready ? bannerImage.source : ""

            onSrcChanged: {
                if (src.toString() !== "")
                    loadImage(src)
            }
            onImageLoaded: requestPaint()

            function brightness(ctx, x, y, w, h) {
                const d = ctx.getImageData(x, y, w, h).data
                let sum = 0
                let n = 0
                for (let i = 0; i < d.length; i += 4) {
                    if (d[i + 3] === 0)
                        continue
                    const r = Math.pow(d[i] / 255, 2.2)
                    const g = Math.pow(d[i + 1] / 255, 2.2)
                    const b = Math.pow(d[i + 2] / 255, 2.2)
                    sum += 0.2126 * r + 0.7152 * g + 0.0722 * b
                    n++
                }
                return n > 0 ? sum / n : 1
            }

            onPaint: {
                if (src.toString() === "" || !isImageLoaded(src))
                    return
                const iw = bannerImage.implicitWidth
                const ih = bannerImage.implicitHeight
                if (iw <= 0 || ih <= 0)
                    return

                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)

                let dw = width
                let dh = width * ih / iw
                if (dh < height) {
                    dh = height
                    dw = height * iw / ih
                }
                ctx.drawImage(src, (width - dw) / 2, (height - dh) / 2, dw, dh)

                face.bannerDarkLeft = brightness(ctx, 4, 1, 15, 5) < 0.30
                face.bannerDarkRight = brightness(ctx, 41, 1, 15, 5) < 0.30
            }
        }

        Item {
            id: bannerMask
            anchors.fill: parent
            visible: false
            layer.enabled: true
            layer.smooth: true
            layer.textureSize: Qt.size(Math.ceil(width * face.renderScale * 2),
                                       Math.ceil(height * face.renderScale * 2))

            Rectangle {
                anchors.fill: parent
                color: "black"
                topLeftRadius: 74
                topRightRadius: 74
                bottomLeftRadius: 50
                bottomRightRadius: 50
            }
        }

        MultiEffect {
            anchors.fill: parent
            source: bannerImage
            maskEnabled: true
            maskSource: bannerMask
            visible: bannerImage.status === Image.Ready
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.pLine
            opacity: bannerArea.containsMouse ? 0.14 : 0
            topLeftRadius: 74
            topRightRadius: 74
            bottomLeftRadius: 50
            bottomRightRadius: 50

            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                }
            }
        }

        MaterialIcon {
            name: "stylus"
            size: 32
            anchors.centerIn: parent
            opacity: bannerArea.containsMouse ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                }
            }
        }

        MouseArea {
            id: bannerArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                face.bannerPickRequested()
                face.panelCloseRequested()
            }
        }

        Rectangle {
            id: bannerRemove
            visible: bannerImage.status === Image.Ready
                && (bannerArea.containsMouse || bannerRemoveArea.containsMouse)
            x: banner.width - width - 24
            y: 84
            width: 32
            height: 32
            radius: width / 2
            color: Theme.pLine
            opacity: bannerRemoveArea.containsMouse ? 1 : 0.8
            antialiasing: true

            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                }
            }

            MaterialIcon {
                name: "close"
                size: 18
                fill: 1
                color: "white"
                anchors.centerIn: parent
            }

            MouseArea {
                id: bannerRemoveArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: face.bannerResetRequested()
            }
        }
    }

    Column {
        x: 67
        y: 36
        spacing: -7

        Text {
            text: face.clockText
            color: face.bannerInkLeft
            font.family: Theme.fontFamily
            font.pixelSize: 24
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }

        Text {
            text: face.dateText
            color: face.bannerInkLeft
            font.family: Theme.fontFamily
            font.pixelSize: 20
        }
    }

    function formatRate(bps) {
        if (bps >= 1048576)
            return (bps / 1048576).toFixed(1) + " MB/s"
        if (bps >= 1024)
            return Math.round(bps / 1024) + " KB/s"
        return Math.round(bps) + " B/s"
    }

    Column {
        id: speedBlock
        x: 654 - 67 - width
        y: 38
        width: 150
        spacing: -2

        Item {
            width: speedBlock.width
            height: downText.implicitHeight

            MaterialIcon {
                id: downIcon
                name: "arrow_downward"
                size: 20
                weight: 600
                color: face.bannerInkRight
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                id: downText
                anchors.right: downIcon.left
                anchors.rightMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                text: face.formatRate(face.downloadBps)
                color: face.bannerInkRight
                font.family: Theme.fontFamily
                font.pixelSize: 20
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }
        }

        Item {
            width: speedBlock.width
            height: upText.implicitHeight

            MaterialIcon {
                id: upIcon
                name: "arrow_upward"
                size: 20
                weight: 600
                color: face.bannerInkRight
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                id: upText
                anchors.right: upIcon.left
                anchors.rightMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                text: face.formatRate(face.uploadBps)
                color: face.bannerInkRight
                font.family: Theme.fontFamily
                font.pixelSize: 20
            }
        }
    }

    Item {
        id: avatar
        x: 67
        y: 208
        width: 120
        height: 120

        readonly property real imgInset: 2

        Rectangle {
            anchors.fill: parent
            anchors.margins: avatar.imgInset
            radius: width / 2
            color: face.placeholderGrey
            visible: avatarImage.status !== Image.Ready
            antialiasing: true
        }

        MaterialIcon {
            name: "account_circle"
            size: 24
            anchors.centerIn: parent
            visible: avatarImage.status !== Image.Ready && !avatarArea.containsMouse
        }

        Image {
            id: avatarImage
            anchors.fill: parent
            anchors.margins: avatar.imgInset
            source: face.avatarSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize: Qt.size(240, 240)
            visible: false
        }

        Item {
            id: avatarMask
            anchors.fill: parent
            anchors.margins: avatar.imgInset
            visible: false
            layer.enabled: true
            layer.smooth: true
            layer.textureSize: Qt.size(Math.ceil(width * face.renderScale * 2),
                                       Math.ceil(height * face.renderScale * 2))

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "black"
                antialiasing: true
            }
        }

        MultiEffect {
            anchors.fill: parent
            anchors.margins: avatar.imgInset
            source: avatarImage
            maskEnabled: true
            maskSource: avatarMask
            visible: avatarImage.status === Image.Ready
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: avatar.imgInset
            radius: width / 2
            color: Theme.pLine
            opacity: avatarArea.containsMouse ? 0.14 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                }
            }
            antialiasing: true
        }

        MaterialIcon {
            name: "stylus"
            size: 28
            anchors.centerIn: parent
            opacity: avatarArea.containsMouse ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: 3
            border.color: Theme.pRingWhite
            antialiasing: true
        }

        MouseArea {
            id: avatarArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                face.avatarPickRequested()
                face.panelCloseRequested()
            }
        }

        Rectangle {
            id: avatarRemove
            visible: avatarImage.status === Image.Ready
                && (avatarArea.containsMouse || avatarRemoveArea.containsMouse)
            x: avatar.width - width - 2
            y: avatar.height - height - 2
            width: 28
            height: 28
            radius: width / 2
            color: Theme.pLine
            opacity: avatarRemoveArea.containsMouse ? 1 : 0.8
            antialiasing: true

            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                }
            }

            MaterialIcon {
                name: "close"
                size: 16
                fill: 1
                color: "white"
                anchors.centerIn: parent
            }

            MouseArea {
                id: avatarRemoveArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: face.avatarResetRequested()
            }
        }
    }

    Text {
        x: 67
        y: 331
        width: 254
        elide: Text.ElideRight
        text: face.userName + "@" + face.hostName
        color: Theme.pInk
        font.family: Theme.fontFamily
        font.pixelSize: 20
    }

    readonly property real headerX: 329
    readonly property real headerPitch: 89

    function togglePowerMenu() {
        if (face.powerMenuOpen) {
            face.powerMenuOpen = false
        } else {
            face.powerMenuOpen = true
            face.networkDialogOpen = false
            face.bluetoothDialogOpen = false
            face.nightLightDialogOpen = false
            face.audioDialogKind = ""
        }
    }

    QuickToggle {
        flatShadow: Theme.quickFlat
        kind: "square"
        x: face.headerX
        y: 276
        hoverLights: true
        icon: "settings"
        onClicked: face.settingsRequested()
    }

    QuickToggle {
        flatShadow: Theme.quickFlat
        kind: "square"
        x: face.headerX + face.headerPitch
        y: 276
        hoverLights: true
        icon: "refresh"
        onClicked: face.refreshRequested()
    }

    QuickToggle {
        flatShadow: Theme.quickFlat
        kind: "square"
        x: face.headerX + face.headerPitch * 2
        y: 276
        hoverLights: true
        on: face.editing
        icon: "stylus"
        onClicked: face.editToggled()
    }

    readonly property var tileLayout: QT.pack(face.tiles, face.tileColumns, Theme.quickFlat)
    property real tileExtra: tileLayout.height - QT.baseGridHeight
    Behavior on tileExtra {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    property int dropIndex: -1

    readonly property var unplacedTiles: QT.catalog.filter(id => !face.tiles.some(t => t.id === id))
    readonly property bool canAdd: QT.fits(face.tiles.concat([{ id: "_", size: "small" }]), face.tileColumns)

    function canResize(index) {
        if (index < 0 || index >= face.tiles.length)
            return false
        return QT.nextSize(face.tiles, index, face.tileColumns) !== face.tiles[index].size
    }

    function resizeGrows(index) {
        if (index < 0 || index >= face.tiles.length)
            return true
        const next = QT.nextSize(face.tiles, index, face.tileColumns)
        return QT.unitsOf(next) > QT.unitsOf(face.tiles[index].size)
    }

    function canColumns(columns) {
        return QT.fits(face.tiles, columns)
    }

    function tileSlotNear(px, py) {
        const slots = face.tileLayout.slots
        let best = -1
        let bestD = 1e12
        for (let i = 0; i < slots.length; i++) {
            const cx = 67 + slots[i].x + slots[i].w / 2
            const cy = 373 + slots[i].y + slots[i].rowH / 2
            const d = (px - cx) * (px - cx) + (py - cy) * (py - cy)
            if (d < bestD) {
                bestD = d
                best = i
            }
        }
        return best
    }

    function tileName(id) {
        switch (id) {
        case "network": return face.networkKind === "ethernet" ? "Ethernet" : "Wi-Fi"
        case "bluetooth": return "Bluetooth"
        case "keepAwake": return "Keep Awake"
        case "microphone": return "Microphone"
        case "speaker": return "Speaker"
        case "notifications": return "Alerts"
        case "nightLight": return "Night Light"
        case "gameMode": return "Game Mode"
        case "darkMode": return "Dark Mode"
        case "easyEffects": return "Easy Effects"
        case "warp": return "Cloudflare WARP"
        case "screenSnip": return "Screen Snip"
        case "colorPicker": return "Color Picker"
        case "keyboard": return "On-Screen Keyboard"
        case "powerProfile": return "Power Profile"
        case "musicRecognition": return "Music Recognition"
        case "antiFlashbang": return "Anti-Flashbang"
        }
        return ""
    }

    function tileOn(id) {
        switch (id) {
        case "network": return face.networkOn
        case "bluetooth": return face.bluetoothOn
        case "keepAwake": return face.keepAwakeOn
        case "microphone": return face.microphoneOn
        case "speaker": return face.speakerOn
        case "notifications": return face.notificationsOn
        case "nightLight": return face.nightLightOn
        case "gameMode": return face.gameModeOn
        case "darkMode": return face.darkModeOn
        case "easyEffects": return face.easyEffectsOn
        case "warp": return face.warpOn || face.warpConnecting
        case "keyboard": return face.keyboardOn
        case "powerProfile": return face.powerProfileName === "performance"
        case "musicRecognition": return face.musicListening
        case "antiFlashbang": return face.antiFlashbangOn
        }
        return false
    }

    function tileSubtitle(id) {
        switch (id) {
        case "network": return face.networkDetail
        case "bluetooth": return face.bluetoothDetail
        case "keepAwake": return face.keepAwakeOn ? "ON" : "OFF"
        case "microphone": return face.microphoneOn ? "ON" : "Muted"
        case "speaker": return face.speakerOn ? "ON" : "Muted"
        case "notifications": return face.notificationsOn ? "ON" : "Muted"
        case "nightLight": return face.nightLightOn ? face.nightLightTemperature + "K"
                                                    : (face.nightLightAuto ? "AUTO" : "OFF")
        case "gameMode": return face.gameModeOn ? "ON" : "OFF"
        case "darkMode": return face.darkModeName === "light" ? "Light" : (face.darkModeName === "darker" ? "Darker" : "Dark")
        case "easyEffects": return face.easyEffectsOn ? "ON" : "OFF"
        case "warp": return !face.warpInstalled ? "Not installed"
                              : (face.warpConnecting ? "Connecting…" : (face.warpOn ? "ON" : "OFF"))
        case "screenSnip": return "Tap"
        case "colorPicker": return "Tap"
        case "keyboard": return face.keyboardOn ? "ON" : "OFF"
        case "powerProfile": return face.powerProfileName === "saver" ? "Saver" : (face.powerProfileName === "performance" ? "Performance" : "Balanced")
        case "musicRecognition": return face.musicListening ? "Listening…" : "Tap"
        case "antiFlashbang": return face.antiFlashbangLevel === 1 ? "Weak" : (face.antiFlashbangLevel === 2 ? "Strong" : "OFF")
        }
        return ""
    }

    function tileIcon(id) {
        switch (id) {
        case "network":
            return face.networkKind === "ethernet" ? "settings_ethernet"
                                                   : (face.networkOn ? "wifi" : "wifi_off")
        case "bluetooth": return !face.bluetoothOn ? "bluetooth_disabled"
                                                   : (face.bluetoothConnected ? "bluetooth_connected" : "bluetooth")
        case "keepAwake": return "emoji_food_beverage"
        case "microphone": return face.microphoneOn ? "mic" : "mic_off"
        case "speaker": return face.speakerOn ? "volume_up" : "volume_off"
        case "notifications": return face.notificationsOn ? "notifications_active" : "notifications_off"
        case "nightLight": return "bedtime"
        case "gameMode": return "gamepad"
        case "darkMode": return face.darkModeName === "light" ? "light_mode" : (face.darkModeName === "darker" ? "bedtime" : "dark_mode")
        case "easyEffects": return "graphic_eq"
        case "warp": return "vpn_lock"
        case "screenSnip": return "screenshot_region"
        case "colorPicker": return "colorize"
        case "keyboard": return "keyboard"
        case "powerProfile": return face.powerProfileName === "saver" ? "energy_savings_leaf" : (face.powerProfileName === "performance" ? "speed" : "balance")
        case "musicRecognition": return "music_cast"
        case "antiFlashbang": return "flash_off"
        }
        return ""
    }

    function tileFilled(id) {
        return (id === "nightLight" || id === "gameMode"
                || id === "easyEffects" || id === "warp" || id === "keyboard"
                || id === "musicRecognition" || id === "antiFlashbang") && face.tileOn(id)
    }

    function tileClicked(id) {
        switch (id) {
        case "network": face.networkToggled(); break
        case "bluetooth": face.bluetoothToggled(); break
        case "keepAwake": face.keepAwakeToggled(); break
        case "microphone": face.microphoneToggled(); break
        case "speaker": face.speakerToggled(); break
        case "notifications": face.notificationsToggled(); break
        case "nightLight": face.nightLightToggled(); break
        case "gameMode": face.gameModeToggled(); break
        case "darkMode": face.darkModeToggled(); break
        case "easyEffects": face.easyEffectsToggled(); break
        case "warp": face.warpToggled(); break
        case "keyboard": face.keyboardToggled(); break
        case "powerProfile": face.powerProfileCycled(); break
        case "musicRecognition": face.musicRecognitionToggled(); break
        case "antiFlashbang": face.antiFlashbangToggled(); break
        case "screenSnip":
        case "colorPicker":
            face.panelCloseRequested()
            face.tileActionRequested(id)
            break
        }
    }

    function closeDialogs() {
        face.networkDialogOpen = false
        face.bluetoothDialogOpen = false
        face.nightLightDialogOpen = false
        face.powerMenuOpen = false
        face.audioDialogKind = ""
    }

    function tileRightClicked(id) {
        if (id === "network" && face.networkKind !== "ethernet") {
            face.closeDialogs()
            face.networkDialogOpen = true
        } else if (id === "bluetooth") {
            face.closeDialogs()
            face.bluetoothDialogOpen = true
        } else if (id === "nightLight") {
            face.closeDialogs()
            face.nightLightDialogOpen = true
        } else if (id === "microphone" || id === "speaker") {
            face.closeDialogs()
            face.audioDialogKind = id
        }
    }

    Rectangle {
        x: 40
        y: 362
        width: 575
        height: 275 + face.tileExtra
        radius: 40
        color: face.placeholderGrey
        antialiasing: true
    }

    Repeater {
        model: QT.catalog

        delegate: Item {
            id: tile

            required property string modelData

            readonly property int pos: {
                const t = face.tiles
                for (let i = 0; i < t.length; i++) {
                    if (t[i].id === tile.modelData)
                        return i
                }
                return -1
            }
            readonly property bool placed: pos >= 0
            readonly property var slot: pos >= 0 ? face.tileLayout.slots[pos] : undefined

            property string sizeName: "small"
            readonly property bool big: sizeName !== "small"
            property real slotW: 74
            property real slotX: 67
            property real slotY: 373

            Binding {
                target: tile
                property: "sizeName"
                value: tile.placed ? face.tiles[tile.pos].size : "small"
                when: tile.placed
            }
            Binding {
                target: tile
                property: "slotW"
                value: tile.slot ? tile.slot.w : 74
                when: tile.placed && tile.slot !== undefined
            }
            Binding {
                target: tile
                property: "slotX"
                value: 67 + (tile.slot ? tile.slot.x : 0)
                when: tile.placed && tile.slot !== undefined
            }
            Binding {
                target: tile
                property: "slotY"
                value: 373 + (tile.slot ? tile.slot.y + tile.slot.oy : 0)
                when: tile.placed && tile.slot !== undefined
            }

            property bool dragging: false
            property real dragX: 0
            property real dragY: 0

            x: dragging ? dragX : slotX
            y: dragging ? dragY : slotY
            z: dragging ? 20 : 0
            readonly property bool sliderMode: QT.isSlider(modelData) && big
            width: sliderMode ? slider.implicitWidth + 5 : toggle.implicitWidth
            height: sliderMode ? slider.implicitHeight : toggle.implicitHeight

            opacity: placed ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                }
            }
            Behavior on slotW {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on x {
                enabled: !tile.dragging
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on y {
                enabled: !tile.dragging
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            VolumeSlider {
                id: slider
                flatShadow: Theme.quickFlat
                visible: tile.sliderMode
                sliderWidth: tile.slotW
                enabled: !face.editing
                label: face.tileName(tile.modelData)
                icon: face.tileIcon(tile.modelData)
                muted: !face.tileOn(tile.modelData)
                value: tile.modelData === "microphone" ? face.microphoneVolume : face.speakerVolume
                onIconClicked: face.tileClicked(tile.modelData)
                onMoved: value => {
                    if (tile.modelData === "microphone")
                        face.microphoneVolumeMoved(value)
                    else
                        face.speakerVolumeMoved(value)
                }
                onRightClicked: face.tileRightClicked(tile.modelData)
            }

            QuickToggle {
                flatShadow: Theme.quickFlat
                id: toggle
                visible: !tile.sliderMode
                // Wide (icon + name + status, e.g. the Wi-Fi network or the
                // connected Bluetooth device) for the 2- and 3-column sizes,
                // and also for a small button whose row got stretched in
                // 2-column mode: it would otherwise be a wide, empty
                // icon-only pill with the name and active device hidden.
                kind: (tile.big || (face.tileColumns <= 2 && tile.slotW >= 140)) ? "wide" : "round"
                wideWidth: tile.slotW
                roundWidth: tile.slotW
                enabled: !face.editing
                on: face.tileOn(tile.modelData)
                label: face.tileName(tile.modelData)
                subtitle: face.tileSubtitle(tile.modelData)
                icon: face.tileIcon(tile.modelData)
                iconFilled: face.tileFilled(tile.modelData)
                onClicked: face.tileClicked(tile.modelData)
                onRightClicked: face.tileRightClicked(tile.modelData)
            }

            // Edit mode: press and drag to move. A press that never moves
            // does nothing (removing / resizing are the badges below, so
            // a stray tap can't delete a button). Letting go over another
            // slot asks for the move; the button then slides there.
            MouseArea {
                id: editArea
                anchors.fill: parent
                visible: face.editing && tile.placed
                enabled: visible
                hoverEnabled: true
                cursorShape: tile.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                property real grabX: 0
                property real grabY: 0

                function endDrag() {
                    if (!tile.dragging)
                        return
                    tile.dragging = false
                    const to = face.dropIndex
                    face.dropIndex = -1
                    if (to >= 0 && to !== tile.pos)
                        face.tileMoveRequested(tile.pos, to)
                }

                onPressed: mouse => {
                    grabX = mouse.x
                    grabY = mouse.y
                }
                onPositionChanged: mouse => {
                    if (!pressed)
                        return
                    if (!tile.dragging && Math.abs(mouse.x - grabX) + Math.abs(mouse.y - grabY) < 8)
                        return
                    const p = mapToItem(face, mouse.x, mouse.y)
                    tile.dragging = true
                    tile.dragX = p.x - grabX
                    tile.dragY = p.y - grabY
                    face.dropIndex = face.tileSlotNear(p.x, p.y)
                }
                onReleased: endDrag()
                onCanceled: endDrag()
            }

            Rectangle {
                id: removeBadge
                visible: face.editing && tile.placed && !tile.dragging
                x: -7
                y: -7
                width: 24
                height: 24
                radius: width / 2
                color: Theme.pLine
                antialiasing: true

                MaterialIcon {
                    name: "remove"
                    size: 16
                    fill: 1
                    color: "white"
                    anchors.centerIn: parent
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: face.tileRemoveRequested(tile.pos)
                }
            }

            Rectangle {
                id: resizeBadge
                visible: face.editing && tile.placed && !tile.dragging
                x: tile.slotW - width + 7
                y: -7
                width: 24
                height: 24
                radius: width / 2
                color: Theme.pLine
                opacity: face.canResize(tile.pos) ? 1 : 0.35
                antialiasing: true

                MaterialIcon {
                    name: face.resizeGrows(tile.pos) ? "open_in_full" : "close_fullscreen"
                    size: 14
                    fill: 1
                    color: "white"
                    anchors.centerIn: parent
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    enabled: face.canResize(tile.pos)
                    cursorShape: Qt.PointingHandCursor
                    onClicked: face.tileResizeRequested(tile.pos)
                }
            }
        }
    }

    Rectangle {
        readonly property bool shown: face.editing && face.dropIndex >= 0 && face.dropIndex < face.tiles.length
        readonly property var dropSlot: shown ? face.tileLayout.slots[face.dropIndex] : null
        visible: shown
        x: 67 + (dropSlot ? dropSlot.x : 0) - 5
        y: 373 + (dropSlot ? dropSlot.y : 0) - 4
        width: (dropSlot ? dropSlot.w : 0) + 10
        height: (dropSlot ? dropSlot.rowH : 75) + 8
        radius: 44
        color: "transparent"
        border.width: 3
        border.color: Theme.accentCyan
        antialiasing: true
    }

    GammaBrightnessSlider {
        x: 67
        y: 570 + face.tileExtra
        sliderWidth: 514
        gamma: face.gamma
        brightness: face.brightness
        onGammaMoved: value => face.gammaMoved(value)
        onBrightnessMoved: value => face.brightnessMoved(value)
    }

    Timer {
        interval: 20000
        repeat: true
        running: face.visible
        onTriggered: face.nowMs = Date.now()
    }

    onVisibleChanged: {
        if (visible)
            nowMs = Date.now()
    }

    ListModel {
        id: listModel
    }

    function groupIdOf(n) {
        return n.app !== "" ? n.app : "#" + n.key
    }

    property var expandedGroups: ({})

    function toggleGroup(gid) {
        const m = Object.assign({}, expandedGroups)
        if (m[gid])
            delete m[gid]
        else
            m[gid] = true
        expandedGroups = m
    }

    function groupItems(gid) {
        return notifications.filter(n => groupIdOf(n) === gid)
    }

    function groupKeys(gid) {
        return groupItems(gid).map(n => n.key)
    }

    function groupsOf(list) {
        const order = []
        const map = Object.create(null)
        for (let i = 0; i < list.length; i++) {
            const gid = groupIdOf(list[i])
            if (!(gid in map)) {
                map[gid] = { gid: gid, count: 0, urgency: 0, n: list[i] }
                order.push(gid)
            }
            map[gid].count++
            map[gid].urgency = Math.max(map[gid].urgency, list[i].urgency)
        }
        return order.map(gid => map[gid])
    }

    function cardData(g) {
        return {
            gid: g.gid,
            key: g.n.key,
            app: g.n.app,
            title: g.n.title,
            body: g.n.body,
            time: g.n.time,
            urgency: g.urgency,
            icon: g.n.icon,
            groupCount: g.count
        }
    }

    function syncNotifications() {
        const incoming = groupsOf(notifications)
        const want = Object.create(null)
        for (let i = 0; i < incoming.length; i++)
            want[incoming[i].gid] = incoming[i].count

        let stale = false
        for (const gid in expandedGroups) {
            if (!(want[gid] > 1))
                stale = true
        }
        if (stale) {
            const m = {}
            for (const gid in expandedGroups) {
                if (want[gid] > 1)
                    m[gid] = true
            }
            expandedGroups = m
        }

        for (let i = listModel.count - 1; i >= 0; i--) {
            if (!(listModel.get(i).gid in want))
                listModel.remove(i)
        }

        for (let i = 0; i < incoming.length; i++) {
            const g = incoming[i]
            const n = g.n
            if (i < listModel.count && listModel.get(i).gid === g.gid) {
                const row = listModel.get(i)
                if (row.key !== n.key || row.app !== n.app || row.title !== n.title || row.body !== n.body
                        || row.urgency !== g.urgency || row.time !== n.time
                        || row.icon !== n.icon || row.groupCount !== g.count)
                    listModel.set(i, cardData(g))
                continue
            }
            let found = -1
            for (let j = i + 1; j < listModel.count; j++) {
                if (listModel.get(j).gid === g.gid) {
                    found = j
                    break
                }
            }
            if (found >= 0) {
                listModel.move(found, i, 1)
                listModel.set(i, cardData(g))
            } else {
                listModel.insert(i, cardData(g))
            }
        }
    }

    onNotificationsChanged: syncNotifications()
    Component.onCompleted: syncNotifications()

    function ago(ms) {
        const s = Math.max(0, Math.floor((nowMs - ms) / 1000))
        if (s < 60)
            return "now"
        if (s < 3600)
            return Math.floor(s / 60) + "m"
        if (s < 86400)
            return Math.floor(s / 3600) + "h"
        return Math.floor(s / 86400) + "d"
    }

    // The now-playing card borrows the top of the notifications slot.
    readonly property bool mediaCardShown: face.mediaOn && face.mediaPresent
    readonly property real mediaGap: face.mediaCardShown ? 144 : 0
    readonly property real notificationsH: Math.max(140, 515 - face.tileExtra - face.mediaGap)

    NowPlayingCard {
        visible: opacity > 0.01
        opacity: face.mediaCardShown ? 1 : 0
        x: 40
        y: 655 + face.tileExtra
        renderScale: face.renderScale
        title: face.mediaTitle
        artist: face.mediaArtist
        art: face.mediaArt
        playing: face.mediaPlaying
        onToggleRequested: face.mediaToggleRequested()
        onPreviousRequested: face.mediaPreviousRequested()
        onNextRequested: face.mediaNextRequested()
        onLyricsRequested: face.lyricsRequested()

        Behavior on opacity {
            NumberAnimation {
                duration: 180
            }
        }
    }

    Rectangle {
        x: 40 + (Theme.quickFlat ? 0 : 5)
        y: 655 + 4 + face.tileExtra + face.mediaGap
        width: 575
        height: face.notificationsH
        radius: 41
        color: Theme.pLineShadow
        antialiasing: true

        Behavior on y {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
    }

    Rectangle {
        id: notificationsCard
        x: 40
        y: 655 + face.tileExtra + face.mediaGap
        width: 575
        height: face.notificationsH
        radius: 41
        color: Theme.pSurface
        border.width: 3
        border.color: Theme.pLine
        clip: true

        Behavior on y {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        readonly property bool empty: face.notifications.length === 0


        property bool clearing: false

        signal clearAllTriggered()

        Timer {
            id: clearAllTimer
            interval: 5 * 35 + 140 + 20
            onTriggered: {
                face.notificationsCleared()
                notificationsCard.clearing = false
                face.panelCloseRequested()
            }
        }

        WheelScroll { scroller: list }
        ListView {
            id: list
            x: 27
            y: 28
            width: 526
            height: Math.max(95.06, Math.min(notificationsCard.height - 28 - 3,
                                             face.visibleBottomLeft + face.visibleExtra
                                             - (notificationsCard.y + list.y)))
            bottomMargin: face.visibleExtra + Math.max(0, face.visibleBottomLeft - face.visibleBottomRight) + face.listBottomPad
            clip: true
            spacing: 7
            boundsBehavior: Flickable.StopAtBounds
            model: listModel
            onContentYChanged: PanelActivity.touch()

            // A new notification: it fades in at the top while the
            // others slide down to make room. Also runs for the cards
            // that are there when the panel is first built, which is
            // why it only touches opacity.
            add: Transition {
                NumberAnimation {
                    property: "opacity"; from: 0; to: 1; duration: 200
                }
            }

            remove: Transition {
                NumberAnimation {
                    property: "opacity"; to: 0; duration: 140
                }
            }

            displaced: Transition {
                NumberAnimation {
                    properties: "y"; duration: 240; easing.type: Easing.OutCubic
                }
            }

            // Just a sliver under the last card. It used to be big enough
            // to lift the last card fully clear of the slanted screen
            // edge, but that left a blank strip under it whenever you
            // scrolled to the end. Instead the last card now rests
            // against the edge like the others: its bottom-right corner
            // dips off-screen a little (the tilt), while the text — all
            // on the left, where the edge is lowest — stays fully visible.
            footer: Item {
                width: 526
                height: 6
            }

            delegate: Item {
                id: row

                required property int index
                required property string gid
                required property var key
                required property string app
                required property string title
                required property string body
                required property double time
                required property int urgency
                required property string icon
                required property int groupCount

                readonly property bool group: groupCount > 1
                readonly property bool open: group && face.expandedGroups[gid] === true
                readonly property real headerH: 95.06

                width: 526
                height: headerH + (open ? 7 + childCol.implicitHeight : (group ? 8 : 0))
                clip: true
                Behavior on height {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }

                readonly property color peekTone: Theme.classic ? Qt.color("#e9e9e9") : Qt.darker(Theme.pSurfaceHover, 1.12)

                property real peekShow: row.open ? 0 : 1
                Behavior on peekShow { NumberAnimation { duration: 150 } }

                Rectangle {
                    visible: row.group
                    opacity: row.peekShow * head.slideOpacity
                    x: 9 + head.slideX
                    y: row.headerH - 30
                    width: 508
                    height: 35
                    radius: 16.5
                    color: row.peekTone
                    antialiasing: true
                }

                Rectangle {
                    visible: row.group
                    opacity: row.peekShow * head.slideOpacity
                    x: 18 + head.slideX
                    y: row.headerH - 30
                    width: 490
                    height: 38
                    radius: 16.5
                    color: Qt.darker(row.peekTone, 1.06)
                    antialiasing: true
                }

                NotificationCard {
                    id: head

                    key: row.key
                    app: row.app
                    title: row.open ? row.groupCount + " notifications" : row.title
                    body: row.open ? "Swipe to clear them all" : row.body
                    time: row.time
                    urgency: row.urgency
                    icon: row.icon
                    agoText: face.ago(row.time)
                    groupCount: row.groupCount
                    expanded: row.open
                    blocked: notificationsCard.clearing
                    clearIndex: row.index

                    onDismissed: {
                        if (row.group)
                            face.notificationsDismissed(face.groupKeys(row.gid))
                        else
                            face.notificationDismissed(row.key)
                    }
                    onToggled: face.toggleGroup(row.gid)
                    onActivated: face.notificationActivated(row.key)

                    Connections {
                        target: notificationsCard
                        function onClearAllTriggered() { head.clearOut() }
                    }
                }

                Column {
                    id: childCol
                    x: 14
                    y: row.headerH + 7
                    spacing: 7
                    opacity: row.open ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160 } }

                    Repeater {
                        model: row.open ? face.groupItems(row.gid) : []

                        delegate: NotificationCard {
                            required property var modelData

                            key: modelData.key
                            app: modelData.app
                            title: modelData.title
                            body: modelData.body
                            time: modelData.time
                            urgency: modelData.urgency
                            icon: modelData.icon
                            agoText: face.ago(modelData.time)
                            cardWidth: 512
                            blocked: notificationsCard.clearing
                            onDismissed: face.notificationDismissed(modelData.key)
                            onActivated: face.notificationActivated(modelData.key)
                        }
                    }
                }
            }
        }

        // Scrollbar for the real list (only when there's more than fits)
        Rectangle {
            visible: !notificationsCard.empty && list.visibleArea.heightRatio < 1
            readonly property real track: list.height - face.visibleExtra - Math.max(0, face.visibleBottomLeft - face.visibleBottomRight)
            x: 563
            y: 28 + list.visibleArea.yPosition * track
            width: 6
            height: Math.max(30, list.visibleArea.heightRatio * track)
            radius: 3
            color: Theme.pSurfaceRing
            antialiasing: true
        }
        antialiasing: true
    }

    Rectangle {
        id: editTray
        x: 40
        y: notificationsCard.y
        width: 575
        height: notificationsCard.height
        // How much of the tray is on the monitor. Only the top of the phone
        // shows, so (as with the notification list) anything below the
        // slanted cutoff is off-screen: the lower of its two ends is used
        // because the tray spans the whole width.
        readonly property real shownH: Math.max(0, Math.min(height,
            Math.min(face.visibleBottomLeft, face.visibleBottomRight) - y))
        readonly property real reachH: Math.max(0, Math.min(height,
            face.visibleBottomLeft + face.visibleExtra - y))
        radius: 41
        color: Theme.pSurface
        border.width: 3
        border.color: Theme.pLine
        clip: true
        opacity: face.editing ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity {
            NumberAnimation {
                duration: 160
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            onWheel: wheel => wheel.accepted = true
        }

        // Columns: the most buttons a row may hold, 1-5, whatever their size.
        // Five is the old layout (widths never change — fewer columns just
        // wrap sooner). A count that would make the grid too tall for the
        // current buttons is dimmed and does nothing until one is removed.
        Item {
            id: columnsRow
            x: 27
            y: 30
            width: 520
            height: 44

            Text {
                id: columnsLabel
                anchors.verticalCenter: parent.verticalCenter
                text: "Columns"
                color: Theme.pInk
                font.family: Theme.fontFamily
                font.pixelSize: 18
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }

            Row {
                anchors.left: columnsLabel.right
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Repeater {
                    model: [1, 2, 3, 4, 5]

                    delegate: Rectangle {
                        id: chip
                        required property int modelData

                        readonly property bool current: face.tileColumns === modelData
                        readonly property bool allowed: face.canColumns(modelData)

                        width: 46
                        height: 40
                        radius: 20
                        color: chip.current ? Theme.accentMint : Theme.pSurfaceDivider
                        border.width: 3
                        border.color: Theme.pLine
                        opacity: chip.allowed || chip.current ? 1 : 0.4
                        antialiasing: true

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: chip.modelData
                            color: chip.current ? Theme.colBorder : Theme.pInk
                            font.family: Theme.fontFamily
                            font.pixelSize: 18
                            font.weight: Font.ExtraBold
                            font.styleName: Theme.fontStyleBold
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: chip.allowed && !chip.current
                            cursorShape: Qt.PointingHandCursor
                            onClicked: face.tileColumnsRequested(chip.modelData)
                        }
                    }
                }
            }
        }

        // The buttons that aren't on the panel, five to a row (100px each, 4px
        // apart = 516 of the tray's 520px content width). There are more of
        // them than fit in the tray at once, so the list scrolls: mouse wheel,
        // or drag it. When the "panel is full" note is showing, the list stops
        // above it instead of running underneath.
        WheelScroll { scroller: trayScroll }
        Flickable {
            id: trayScroll
            x: 27
            y: columnsRow.y + columnsRow.height + 10
            width: 520
            // Runs all the way down to the monitor edge (editTray.reachH), like the
            // notification list: the buttons scroll under the edge instead of being
            // cut by an invisible line with the picture showing under them. The
            // room the last row needs to come up clear of the edge is scroll margin
            // (bottomMargin), not a shorter list. With the "panel is full" note up,
            // the list still stops above the note.
            readonly property bool noteUp: face.unplacedTiles.length > 0 && !face.canAdd
            height: Math.max(0, (noteUp ? editTray.shownH - 68 : editTray.reachH - 14) - y)
            bottomMargin: noteUp ? 0 : Math.max(0, editTray.reachH - editTray.shownH) + face.listBottomPad
            onContentYChanged: PanelActivity.touch()
            contentWidth: width
            contentHeight: trayFlow.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            Flow {
                id: trayFlow
                width: trayScroll.width
                spacing: 4

                Repeater {
                    model: face.unplacedTiles

                    delegate: Item {
                        required property string modelData

                        width: 100
                        height: 118
                        opacity: face.canAdd ? 1 : 0.4

                        QuickToggle {
                            flatShadow: Theme.quickFlat
                            kind: "round"
                            anchors.horizontalCenter: parent.horizontalCenter
                            hoverLights: face.canAdd
                            enabled: face.canAdd
                            icon: face.tileIcon(modelData)
                            onClicked: face.tileAddRequested(modelData)
                        }

                        Text {
                            y: 80
                            x: 2
                            width: parent.width - 4
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            lineHeight: 0.9
                            text: face.tileName(modelData)
                            color: Theme.pInk
                            font.family: Theme.fontFamily
                            font.pixelSize: 16
                            font.weight: Font.ExtraBold
                            font.styleName: Theme.fontStyleBold
                        }
                    }
                }
            }
        }

        // Scrollbar for the list (only when there's more than fits)
        Rectangle {
            visible: trayScroll.visibleArea.heightRatio < 1
            x: 555
            y: trayScroll.y + trayScroll.visibleArea.yPosition * trayScroll.height
            width: 6
            height: Math.max(30, trayScroll.visibleArea.heightRatio * trayScroll.height)
            radius: 3
            color: Theme.pSurfaceRing
            antialiasing: true
        }

        Text {
            visible: face.unplacedTiles.length === 0
            x: 27
            y: columnsRow.y + columnsRow.height + 24
            width: 520
            wrapMode: Text.WordWrap
            text: "Every button is on the panel. Remove one to see it here."
            color: Theme.pInk
            opacity: 0.67
            font.family: Theme.fontFamily
            font.pixelSize: 18
        }

        Text {
            visible: face.unplacedTiles.length > 0 && !face.canAdd
            x: 27
            y: editTray.shownH - 60
            width: 520
            wrapMode: Text.WordWrap
            text: "The panel is full. Remove a button to make room."
            color: Theme.pInk
            opacity: 0.67
            font.family: Theme.fontFamily
            font.pixelSize: 18
        }
    }

    Rectangle {
        id: tag

        x: 212
        y: 639 + face.tileExtra
        width: 229
        height: 31
        radius: 27
        color: tagArea.containsMouse && !notificationsCard.empty && !notificationsCard.clearing ? Theme.accentMint : Theme.pSurface
        border.width: 3
        border.color: Theme.pLine

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        Text {
            anchors.centerIn: parent
            text: face.editing ? "Add buttons"
                : (tagArea.containsMouse && !notificationsCard.empty && !notificationsCard.clearing ? "Clear all" : "Notifications")
            color: Theme.pInk
            font.family: Theme.fontFamily
            font.pixelSize: 20
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }

        MouseArea {
            id: tagArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: !face.editing && !notificationsCard.empty && !notificationsCard.clearing
            cursorShape: notificationsCard.empty ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: {
                notificationsCard.clearing = true
                notificationsCard.clearAllTriggered()
                clearAllTimer.restart()
            }
        }
        antialiasing: true
    }

    NetworkDialog {
        id: networkDialog
        open: face.networkDialogOpen
        networks: face.wifiNetworks
        scanning: face.wifiScanning
        manualScanning: face.wifiManualScanning
        connectingSsid: face.wifiConnectingSsid
        errorText: face.wifiConnectError
        onCloseRequested: face.networkDialogOpen = false
        onScanRequested: face.wifiScanRequested()
        onAdvancedRequested: face.wifiAdvancedRequested()
        onConnectRequested: (ssid, password) => face.wifiConnectRequested(ssid, password)
        onDisconnectRequested: ssid => face.wifiDisconnectRequested(ssid)
    }

    BluetoothDialog {
        id: bluetoothDialog
        open: face.bluetoothDialogOpen
        devices: face.bluetoothDevices
        scanning: face.bluetoothScanning
        manualScanning: face.bluetoothManualScanning
        connectingAddress: face.bluetoothConnectingAddress
        errorText: face.bluetoothConnectError
        onCloseRequested: face.bluetoothDialogOpen = false
        onScanRequested: face.bluetoothScanRequested()
        onAdvancedRequested: face.bluetoothAdvancedRequested()
        onConnectRequested: address => face.bluetoothConnectRequested(address)
        onDisconnectRequested: address => face.bluetoothDisconnectRequested(address)
    }

    VolumeMixerDialog {
        id: volumeMixerDialog
        open: face.audioDialogKind !== ""
        kind: face.audioDialogShownKind === "microphone" ? "microphone" : "speaker"
        title: face.audioDialogShownKind === "microphone" ? "Microphone" : "Speaker"
        deviceCaption: face.audioDialogShownKind === "microphone" ? "Input" : "Output"
        devices: face.audioDialogShownKind === "microphone" ? face.microphoneDevices : face.speakerDevices
        streams: face.audioDialogShownKind === "microphone" ? face.microphoneStreams : face.speakerStreams
        scanning: face.audioDevicesScanning
        manualScanning: face.audioDevicesManualScanning
        selectingDeviceId: face.audioDeviceSelectingId
        onCloseRequested: face.audioDialogKind = ""
        onScanRequested: face.audioDeviceScanRequested()
        onDeviceSelected: id => {
            if (face.audioDialogShownKind === "microphone")
                face.microphoneDeviceSelected(id)
            else
                face.speakerDeviceSelected(id)
        }
        onStreamVolumeChanged: (id, value) => {
            if (face.audioDialogShownKind === "microphone")
                face.microphoneStreamVolumeChanged(id, value)
            else
                face.speakerStreamVolumeChanged(id, value)
        }
        onStreamMuteToggled: (id, muted) => {
            if (face.audioDialogShownKind === "microphone")
                face.microphoneStreamMuteToggled(id, muted)
            else
                face.speakerStreamMuteToggled(id, muted)
        }
        onStreamDragStarted: id => {
            if (face.audioDialogShownKind === "microphone")
                face.microphoneStreamDragStarted(id)
            else
                face.speakerStreamDragStarted(id)
        }
        onStreamDragEnded: id => {
            if (face.audioDialogShownKind === "microphone")
                face.microphoneStreamDragEnded(id)
            else
                face.speakerStreamDragEnded(id)
        }
    }

    NightLightDialog {
        id: nightLightDialog
        open: face.nightLightDialogOpen
        nightOn: face.nightLightOn
        temperature: face.nightLightTemperature
        autoOn: face.nightLightAuto
        autoFrom: face.nightLightAutoFrom
        autoTo: face.nightLightAutoTo
        onCloseRequested: face.nightLightDialogOpen = false
        onToggleRequested: face.nightLightToggled()
        onTemperatureMoved: kelvin => face.nightLightTemperatureMoved(kelvin)
        onAutoRequested: on => face.nightLightAutoRequested(on)
        onScheduleRequested: (from, to) => face.nightLightScheduleRequested(from, to)
    }

    PowerMenuScrim {
        id: powerScrim
        open: face.powerMenuOpen
        onDismissRequested: face.powerMenuOpen = false
    }

    Item {
        id: alertCard

        readonly property var e: face.alertEntry
        readonly property bool critical: e !== null && e.urgency === 2
        readonly property bool shellIcon: e !== null && e.icon.startsWith("material:")

        property real reveal: face.alertShown ? 1 : 0
        property real pop: 0

        x: 47
        y: 84 - (1 - reveal) * 44
        width: 560
        height: 112
        visible: reveal > 0.001
        opacity: Math.min(1, reveal * 1.6)
        scale: (0.94 + 0.06 * reveal) * (1 + 0.04 * pop)
        transformOrigin: Item.Top

        Behavior on reveal {
            NumberAnimation {
                duration: face.alertShown ? 300 : 200
                easing.type: face.alertShown ? Easing.OutBack : Easing.InCubic
                easing.overshoot: 1.4
            }
        }

        Connections {
            target: face
            function onAlertEntryChanged() {
                if (face.alertShown && alertCard.reveal > 0.5)
                    popAnim.restart()
            }
        }

        NumberAnimation {
            id: popAnim
            target: alertCard
            property: "pop"
            from: 1
            to: 0
            duration: 340
            easing.type: Easing.OutQuad
        }

        onYChanged: PanelActivity.touch()

        Rectangle {
            x: Theme.quickFlat ? 0 : 5
            y: 4
            width: parent.width
            height: parent.height
            radius: 34
            color: Theme.pLineShadow
            antialiasing: true
        }

        Rectangle {
            anchors.fill: parent
            radius: 34
            color: Theme.pSurface
            border.width: alertCard.critical ? 5 : 3
            border.color: Theme.pLine
            antialiasing: true
        }

        Item {
            id: alertIcon
            x: 22
            width: 64
            height: 64
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                visible: !alertCard.shellIcon
                anchors.fill: parent
                radius: width / 2
                color: Theme.pSurface
                antialiasing: true
            }

            ShellBadge {
                anchors.centerIn: parent
                size: 58
                visible: alertCard.shellIcon
                glyph: alertCard.shellIcon ? alertCard.e.icon.substring(9) : ""
            }

            Image {
                anchors.centerIn: parent
                width: parent.width
                height: width
                visible: alertCard.e !== null && alertCard.e.icon !== "" && !alertCard.e.icon.startsWith("material:")
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                sourceSize: Qt.size(Math.ceil(width * 3), Math.ceil(width * 3))
                source: alertCard.e !== null && !alertCard.e.icon.startsWith("material:") ? alertCard.e.icon : ""
            }

            MaterialIcon {
                anchors.centerIn: parent
                size: parent.width - 10
                visible: alertCard.e === null || alertCard.e.icon === ""
                name: "notifications_active"
            }
        }

        Text {
            x: 104
            y: 12
            width: 340
            elide: Text.ElideRight
            text: alertCard.e !== null ? alertCard.e.app : ""
            color: Theme.pInkSub
            font.family: Theme.fontFamily
            font.pixelSize: 15
            font.weight: Font.Medium
        }

        Text {
            x: parent.width - 26 - width
            y: 12
            width: 70
            horizontalAlignment: Text.AlignRight
            text: "now"
            color: Theme.pInkSub
            font.family: Theme.fontFamily
            font.pixelSize: 15
            font.weight: Font.Medium
        }

        Text {
            x: 104
            y: 31
            width: 434
            elide: Text.ElideRight
            text: alertCard.e !== null ? alertCard.e.title : ""
            color: Theme.pInk
            font.family: Theme.fontFamily
            font.pixelSize: 23
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
        }

        Text {
            x: 104
            y: 61
            width: 434
            visible: text !== ""
            text: alertCard.e !== null ? alertCard.e.body : ""
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            lineHeight: 0.92
            color: Theme.pInk
            font.family: Theme.fontFamily
            font.pixelSize: 17
        }

        Timer {
            id: hoverOpen
            interval: 180
            onTriggered: {
                if (face.alertShown)
                    face.alertActivated()
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: face.alertShown
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: {
                if (containsMouse)
                    hoverOpen.restart()
                else
                    hoverOpen.stop()
            }
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton && alertCard.e !== null)
                    face.alertDismissRequested(alertCard.e.key)
                else if (mouse.button === Qt.LeftButton && alertCard.e !== null)
                    face.alertClicked(alertCard.e.key)
                else
                    face.alertActivated()
            }
        }
    }
}
