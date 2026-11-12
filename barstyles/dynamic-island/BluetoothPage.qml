pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell.Bluetooth

// Bluetooth menu (Control Center drill-down). Scans while open.
// Click a paired device to connect/disconnect, click a new one to pair.
Item {
    id: root

    Item {
        id: header
        width: parent.width
        height: 36
        IconButton { id: backBtn; icon: "chevron_left"; size: 22; pad: 5; anchors.verticalCenter: parent.verticalCenter; onClicked: Hub.ccPage = "" }
        Txt { anchors.left: backBtn.right; anchors.leftMargin: 4; anchors.verticalCenter: parent.verticalCenter; text: "Bluetooth"; size: 18; weight: Font.Bold }
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Icon {
                visible: Hub.btScanning
                anchors.verticalCenter: parent.verticalCenter
                text: "progress_activity"; size: 18; color: Theme.fg2
                RotationAnimator on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: Hub.btScanning }
            }
            IosSwitch {
                anchors.verticalCenter: parent.verticalCenter
                visible: Hub.btAdapter !== null
                checked: Hub.btOn
                activeColor: Theme.ccTint(Theme.green)
                onToggled: v => { Hub.setBt(v); if (v) scanLater.restart(); }
            }
        }
        Timer { id: scanLater; interval: 1200; onTriggered: Hub.btScan(Hub.btMenuOpen) }
    }

    Rectangle {
        id: errBox
        visible: Hub.btError !== ""
        anchors.top: header.bottom
        anchors.topMargin: 6
        width: parent.width
        height: visible ? errTxt.implicitHeight + 14 : 0
        radius: 10
        color: Theme.alpha(Theme.red, 0.16)
        Txt { id: errTxt; x: 12; width: parent.width - 24; anchors.verticalCenter: parent.verticalCenter; text: Hub.btError; size: 12; color: Theme.red; wrapMode: Text.Wrap }
    }

    component SectionLabel: Txt {
        x: 12
        height: 28
        size: 11.5
        weight: Font.DemiBold
        color: Theme.fg2
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

                Txt {
                    visible: Hub.btAdapter === null
                    x: 12; width: parent.width - 24
                    topPadding: 14; bottomPadding: 14
                    wrapMode: Text.Wrap
                    text: Hub.deps["bluetooth.service"] === false
                        ? "The Bluetooth service isn't running — enable it in your system's service settings."
                        : "No Bluetooth adapter found."
                    size: 13
                    color: Theme.fg2
                }
                Txt {
                    visible: Hub.btAdapter !== null && !Hub.btOn
                    x: 12; height: 60
                    text: "Bluetooth is off"
                    size: 13.5
                    color: Theme.fg2
                }

                SectionLabel { visible: Hub.btOn && Hub.btPaired.length > 0; text: "My Devices" }
                Repeater {
                    model: Hub.btOn ? Hub.btPaired : []
                    MenuRow {
                        required property var modelData
                        required property int index
                        readonly property bool connected: modelData.connected
                        showSep: index > 0
                        icon: Hub.btIcon(modelData.icon)
                        iconBg: connected ? Theme.ccTint(Theme.blue) : Theme.fill2
                        iconColor: connected ? (Theme.lum(iconBg) > 0.62 ? "#000000" : "#ffffff") : Theme.fg
                        label: modelData.name || modelData.deviceName
                        sub: Hub.btState(modelData)
                        subColor: connected ? Theme.accent : Theme.fg2
                        checked: connected
                        busy: modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting
                        trailingIcon: "delete"
                        onTrailingClicked: Hub.btForget(modelData)
                        onClicked: Hub.btActivate(modelData)
                    }
                }

                SectionLabel { visible: Hub.btOn; text: Hub.btScanning ? "Other Devices — searching…" : "Other Devices" }
                Txt {
                    visible: Hub.btOn && Hub.btOthers.length === 0
                    x: 12; height: 34
                    text: Hub.btScanning ? "Put your device in pairing mode." : "None found."
                    size: 12.5
                    color: Theme.fg3
                }
                Repeater {
                    model: Hub.btOn ? Hub.btOthers : []
                    MenuRow {
                        required property var modelData
                        required property int index
                        showSep: index > 0
                        icon: Hub.btIcon(modelData.icon)
                        label: modelData.name || modelData.deviceName
                        sub: Hub.btPendingAddr === modelData.address ? "Pairing…" : ""
                        busy: Hub.btPendingAddr === modelData.address || modelData.pairing
                        onClicked: Hub.btActivate(modelData)
                    }
                }
            }
        }
    }

    Txt {
        id: footer
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        text: "Bluetooth Settings…"
        size: 12.5
        weight: Font.DemiBold
        color: Theme.accent
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Hub.openFirst(["blueman-manager", "overskride", "blueberry", "kitty -e bluetuith", "kitty -e bluetoothctl"]) }
    }
}
