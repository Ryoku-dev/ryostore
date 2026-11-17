pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

// Wi-Fi menu (Control Center drill-down). Click a network to join it; saved networks
// join straight away, new secured ones ask for the password inline.
Item {
    id: root

    Item {
        id: header
        width: parent.width
        height: 36
        IconButton { id: backBtn; icon: "chevron_left"; size: 22; pad: 5; anchors.verticalCenter: parent.verticalCenter; onClicked: Hub.ccPage = "" }
        Txt { anchors.left: backBtn.right; anchors.leftMargin: 4; anchors.verticalCenter: parent.verticalCenter; text: "Wi-Fi"; size: 18; weight: Font.Bold }
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Icon {
                visible: Hub.wifiScanning && Hub.wifiOn
                anchors.verticalCenter: parent.verticalCenter
                text: "progress_activity"; size: 18; color: Theme.fg2
                RotationAnimator on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: Hub.wifiScanning }
            }
            IconButton { visible: Hub.wifiOn; icon: "refresh"; size: 18; pad: 6; anchors.verticalCenter: parent.verticalCenter; onClicked: Hub.wifiScan() }
            IosSwitch { anchors.verticalCenter: parent.verticalCenter; checked: Hub.wifiOn; activeColor: Theme.ccTint(Theme.green); onToggled: v => Hub.setWifi(v) }
        }
    }

    Rectangle {
        id: errBox
        visible: Hub.wifiError !== ""
        anchors.top: header.bottom
        anchors.topMargin: 6
        width: parent.width
        height: visible ? errTxt.implicitHeight + 14 : 0
        radius: 10
        color: Theme.alpha(Theme.red, 0.16)
        Txt { id: errTxt; x: 12; width: parent.width - 24; anchors.verticalCenter: parent.verticalCenter; text: Hub.wifiError; size: 12; color: Theme.red; wrapMode: Text.Wrap }
    }

    Widget {
        anchors.top: errBox.visible ? errBox.bottom : header.bottom
        anchors.topMargin: 8
        anchors.bottom: footer.top
        anchors.bottomMargin: 8
        width: parent.width
        pad: 6

        Flickable {
            id: flick
            anchors.fill: parent
            contentHeight: col.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 4 }

            Column {
                id: col
                width: flick.width

                MenuRow {
                    visible: Hub.wiredUp
                    icon: "lan"
                    iconBg: Theme.ccTint(Theme.blue)
                    iconColor: Theme.lum(iconBg) > 0.62 ? "#000000" : "#ffffff"
                    label: "Ethernet"
                    sub: "Connected"
                    checked: true
                    showSep: false
                }

                Txt {
                    visible: !Hub.wifiOn
                    x: 12
                    height: 60
                    text: "Wi-Fi is off"
                    size: 13.5
                    color: Theme.fg2
                }
                Txt {
                    visible: Hub.wifiOn && Hub.wifiNetworks.length === 0
                    x: 12
                    height: 60
                    text: Hub.deps.nmcli === false ? "NetworkManager (nmcli) isn't installed" : "Searching for networks…"
                    size: 13.5
                    color: Theme.fg2
                }

                Repeater {
                    model: Hub.wifiOn ? Hub.wifiNetworks : []
                    MenuRow {
                        id: net
                        required property var modelData
                        required property int index
                        readonly property bool asking: Hub.wifiNeedsPassword === modelData.ssid
                        showSep: index > 0 || Hub.wiredUp
                        icon: Hub.signalIcon(modelData.signal)
                        iconBg: modelData.active ? Theme.ccTint(Theme.blue) : Theme.fill2
                        iconColor: modelData.active ? (Theme.lum(iconBg) > 0.62 ? "#000000" : "#ffffff") : Theme.fg
                        label: modelData.ssid
                        sub: Hub.wifiBusy === modelData.ssid ? "Joining…" : modelData.active ? "Connected" : modelData.known ? "Saved" : ""
                        checked: modelData.active
                        locked: modelData.secure
                        busy: Hub.wifiBusy === modelData.ssid
                        trailingIcon: modelData.active ? "link_off" : modelData.known ? "delete" : ""
                        onTrailingClicked: modelData.active ? Hub.wifiDisconnect(modelData) : Hub.wifiForget(modelData)
                        onClicked: {
                            if (net.asking) { Hub.wifiNeedsPassword = ""; return; }
                            Hub.wifiConnect(modelData, "");
                        }
                        onAskingChanged: if (asking) Qt.callLater(() => pw.forceActiveFocus())

                        // password, inline
                        Row {
                            visible: net.asking
                            width: parent.width
                            height: visible ? 44 : 0
                            spacing: 8
                            TextField {
                                id: pw
                                width: parent.width - joinBtn.width - 8
                                height: 34
                                anchors.verticalCenter: parent.verticalCenter
                                leftPadding: 12
                                echoMode: showPw.checked ? TextInput.Normal : TextInput.Password
                                placeholderText: "Password"
                                placeholderTextColor: Theme.fg3
                                color: Theme.fg
                                font.family: Theme.font
                                font.pixelSize: 13
                                selectionColor: Theme.accent
                                background: Rectangle { radius: 10; color: Theme.fill2; border.width: pw.activeFocus ? 1 : 0; border.color: Theme.accent }
                                onAccepted: joinBtn.go()
                                rightPadding: 34
                                IconButton {
                                    id: showPw
                                    property bool checked: false
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    icon: checked ? "visibility_off" : "visibility"
                                    size: 15; pad: 6
                                    color: Theme.fg2
                                    onClicked: checked = !checked
                                }
                            }
                            Rectangle {
                                id: joinBtn
                                width: 64; height: 34; radius: 17
                                anchors.verticalCenter: parent.verticalCenter
                                color: pw.text.length >= 8 ? Theme.accent : Theme.fill2
                                Txt { anchors.centerIn: parent; text: "Join"; size: 13; weight: Font.DemiBold; color: pw.text.length >= 8 ? Theme.accentText : Theme.fg3 }
                                function go() {
                                    if (pw.text.length < 8) return;
                                    Hub.wifiConnect(net.modelData, pw.text);
                                    pw.text = "";
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: joinBtn.go() }
                            }
                        }
                    }
                }
            }
        }
    }

    Row {
        id: footer
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        spacing: 4
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: "Network Settings…"
            size: 12.5
            weight: Font.DemiBold
            color: Theme.accent
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Hub.openFirst(["nm-connection-editor", "kitty -e nmtui", "foot nmtui", "alacritty -e nmtui", "wezterm start nmtui"]) }
        }
    }
}
