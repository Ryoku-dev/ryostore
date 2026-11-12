pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Ryoku.Ui.Singletons

// The morphing island. Picks a mode, springs to its size, crossfades pages.
Item {
    id: root
    required property string screenName

    readonly property bool focusedHere: Wm.focusedOutput === "" || Wm.focusedOutput === screenName
    readonly property bool isExpanded: Hub.expanded && Hub.expandedScreen === screenName
    readonly property bool isLauncher: Hub.launcherOpen && Hub.launcherScreen === screenName
    property bool peek: false

    readonly property string primary: Hub.activities.length > 0 ? Hub.activities[0] : ""
    readonly property string secondary: Config.s.splitActivities && Hub.activities.length > 1 ? Hub.activities[1] : ""
    readonly property var notif: Config.s.notifStyle === "island" && focusedHere && Notifs.popups.length > 0 ? Notifs.popups[0] : null

    readonly property string mode: {
        if (isLauncher) return "launcher";
        if (isExpanded) return "expanded";
        if (focusedHere && Hub.event !== "") return Hub.event;      // osd | workspace | device
        if (notif) return "notif";
        if (primary !== "") {
            const p = peek || (primary === "media" && Hub.trackFlash && focusedHere);
            return p ? primary + "Peek" : primary;
        }
        return peek ? "idlePeek" : "idle";
    }
    readonly property bool compact: mode === "idle" || mode === "media" || mode === "timer" || mode === "stopwatch" || mode === "recording"
    // Keep the time visible while a live activity owns the island (iOS/macOS-style split)
    readonly property bool activityCompact: compact && mode !== "idle"
    readonly property bool clockSplit: Config.s.activityClock === "split" && activityCompact
    readonly property bool inlineClock: Config.s.activityClock === "inline"

    //                       home media controls timer
    readonly property var tabHeights: [404, 312, 430, 300]
    readonly property int expandedWidth: 700
    readonly property size target: {
        switch (mode) {
        case "launcher":      return Qt.size(600, launcherPage.wantedHeight);
        case "expanded":      return Qt.size(expandedWidth, tabHeights[Hub.tab] || 360);
        case "notif":         return Qt.size(470, Math.max(76, notifCard.implicitHeight + 24));
        case "osd":           return Qt.size(340, 50);
        case "device":        return Qt.size(390, 76);
        case "workspace":     return Qt.size(wsRow.implicitWidth + 44, 40);
        case "media":         return Qt.size(root.inlineClock ? 372 : 320, 38);
        case "mediaPeek":     return Qt.size(452, 176);
        case "timer":         return Qt.size(196, 38);
        case "stopwatch":     return Qt.size(206, 38);
        case "timerPeek":
        case "stopwatchPeek": return Qt.size(410, 84);
        case "recording":     return Qt.size(196, 38);
        case "recordingPeek": return Qt.size(392, 76);
        case "idlePeek":      return Qt.size(410, 66);
        default:              return Qt.size(Math.max(126, idleRow.implicitWidth + 38), 36);
        }
    }

    width: target.width
    height: target.height
    Behavior on width { SpringAnimation { spring: Theme.spring; damping: Theme.damping; epsilon: 0.25 } }
    Behavior on height { SpringAnimation { spring: Theme.spring * 1.12; damping: Math.min(1, Theme.damping + 0.06); epsilon: 0.25 } }

    // ── Hover peek with intent delay ──
    HoverHandler {
        id: hover
        onHoveredChanged: {
            peekTimer.restart();
            Hub.holdEvent(hovered);
            Notifs.hovering = hovered && root.mode === "notif";
        }
    }
    Timer {
        id: peekTimer
        interval: hover.hovered ? Config.s.hoverDelay : 160
        onTriggered: root.peek = hover.hovered && Config.s.hoverPeek
    }

    // ── Keyboard while expanded ──
    Item {
        id: keys
        focus: true
        Keys.onPressed: e => {
            if (!root.isExpanded) return;
            if (e.key === Qt.Key_Escape) Hub.expanded = false;
            else if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab) Hub.tab = (Hub.tab + 1) % 4;
            else if (e.key === Qt.Key_Left || e.key === Qt.Key_Backtab) Hub.tab = (Hub.tab + 3) % 4;
            else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_4) Hub.tab = e.key - Qt.Key_1;
            else if (e.key === Qt.Key_Space && Hub.player) Hub.player.togglePlaying();
            else if (e.key === Qt.Key_Comma && (e.modifiers & Qt.ControlModifier)) Hub.openSettings();
            else return;
            e.accepted = true;
        }
    }
    onIsExpandedChanged: if (isExpanded) keys.forceActiveFocus()

    // ═══════════════════════ SURFACE ═══════════════════════
    readonly property color glowColor: {
        if (Hub.recording) return Theme.red;
        if (mode === "notif" && Notifs.critical(notif)) return Theme.red;
        if ((mode === "osd" || mode === "device") && Hub.eventTinted) return Hub.eventColor;
        if (mode.startsWith("timer")) return Theme.orange;
        return Theme.live;
    }
    readonly property real glowStrength: {
        if (!Config.s.glow || isExpanded || isLauncher) return 0;
        if (Hub.recording || (mode === "notif" && Notifs.critical(notif))) return 0.45;
        if ((mode === "osd" || mode === "device") && Hub.eventTinted) return 0.35;
        if (mode.startsWith("timer")) return 0.25;
        if (Hub.playing) return 0.3;
        return 0;
    }

    Glass {
        id: surface
        anchors.fill: parent
        radius: root.isExpanded ? 36 : root.isLauncher ? 28 : root.height >= 60 ? 32 : root.height / 2
        glowColor: root.glowColor
        glowStrength: root.glowStrength
        shadowBlur: root.isExpanded || root.isLauncher ? 40 : 24
        shadowY: root.isExpanded || root.isLauncher ? 14 : 6
    }

    // Whole-island gestures
    MouseArea {
        anchors.fill: parent
        enabled: !root.isExpanded && !root.isLauncher
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: m => {
            if (m.button === Qt.MiddleButton) { if (Hub.player) Hub.player.togglePlaying(); return; }
            if (m.button === Qt.RightButton) { Hub.openTab(root.screenName, 2); return; }
            if (root.mode === "notif") { Notifs.activate(root.notif); return; }
            if (root.mode.startsWith("media")) { Hub.openTab(root.screenName, 1); return; }
            if (root.mode.startsWith("timer") || root.mode.startsWith("stopwatch")) {
                Hub.timerMode = root.mode.startsWith("stopwatch") ? 1 : 0;
                Hub.openTab(root.screenName, 3);
                return;
            }
            Hub.openTab(root.screenName, 0);
        }
        onWheel: w => Hub.setVolume(Hub.volume + (w.angleDelta.y > 0 ? 0.04 : -0.04))
    }

    // ═══════════════════════ BUILDING BLOCKS ═══════════════════════
    component Page: Item {
        id: page
        property bool shown: false
        anchors.fill: parent
        opacity: shown ? 1 : 0
        scale: shown ? 1 : 0.92
        visible: opacity > 0.01
        enabled: shown
        layer.enabled: !Theme.reduced && opacity > 0.01 && opacity < 0.99
        layer.effect: MultiEffect { blurEnabled: true; blurMax: 32; blur: 1 - page.opacity }
        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation { duration: page.shown && !Theme.reduced ? 70 : 0 }
                NumberAnimation { duration: page.shown ? 280 : 150; easing.type: Easing.OutCubic }
            }
        }
        Behavior on scale { NumberAnimation { duration: Theme.reduced ? 1 : 460; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }
    }

    component PulseDot: Rectangle {
        width: 8; height: 8; radius: 4
        SequentialAnimation on opacity {
            loops: Animation.Infinite
            running: true
            NumberAnimation { to: 0.25; duration: 750; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 750; easing.type: Easing.InOutSine }
        }
    }

    component RoundBtn: Rectangle {
        id: rb
        property string icon: ""
        property color tint: Theme.fg
        property bool tinted: true
        property real size: 44
        signal clicked()
        width: size; height: size; radius: size / 2
        color: tinted ? Theme.alpha(tint, rbMa.containsMouse ? 0.32 : 0.22) : (rbMa.containsMouse ? Theme.fill3 : Theme.fill2)
        scale: rbMa.pressed ? 0.88 : 1
        Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
        Behavior on color { ColorAnimation { duration: 150 } }
        Icon { anchors.centerIn: parent; text: rb.icon; size: rb.size * 0.5; fill: 1; color: rb.tinted ? rb.tint : Theme.fg }
        MouseArea { id: rbMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: rb.clicked() }
    }

    component TabPage: Item {
        id: tp
        property int index: 0
        readonly property bool current: Hub.tab === index
        width: parent ? parent.width : 0
        opacity: current ? 1 : 0
        visible: opacity > 0.01
        enabled: current
        transform: Translate {
            x: tp.current ? 0 : (tp.index < Hub.tab ? -40 : 40)
            Behavior on x { NumberAnimation { duration: Theme.reduced ? 1 : 440; easing.type: Easing.OutCubic } }
        }
        Behavior on opacity { NumberAnimation { duration: Theme.reduced ? 1 : 260; easing.type: Easing.OutCubic } }
    }

    // ═══════════════════════ PAGES ═══════════════════════
    ClippingRectangle {
        id: content
        anchors.fill: parent
        radius: surface.r
        color: "transparent"

        // ─────────── IDLE ───────────
        Page {
            shown: root.mode === "idle"
            Row {
                id: idleRow
                anchors.centerIn: parent
                spacing: 9

                Icon {
                    visible: Hub.player !== null && !Hub.playing && root.primary === ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: "music_note"; size: 15; color: Theme.fg3
                }
                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Hub.clockTextSec
                    size: 13.5
                    weight: Font.DemiBold
                }
                Row {
                    visible: Config.s.showPrivacy && (Hub.micInUse || Hub.camInUse)
                    spacing: 4
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle { visible: Hub.micInUse; width: 7; height: 7; radius: 3.5; color: Theme.orange }
                    Rectangle { visible: Hub.camInUse; width: 7; height: 7; radius: 3.5; color: Theme.green }
                }
                Icon { visible: Notifs.dnd; text: "bedtime"; size: 15; fill: 1; color: Theme.indigo; anchors.verticalCenter: parent.verticalCenter }
                Icon { visible: Hub.caffeine; text: "coffee"; size: 15; fill: 1; color: Theme.orange; anchors.verticalCenter: parent.verticalCenter }
                Row {
                    visible: Hub.hasBattery && Config.s.showBattery
                    spacing: 3
                    anchors.verticalCenter: parent.verticalCenter
                    Txt { text: Math.round(Hub.batPct * 100); size: 11.5; color: Theme.fg2; anchors.verticalCenter: parent.verticalCenter }
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Hub.batteryIcon; size: 16; fill: 1; rotation: 90
                        color: Hub.batCharging ? Theme.green : Hub.batPct < 0.2 ? Theme.red : Theme.fg
                    }
                }
            }
        }

        // ─────────── IDLE PEEK ───────────
        Page {
            shown: root.mode === "idlePeek"
            Column {
                id: peekLeft
                anchors.left: parent.left
                anchors.leftMargin: 24
                anchors.verticalCenter: parent.verticalCenter
                Row {
                    spacing: 3
                    Txt { id: peekClock; text: Hub.fmtClock(Hub.now, false, false); size: 24; weight: Font.DemiBold }
                    Txt { visible: Hub.ampm !== ""; anchors.baseline: peekClock.baseline; text: Hub.ampm; size: 12; weight: Font.DemiBold; color: Theme.fg2 }
                }
                Txt { text: Qt.formatDate(Hub.now, "dddd, d MMM"); size: 11.5; color: Theme.fg2 }
            }
            Column {
                anchors.right: parent.right
                anchors.rightMargin: 22
                anchors.left: peekLeft.right
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Row {
                    anchors.right: parent.right
                    spacing: 5
                    visible: Hub.wTemp !== ""
                    Icon { text: Hub.weatherSymbol(Hub.wDesc); size: 17; fill: 1; color: Hub.weatherColor(Hub.wDesc) }
                    Txt { text: Hub.wTemp + "  " + Hub.wDesc; size: 12.5; weight: Font.DemiBold; width: Math.min(implicitWidth, 190) }
                }
                Row {
                    anchors.right: parent.right
                    spacing: 6
                    IconImage {
                        visible: Hub.activeIcon !== ""
                        source: Hub.activeIcon
                        implicitSize: 15
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Txt {
                        width: Math.min(implicitWidth, 200)
                        text: Hub.activeName || "Desktop"
                        size: 11.5
                        color: Theme.fg2
                    }
                    Rectangle {
                        visible: Notifs.visibleCount > 0
                        anchors.verticalCenter: parent.verticalCenter
                        height: 16; radius: 8
                        width: nb.implicitWidth + 10
                        color: Theme.red
                        Txt { id: nb; anchors.centerIn: parent; text: Notifs.visibleCount; size: 10; weight: Font.Bold; color: "#ffffff" }
                    }
                }
            }
        }

        // ─────────── MEDIA (compact) ───────────
        Page {
            shown: root.mode === "media"
            ArtImage {
                id: miniArt
                x: 7
                anchors.verticalCenter: parent.verticalCenter
                width: 25; height: 25
                radius: Config.s.spinArt ? 12.5 : 7
                source: Hub.artUrl
                RotationAnimator on rotation {
                    from: 0; to: 360; duration: 9000
                    loops: Animation.Infinite
                    running: Config.s.spinArt && Hub.playing && root.mode === "media" && !Theme.reduced
                }
            }
            Marquee {
                anchors.left: miniArt.right
                anchors.leftMargin: 10
                anchors.right: inlineTime.visible ? inlineTime.left : miniViz.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: Hub.player ? (Hub.player.trackTitle || Hub.player.identity) : ""
                size: 12.5
                weight: Font.DemiBold
                color: Hub.playing ? Theme.fg : Theme.fg2
                running: root.mode === "media"
            }
            Txt {
                id: inlineTime
                visible: root.inlineClock
                anchors.right: miniViz.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: Hub.clockText
                size: 13
                weight: Font.DemiBold
                color: Theme.fg
            }
            Visualizer {
                id: miniViz
                visible: Hub.playing
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                count: 5
                maxHeight: 15
            }
            Icon {
                visible: !Hub.playing
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "pause"; size: 17; fill: 1; color: Theme.fg2
            }
        }

        // ─────────── MEDIA PEEK (iOS expanded live activity) ───────────
        Page {
            shown: root.mode === "mediaPeek"
            ArtImage {
                id: peekArt
                x: 18; y: 18
                width: 62; height: 62; radius: 15
                source: Hub.artUrl
                scale: Hub.playing ? 1 : 0.9
                Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }
            }
            Column {
                anchors.left: peekArt.right
                anchors.leftMargin: 14
                anchors.right: peekViz.left
                anchors.rightMargin: 12
                anchors.verticalCenter: peekArt.verticalCenter
                spacing: 2
                Marquee {
                    width: parent.width
                    text: Hub.player ? (Hub.player.trackTitle || "Unknown") : ""
                    size: 15
                    weight: Font.DemiBold
                    running: root.mode === "mediaPeek"
                }
                Txt {
                    width: parent.width
                    text: Hub.player ? (Hub.player.trackArtist || Hub.player.identity) : ""
                    size: 13
                    color: Theme.fg2
                }
            }
            Visualizer {
                id: peekViz
                anchors.right: parent.right
                anchors.rightMargin: 22
                anchors.verticalCenter: peekArt.verticalCenter
                count: 6
                maxHeight: 22
                barWidth: 3.5
            }
            RowLayout {
                x: 18; y: 96
                width: parent.width - 36
                spacing: 10
                Txt { text: Hub.player ? Hub.fmtTime(Hub.player.position) : "0:00"; size: 10.5; color: Theme.fg2; Layout.preferredWidth: 34 }
                SliderBar {
                    Layout.fillWidth: true
                    barHeight: 5
                    value: Hub.progress
                    color: Theme.fg
                    interactive: Hub.player !== null && Hub.player.canSeek
                    onCommitted: v => { if (Hub.player) Hub.player.position = v * Hub.player.length; }
                }
                Txt {
                    text: Hub.player && Hub.player.length > 0 ? "-" + Hub.fmtTime(Hub.player.length - Hub.player.position) : ""
                    size: 10.5; color: Theme.fg2
                    Layout.preferredWidth: 38
                    horizontalAlignment: Text.AlignRight
                }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 120
                spacing: 18
                IconButton { icon: "fast_rewind"; size: 28; pad: 6; fill: 1; enabled: !!(Hub.player && Hub.player.canGoPrevious); onClicked: Hub.player.previous() }
                IconButton { icon: Hub.playing ? "pause" : "play_arrow"; size: 34; pad: 5; fill: 1; onClicked: Hub.player.togglePlaying() }
                IconButton { icon: "fast_forward"; size: 28; pad: 6; fill: 1; enabled: !!(Hub.player && Hub.player.canGoNext); onClicked: Hub.player.next() }
            }
        }

        // ─────────── TIMER / STOPWATCH (compact) ───────────
        Page {
            id: tCompact
            shown: root.mode === "timer" || root.mode === "stopwatch"
            readonly property bool sw: root.mode === "stopwatch"
            readonly property color tint: sw ? Theme.green : Theme.orange
            Item {
                x: 9
                width: 22; height: 22
                anchors.verticalCenter: parent.verticalCenter
                Ring {
                    anchors.fill: parent
                    thickness: 3
                    color: tCompact.tint
                    value: tCompact.sw ? (Hub.swElapsed % 60000) / 60000 : Hub.timerLeft / Math.max(1, Hub.timerTotal)
                }
                Icon {
                    anchors.centerIn: parent
                    text: tCompact.sw ? "timer" : (Hub.timerRunning ? "hourglass_top" : "pause")
                    size: 11; fill: 1
                    color: tCompact.tint
                }
            }
            Txt {
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: tCompact.sw ? Hub.fmtSw(Hub.swElapsed) : Hub.fmtTime(Hub.timerLeft)
                size: 15
                weight: Font.DemiBold
                color: tCompact.tint
            }
        }

        // ─────────── TIMER / STOPWATCH PEEK ───────────
        Page {
            id: tPeek
            shown: root.mode === "timerPeek" || root.mode === "stopwatchPeek"
            readonly property bool sw: root.mode === "stopwatchPeek"
            readonly property color tint: sw ? Theme.green : Theme.orange
            Row {
                x: 18
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                RoundBtn {
                    icon: (tPeek.sw ? Hub.swRunning : Hub.timerRunning) ? "pause" : "play_arrow"
                    tint: tPeek.tint
                    onClicked: tPeek.sw ? Hub.swToggle() : Hub.timerToggle()
                }
                RoundBtn {
                    icon: "close"
                    tinted: false
                    onClicked: tPeek.sw ? Hub.swReset() : Hub.timerReset()
                }
            }
            Column {
                anchors.right: parent.right
                anchors.rightMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                Txt {
                    anchors.right: parent.right
                    text: tPeek.sw ? "Stopwatch" : (Hub.timerRunning ? "Timer" : "Paused")
                    size: 12; color: tPeek.tint; weight: Font.DemiBold
                }
                Txt {
                    anchors.right: parent.right
                    text: tPeek.sw ? Hub.fmtSw(Hub.swElapsed) : Hub.fmtTime(Hub.timerLeft)
                    size: 34; weight: Font.Normal
                    color: tPeek.tint
                }
            }
        }

        // ─────────── RECORDING ───────────
        Page {
            shown: root.mode === "recording"
            PulseDot { x: 16; anchors.verticalCenter: parent.verticalCenter; color: Theme.red }
            Txt {
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: Hub.fmtTime(Hub.recordSeconds)
                size: 14; weight: Font.DemiBold; color: Theme.red
            }
        }
        Page {
            shown: root.mode === "recordingPeek"
            RoundBtn { x: 16; anchors.verticalCenter: parent.verticalCenter; icon: "stop"; tint: Theme.red; onClicked: Hub.stopRecording() }
            Column {
                x: 72
                anchors.verticalCenter: parent.verticalCenter
                Txt { text: "Screen Recording"; size: 14; weight: Font.DemiBold }
                Txt { text: "Click to stop"; size: 11.5; color: Theme.fg2 }
            }
            Txt {
                anchors.right: parent.right
                anchors.rightMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                text: Hub.fmtTime(Hub.recordSeconds)
                size: 24; color: Theme.red
            }
        }

        // ─────────── OSD ───────────
        Page {
            shown: root.mode === "osd"
            Icon {
                id: osdIcon
                x: 18
                anchors.verticalCenter: parent.verticalCenter
                text: Hub.eventIcon
                size: 22
                fill: 1
                color: Hub.eventTinted ? Hub.eventColor : Theme.fg
                scale: root.mode === "osd" ? 1 : 0.6
                Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
            }
            SliderBar {
                visible: Hub.eventValue >= 0
                anchors.left: osdIcon.right
                anchors.leftMargin: 14
                anchors.right: osdPct.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                value: Hub.eventValue
                barHeight: 7
                color: Hub.eventTinted ? Hub.eventColor : Theme.fg
                interactive: Hub.eventIcon.startsWith("volume")
                onMoved: v => Hub.setVolume(v)
            }
            Txt {
                id: osdPct
                visible: Hub.eventValue >= 0
                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                horizontalAlignment: Text.AlignRight
                text: Math.round(Hub.eventValue * 100)
                size: 12.5
                weight: Font.DemiBold
                color: Theme.fg2
            }
            Txt {
                visible: Hub.eventValue < 0
                anchors.left: osdIcon.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                text: Hub.eventLabel
                size: 13.5
                weight: Font.DemiBold
                color: Hub.eventTinted ? Hub.eventColor : Theme.fg
            }
        }

        // ─────────── DEVICE CONNECTED (AirPods-style) ───────────
        Page {
            shown: root.mode === "device"
            Rectangle {
                id: devIcon
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 46; height: 46; radius: 23
                color: Theme.fill2
                Icon { anchors.centerIn: parent; text: Hub.eventIcon; size: 24; fill: 1 }
            }
            Column {
                anchors.left: devIcon.right
                anchors.leftMargin: 12
                anchors.right: devRing.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                Txt { text: Hub.eventSub; size: 11.5; color: Theme.fg2 }
                Txt { width: parent.width; text: Hub.eventLabel; size: 15; weight: Font.DemiBold }
            }
            Item {
                id: devRing
                visible: Hub.eventValue >= 0
                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                width: 40; height: 40
                Ring { anchors.fill: parent; thickness: 4; value: Hub.eventValue; color: Hub.eventValue < 0.2 ? Theme.red : Theme.green }
                Txt { anchors.centerIn: parent; text: Math.round(Hub.eventValue * 100); size: 11; weight: Font.DemiBold }
            }
        }

        // ─────────── WORKSPACE ───────────
        Page {
            shown: root.mode === "workspace"
            Row {
                id: wsRow
                anchors.centerIn: parent
                spacing: 12
                Txt { text: Hub.wsId; size: 14; weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                Row {
                    spacing: 5
                    anchors.verticalCenter: parent.verticalCenter
                    Repeater {
                        model: Hub.wsCount
                        Rectangle {
                            required property int index
                            readonly property bool active: Hub.wsId === index + 1
                            readonly property bool occupied: Hub.occupied.indexOf(index + 1) >= 0
                            anchors.verticalCenter: parent.verticalCenter
                            height: 7
                            width: active ? 24 : 7
                            radius: 3.5
                            color: active ? Theme.accent : occupied ? Theme.fg2 : Theme.fg3
                            Behavior on width { SpringAnimation { spring: 5; damping: 0.38 } }
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                    }
                }
            }
        }

        // ─────────── LAUNCHER (Super+Space) ───────────
        Page {
            shown: root.mode === "launcher"
            LauncherPage {
                id: launcherPage
                anchors.fill: parent
                active: root.isLauncher
            }
        }

        // ─────────── NOTIFICATION (island style) ───────────
        Page {
            shown: root.mode === "notif"
            NotifCard {
                id: notifCard
                x: 14; y: 12
                width: parent.width - 28
                notif: root.notif
                variant: "island"
                showActions: hover.hovered
            }
        }

        // ─────────── EXPANDED DASHBOARD ───────────
        Page {
            shown: root.mode === "expanded"

            // blurred album art behind the Media tab
            Item {
                anchors.fill: parent
                opacity: Hub.tab === 1 && Hub.artUrl !== "" ? (Theme.dark ? 0.5 : 0.35) : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 500 } }
                Image {
                    id: bgArt
                    anchors.fill: parent
                    source: Hub.artUrl
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 160
                    sourceSize.height: 160
                    asynchronous: true
                    visible: false
                }
                MultiEffect {
                    anchors.fill: parent
                    source: bgArt
                    blurEnabled: true
                    blurMax: 64
                    blur: 1
                    saturation: 0.3
                }
            }

            Item {
                id: header
                x: 20; y: 14
                width: parent.width - 40
                height: 34

                Segmented {
                    anchors.centerIn: parent
                    width: 400
                    itemHeight: 30
                    currentIndex: Hub.tab
                    model: [
                        { label: "Home", icon: "home" },
                        { label: "Media", icon: "music_note" },
                        { label: "Controls", icon: "toggle_on" },
                        { label: "Timer", icon: "timer" }
                    ]
                    onActivated: i => Hub.tab = i
                }
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Item {
                        width: bell.width; height: bell.height
                        IconButton { id: bell; icon: "notifications"; size: 19; pad: 7; onClicked: Notifs.toggleCenter(root.screenName) }
                        Rectangle {
                            visible: Notifs.visibleCount > 0
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.rightMargin: 2
                            height: 15; radius: 7.5
                            width: Math.max(15, bc.implicitWidth + 8)
                            color: Theme.red
                            Txt { id: bc; anchors.centerIn: parent; text: Notifs.visibleCount > 99 ? "99+" : Notifs.visibleCount; size: 9.5; weight: Font.Bold; color: "#ffffff" }
                        }
                    }
                    IconButton { icon: "settings"; size: 19; pad: 7; onClicked: Hub.openSettings() }
                }
                Txt {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: Hub.clockTextSec
                    size: 14
                    weight: Font.DemiBold
                    color: Theme.fg2
                    visible: Hub.tab !== 0 && tray.count === 0
                }
                // system tray: left of the tab switcher
                TrayStrip {
                    id: tray
                    visible: count > 0
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    maxWidth: (parent.width - 400) / 2 - 8
                    onActivated: Hub.expanded = false
                }
            }

            Item {
                id: tabArea
                x: 20
                y: 62
                width: root.expandedWidth - 40
                height: 420
                TabPage { index: 0; height: root.tabHeights[0] - 82; HomeTab { anchors.fill: parent; screenName: root.screenName } }
                TabPage { index: 1; height: root.tabHeights[1] - 82; MediaTab { anchors.fill: parent } }
                TabPage { index: 2; height: root.tabHeights[2] - 82; ControlsTab { anchors.fill: parent } }
                TabPage { index: 3; height: root.tabHeights[3] - 82; TimerTab { anchors.fill: parent } }
            }
        }
    }

    // ═══════════ CLOCK BUBBLE (time stays visible while music/timers run) ═══════════
    readonly property real surfaceRadius: surface.r
    property alias clockBubble: clockItem
    Item {
        id: clockItem
        readonly property bool shown: root.clockSplit
        width: clockRow.implicitWidth + 30
        height: 38
        anchors.verticalCenter: parent.verticalCenter
        // springs out of the island's left edge, like iOS splitting into two pills
        x: shown ? -width - 8 : 6
        scale: shown ? 1 : 0.4
        opacity: shown ? 1 : 0
        visible: opacity > 0.01
        Behavior on x { SpringAnimation { spring: Theme.spring; damping: Theme.damping } }
        Behavior on scale { SpringAnimation { spring: Theme.spring; damping: Theme.damping + 0.1 } }
        Behavior on opacity { NumberAnimation { duration: 220 } }
        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Glass { anchors.fill: parent; radius: 19; shadowBlur: 18; shadowY: 4 }
        Row {
            id: clockRow
            anchors.centerIn: parent
            spacing: 6
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: Hub.clockTextSec
                size: 13.5
                weight: Font.DemiBold
            }
            Rectangle {
                visible: Config.s.showPrivacy && (Hub.micInUse || Hub.camInUse)
                anchors.verticalCenter: parent.verticalCenter
                width: 7; height: 7; radius: 3.5
                color: Hub.camInUse ? Theme.green : Theme.orange
            }
            Row {
                visible: Hub.hasBattery && Config.s.showBattery
                spacing: 2
                anchors.verticalCenter: parent.verticalCenter
                Txt { text: Math.round(Hub.batPct * 100); size: 11; color: Theme.fg2; anchors.verticalCenter: parent.verticalCenter }
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Hub.batteryIcon; size: 15; fill: 1; rotation: 90
                    color: Hub.batCharging ? Theme.green : Hub.batPct < 0.2 ? Theme.red : Theme.fg
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Hub.openTab(root.screenName, 0)
        }
    }

    // ═══════════ SPLIT BUBBLE (second live activity, iOS style) ═══════════
    property alias bubble: bubbleItem
    Item {
        id: bubbleItem
        readonly property bool shown: root.secondary !== "" && root.compact && root.primary !== ""
        width: 38; height: 38
        anchors.verticalCenter: parent.verticalCenter
        x: shown ? root.width + 8 : root.width - 40
        scale: shown ? 1 : 0.4
        opacity: shown ? 1 : 0
        visible: opacity > 0.01
        Behavior on x { SpringAnimation { spring: Theme.spring; damping: Theme.damping } }
        Behavior on scale { SpringAnimation { spring: Theme.spring; damping: Theme.damping + 0.1 } }
        Behavior on opacity { NumberAnimation { duration: 220 } }

        Glass {
            anchors.fill: parent
            radius: 19
            shadowBlur: 18
            shadowY: 4
            glowColor: root.secondary === "recording" ? Theme.red : root.secondary === "timer" ? Theme.orange : Theme.live
            glowStrength: Config.s.glow ? 0.25 : 0
        }
        ArtImage {
            visible: root.secondary === "media"
            anchors.centerIn: parent
            width: 26; height: 26; radius: 13
            source: Hub.artUrl
            RotationAnimator on rotation {
                from: 0; to: 360; duration: 9000; loops: Animation.Infinite
                running: bubbleItem.shown && root.secondary === "media" && Hub.playing && Config.s.spinArt && !Theme.reduced
            }
        }
        Item {
            visible: root.secondary === "timer" || root.secondary === "stopwatch"
            anchors.centerIn: parent
            width: 24; height: 24
            Ring {
                anchors.fill: parent
                thickness: 3
                color: root.secondary === "stopwatch" ? Theme.green : Theme.orange
                value: root.secondary === "stopwatch" ? (Hub.swElapsed % 60000) / 60000 : Hub.timerLeft / Math.max(1, Hub.timerTotal)
            }
            Icon {
                anchors.centerIn: parent
                text: "timer"; size: 11; fill: 1
                color: root.secondary === "stopwatch" ? Theme.green : Theme.orange
            }
        }
        PulseDot { visible: root.secondary === "recording"; anchors.centerIn: parent; color: Theme.red }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Hub.openActivity(root.secondary, root.screenName)
        }
    }
}
