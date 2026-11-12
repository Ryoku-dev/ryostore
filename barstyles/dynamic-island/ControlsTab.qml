pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// Control Center: connectivity module (with Wi-Fi / Bluetooth menus), big sliders,
// toggles and power. Active toggles take your theme accent (Settings → Controls).
Item {
    id: root
    clip: true

    component PowerBtn: Rectangle {
        id: pb
        property string icon: ""
        property string label: ""
        property bool confirm: Config.s.confirmPower
        property color armColor: Theme.red
        property bool armed: false
        signal triggered()
        Layout.fillWidth: true
        implicitHeight: 40
        radius: 20
        color: armed ? armColor : pbMa.containsMouse ? Theme.fill2 : Theme.fill
        scale: pbMa.pressed ? 0.94 : 1
        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
        Row {
            anchors.centerIn: parent
            spacing: 6
            Icon { text: pb.armed ? "check" : pb.icon; size: 17; fill: pb.armed ? 1 : 0; color: pb.armed ? "#ffffff" : Theme.fg; anchors.verticalCenter: parent.verticalCenter }
            Txt { text: pb.armed ? "Confirm" : pb.label; size: 12; weight: Font.DemiBold; color: pb.armed ? "#ffffff" : Theme.fg; anchors.verticalCenter: parent.verticalCenter }
        }
        Timer { id: disarm; interval: 2600; onTriggered: pb.armed = false }
        MouseArea {
            id: pbMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (pb.confirm && !pb.armed) { pb.armed = true; disarm.restart(); return; }
                pb.armed = false;
                pb.triggered();
            }
        }
    }

    // ═══════════════════════ MAIN PAGE ═══════════════════════
    Item {
        id: main
        width: root.width
        height: root.height
        readonly property bool shown: Hub.ccPage === ""
        x: shown ? 0 : -root.width * 0.3
        opacity: shown ? 1 : 0
        visible: opacity > 0.01
        enabled: shown
        Behavior on x { NumberAnimation { duration: Theme.reduced ? 1 : 380; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Theme.reduced ? 1 : 240 } }

        ColumnLayout {
            anchors.fill: parent
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 164
                spacing: 12

                // Connectivity module (macOS style)
                Widget {
                    Layout.preferredWidth: 248
                    Layout.fillHeight: true
                    pad: 8
                    Column {
                        anchors.fill: parent
                        spacing: 4
                        CCPill {
                            width: parent.width
                            icon: Hub.wifiOn ? "wifi" : "wifi_off"
                            label: "Wi-Fi"
                            sub: Hub.wifiSub
                            active: Hub.wifiOn
                            activeColor: Theme.ccTint(Theme.blue)
                            onToggled: Hub.toggleWifi()
                            onOpened: Hub.ccPage = "wifi"
                        }
                        CCPill {
                            width: parent.width
                            icon: Hub.btOn ? "bluetooth" : "bluetooth_disabled"
                            label: "Bluetooth"
                            sub: Hub.btAdapter ? Hub.btSub : "Unavailable"
                            active: Hub.btOn
                            activeColor: Theme.ccTint(Theme.blue)
                            onToggled: Hub.toggleBt()
                            onOpened: Hub.ccPage = "bt"
                        }
                        CCPill {
                            width: parent.width
                            icon: "bedtime"
                            label: "Focus"
                            sub: Notifs.dnd ? "Do Not Disturb" : "Off"
                            active: Notifs.dnd
                            activeColor: Theme.ccTint(Theme.indigo)
                            hasMenu: false
                            onToggled: Notifs.toggleDnd()
                        }
                    }
                }

                // Sliders
                Widget {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    pad: 14
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 6
                        RowLayout {
                            Layout.fillWidth: true
                            Txt { text: "Sound"; size: 11; weight: Font.DemiBold; color: Theme.fg2 }
                            Item { Layout.fillWidth: true }
                            Icon { text: Hub.sinkIcon(); size: 14; fill: 1; color: Theme.fg2 }
                            Txt { text: Hub.sinkName; size: 11; color: Theme.fg2; Layout.maximumWidth: 240 }
                        }
                        SliderBar {
                            Layout.fillWidth: true
                            big: true
                            barHeight: 38
                            icon: Hub.volumeIcon
                            value: Hub.muted ? 0 : Hub.volume
                            color: Config.s.ccAccent ? Theme.accent : "#ffffff"
                            onMoved: v => Hub.setVolume(v)
                        }
                        Txt {
                            Layout.topMargin: 4
                            text: Hub.hasBacklight ? "Display" : "Microphone"
                            size: 11; weight: Font.DemiBold; color: Theme.fg2
                        }
                        SliderBar {
                            visible: Hub.hasBacklight
                            Layout.fillWidth: true
                            big: true
                            barHeight: 38
                            icon: "light_mode"
                            value: Hub.brightness
                            color: Config.s.ccAccent ? Theme.accent : "#ffffff"
                            onMoved: v => Hub.setBrightness(v)
                        }
                        SliderBar {
                            visible: !Hub.hasBacklight
                            Layout.fillWidth: true
                            big: true
                            barHeight: 38
                            icon: Hub.micMuted ? "mic_off" : "mic"
                            value: Hub.source && Hub.source.audio && !Hub.micMuted ? Hub.source.audio.volume : 0
                            color: Config.s.ccAccent ? Theme.accent : "#ffffff"
                            onMoved: v => { if (Hub.source && Hub.source.audio) { Hub.source.audio.muted = false; Hub.source.audio.volume = v; } }
                        }
                    }
                }
            }

            // Toggles
            RowLayout {
                Layout.fillWidth: true
                spacing: 0
                CCButton { Layout.fillWidth: true; icon: "nightlight"; label: "Night Shift"; sub: Hub.nightLight ? Config.s.nightLightTemp + "K" : "Off"; active: Hub.nightLight; activeColor: Theme.ccTint("#ff9f45"); onClicked: Hub.toggleNightLight() }
                CCButton { Layout.fillWidth: true; icon: "coffee"; label: "Caffeine"; sub: Hub.caffeine ? "Awake" : "Off"; active: Hub.caffeine; activeColor: Theme.ccTint(Theme.orange); onClicked: Hub.toggleCaffeine() }
                CCButton { Layout.fillWidth: true; icon: "timer"; label: "Timer"; sub: Hub.timerActive ? Hub.fmtTime(Hub.timerLeft) : "25 min"; active: Hub.timerActive; activeColor: Theme.ccTint(Theme.orange); onClicked: Hub.timerActive ? Hub.timerToggle() : Hub.startTimer(1500) }
                CCButton { Layout.fillWidth: true; icon: Hub.micMuted ? "mic_off" : "mic"; label: "Mic"; sub: Hub.micMuted ? "Muted" : "Live"; active: Hub.micMuted; activeColor: Theme.red; onClicked: Hub.toggleMic() }
                CCButton { Layout.fillWidth: true; icon: "screenshot_region"; label: "Screenshot"; onClicked: Hub.screenshot() }
                CCButton { Layout.fillWidth: true; icon: "colorize"; label: "Colour"; onClicked: Hub.colorPick() }
                CCButton { Layout.fillWidth: true; icon: "settings"; label: "Settings"; onClicked: Hub.openSettings() }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                PowerBtn { icon: "lock"; label: "Lock"; confirm: false; onTriggered: Hub.session("lock") }
                PowerBtn { icon: "dark_mode"; label: "Sleep"; armColor: Theme.indigo; onTriggered: Hub.session("suspend") }
                PowerBtn { icon: "logout"; label: "Log Out"; armColor: Theme.orange; onTriggered: Hub.session("logout") }
                PowerBtn { icon: "restart_alt"; label: "Restart"; armColor: Theme.orange; onTriggered: Hub.session("reboot") }
                PowerBtn { icon: "power_settings_new"; label: "Shut Down"; onTriggered: Hub.session("shutdown") }
            }
        }
    }

    // ═══════════════════════ DRILL-DOWN PAGES ═══════════════════════
    component SubPage: Item {
        id: sp
        property string page: ""
        readonly property bool shown: Hub.ccPage === page
        x: shown ? 0 : width
        opacity: shown ? 1 : 0
        visible: opacity > 0.01
        enabled: shown
        Behavior on x { NumberAnimation { duration: Theme.reduced ? 1 : 380; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Theme.reduced ? 1 : 240 } }
    }
    SubPage { page: "wifi"; width: root.width; height: root.height; WifiPage { anchors.fill: parent } }
    SubPage { page: "bt"; width: root.width; height: root.height; BluetoothPage { anchors.fill: parent } }
}
