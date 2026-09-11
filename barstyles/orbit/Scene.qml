pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

import shell.services
import shell.barkit as Pill

import "components" as Orbit
import "popouts" as Popout

Scope {
    id: root

    property var modelData: null
    property string selectedPopup: ""
    property date now: new Date()

    readonly property real workspaceAnchor:
        workspaceStrip.x + 45

    readonly property real mediaAnchor:
        clockCore.x + clockCore.width / 2

    readonly property real popupAnchor: {
        if (root.selectedPopup === "network")
            return rightBand.x + systemCluster.x + networkNode.x + networkNode.width / 2;
        if (root.selectedPopup === "bluetooth")
            return rightBand.x + systemCluster.x + bluetoothNode.x + bluetoothNode.width / 2;
        if (root.selectedPopup === "audio")
            return rightBand.x + systemCluster.x + audioNode.x + audioNode.width / 2;
        if (root.selectedPopup === "battery")
            return rightBand.x + systemCluster.x + batteryNode.x + batteryNode.width / 2;
        if (root.selectedPopup === "media")
            return clockCore.x + clockCore.width / 2;
        return rightBand.x + systemCluster.x + audioNode.x + audioNode.width / 2;
    }


    readonly property bool mediaWide:
        Media.present &&
        root.modelData !== null &&
        root.modelData.width >= 1150

    readonly property string timeText: Qt.formatTime(root.now, "HH:mm")
    readonly property string dateText: Qt.formatDate(root.now, "ddd d MMM").toUpperCase()

    readonly property string activeTitle: {
        const tl = Hyprland.activeToplevel;
        if (!tl || !tl.lastIpcObject)
            return "";

        return String(tl.lastIpcObject.title || "");
    }

    readonly property var mediaPlayer: Media.player

    readonly property string mediaArtist:
        root.mediaPlayer
            ? Theme.joinArtists(root.mediaPlayer.trackArtists, root.mediaPlayer.trackArtist)
            : ""

    readonly property real mediaLength: root.mediaPlayer ? root.mediaPlayer.length : 0
    readonly property real mediaPosition: root.mediaPlayer ? root.mediaPlayer.position : 0

    readonly property real mediaFraction:
        root.mediaLength > 0
            ? Math.max(0, Math.min(1, root.mediaPosition / root.mediaLength))
            : 0

    readonly property var sink: Audio.sink
    readonly property bool audioAvailable: !!(root.sink && root.sink.audio)
    readonly property bool audioMuted: root.audioAvailable && root.sink.audio.muted
    readonly property int audioVolume:
        root.audioAvailable ? Math.round(root.sink.audio.volume * 100) : 0

    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btOn: root.btAdapter !== null && root.btAdapter.enabled

    readonly property int btConnected: {
        if (!root.btOn || !Bluetooth.devices)
            return 0;

        const devices = Bluetooth.devices.values || [];
        let count = 0;

        for (let i = 0; i < devices.length; ++i) {
            if (devices[i] && devices[i].connected)
                ++count;
        }

        return count;
    }

    function occupied(workspaceId) {
        const toplevels = Hyprland.toplevels ? Hyprland.toplevels.values : [];

        for (let i = 0; i < toplevels.length; ++i) {
            const object = toplevels[i] && toplevels[i].lastIpcObject
                ? toplevels[i].lastIpcObject
                : {};

            if (object.workspace && object.workspace.id === workspaceId)
                return true;
        }

        return false;
    }

    function focusWorkspace(workspaceId) {
        root.selectedPopup = "";

        Hyprland.dispatch(
            'hl.dsp.focus({ workspace = "' + workspaceId + '" })'
        );
    }

    function togglePopup(name) {
        root.selectedPopup = root.selectedPopup === name ? "" : name;
    }

    function networkIcon() {
        if (Network.vpnActive)
            return "vpn_lock";
        if (Network.kind === "ethernet")
            return "lan";
        if (Network.kind === "wifi")
            return "wifi";

        return "signal_wifi_off";
    }

    function networkLabel() {
        if (Network.vpnActive)
            return "VPN";
        if (Network.kind === "ethernet")
            return "LAN";
        if (Network.kind === "wifi")
            return Math.round(Network.level * 100) + "%";

        return "OFF";
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    Timer {
        interval: 500
        running: Media.present && Media.playing && root.mediaPlayer !== null
        repeat: true

        onTriggered: {
            if (root.mediaPlayer)
                root.mediaPlayer.positionChanged();
        }
    }

    PanelWindow {
        screen: root.modelData
        visible: root.modelData !== null
        color: "transparent"
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 44
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "ryoku-orbit-reserve"
        anchors { top: true; left: true; right: true }
        implicitHeight: 44
        mask: Region {}
    }

    PanelWindow {
        id: overlay

        screen: root.modelData
        visible: root.modelData !== null
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "ryoku-orbit"
        anchors { top: true; bottom: true; left: true; right: true }

        mask: root.selectedPopup.length > 0 ? fullInput : barInput

        Region {
            id: fullInput
            width: overlay.width
            height: overlay.height
        }

        Region {
            id: barInput

            Region { item: workspaceStrip }

            Region {
                x: clockCore.x
                y: clockCore.y
                width: root.mediaWide ? clockCore.width : 0
                height: root.mediaWide ? clockCore.height : 0
            }

            Region { item: rightBand }
        }

        MouseArea {
            anchors.fill: parent
            visible: root.selectedPopup.length > 0
            enabled: root.selectedPopup.length > 0
            acceptedButtons: Qt.AllButtons
            z: 10
            onPressed: root.selectedPopup = ""
        }

        Orbit.OrbitTrajectory {
            id: trajectory

            x: 18
            y: 25
            width: Math.max(0, overlay.width - 36)
            height: 1

            mediaCenter:
                root.mediaAnchor - x

            workspaceCenter:
                root.workspaceAnchor - x

            targetCenter:
                root.popupAnchor - x

            mediaProgress:
                root.mediaFraction

            mediaPlaying:
                Media.playing &&
                root.mediaLength > 0 &&
                !Media.radio

            engaged:
                root.selectedPopup.length > 0

            z: 1
        }

        Rectangle {
            x: 14
            y: 22
            width: 7
            height: 7
            radius: 4
            color: Theme.primary
            z: 2
        }

        Rectangle {
            x: overlay.width - 21
            y: 22
            width: 7
            height: 7
            radius: 4
            color: Theme.primary
            z: 2
        }

        Rectangle {
            x: 14
            y: 22
            width: 7
            height: 7
            radius: 4
            color: Theme.primary
            z: 2
        }

        Rectangle {
            x: overlay.width - 21
            y: 22
            width: 7
            height: 7
            radius: 4
            color: Theme.primary
            z: 2
        }

        Row {
            id: workspaceStrip

            x: 30
            y: 10
            height: 32
            spacing: 1
            z: 20

            Repeater {
                model: 5

                delegate: Item {
                    id: workspaceNode
                    required property int index

                    readonly property int workspaceId: index + 1
                    readonly property bool active: Workspaces.activeId === workspaceId
                    readonly property bool hasWindows: root.occupied(workspaceId)

                    width: 30
                    height: 32

                    Rectangle {
                        anchors.centerIn: parent
                        width: workspaceNode.active
                            ? 24
                            : workspaceNode.hasWindows
                                ? 11
                                : 6

                        height: width
                        radius: width / 2

                        color: workspaceNode.active
                            ? Theme.primary
                            : workspaceNode.hasWindows
                                ? Theme.threadBg
                                : Theme.surface

                        border.width: workspaceNode.active ? 0 : 1
                        border.color: workspaceNode.hasWindows
                            ? Theme.primary
                            : Theme.outlineVariant

                        scale: workspaceHover.hovered ? 1.16 : 1

                        Behavior on width {
                            NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
                        }

                        Behavior on scale {
                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: workspaceNode.active
                            text: workspaceNode.workspaceId
                            color: Theme.onPrimary
                            font.family: Theme.mono
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }
                    }

                    HoverHandler { id: workspaceHover }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.focusWorkspace(workspaceNode.workspaceId)
                    }
                }
            }
        }

        Rectangle {
            id: clockCore

            anchors.horizontalCenter: parent.horizontalCenter
            y: 6
            width:
                root.mediaWide
                    ? root.selectedPopup === "media"
                        ? 372
                        : 430
                    : 166
            height: 40
            radius: 20
            z: 20

            color: coreHover.hovered && root.mediaWide
                ? Theme.surfaceContainerLow
                : Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.97)

            border.width: 1
            border.color: root.selectedPopup === "media"
                ? Theme.primary
                : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.56)

            scale: coreHover.hovered && root.mediaWide ? 1.012 : 1

            Behavior on width {
                NumberAnimation { duration: 230; easing.type: Easing.OutCubic }
            }

            Behavior on color { ColorAnimation { duration: 140 } }

            Behavior on scale {
                NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
            }

            Row {
                visible: !root.mediaWide
                anchors.centerIn: parent
                spacing: 9

                Text {
                    text: root.timeText
                    color: Theme.onSurface
                    font.family: Theme.mono
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: 13
                    color: Theme.outlineVariant
                }

                Text {
                    text: root.dateText
                    color: Theme.onSurfaceVariant
                    font.family: Theme.fontPrimary
                    font.pixelSize: 10
                    font.weight: Font.Medium
                }
            }

            Item {
                visible: root.mediaWide
                anchors.fill: parent

                ClippingRectangle {
                    x: 6
                    y: 6
                    width: 28
                    height: 28
                    radius: 8
                    color: Theme.surfaceContainer

                    Pill.MaterialIcon {
                        anchors.centerIn: parent
                        visible: coreArt.status !== Image.Ready
                        text: "music_note"
                        color: Theme.onSurfaceVariant
                        font.pixelSize: 15
                    }

                    Image {
                        id: coreArt
                        anchors.fill: parent
                        source: root.mediaPlayer ? (root.mediaPlayer.trackArtUrl || "") : ""
                        asynchronous: true
                        smooth: true
                        cache: true
                        fillMode: Image.PreserveAspectCrop
                    }
                }

                Column {
                    x: 42
                    y: 5

                    opacity:
                        root.selectedPopup === "media"
                            ? 0.58
                            : 1

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 170
                            easing.type: Easing.OutCubic
                        }
                    }
                    width: 250
                    spacing: 0

                    Text {
                        width: parent.width
                        text: root.mediaPlayer
                            ? (root.mediaPlayer.trackTitle || "Nothing playing")
                            : "Nothing playing"

                        elide: Text.ElideRight
                        color: Theme.onSurface
                        font.family: Theme.fontPrimary
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }

                    Text {
                        width: parent.width
                        text: root.mediaArtist
                        elide: Text.ElideRight
                        color: Theme.onSurfaceVariant
                        font.family: Theme.fontPrimary
                        font.pixelSize: 8
                    }
                }

                Rectangle {
                    x: 42
                    y: 34
                    width: 250
                    height: 2
                    radius: 1
                    visible: root.mediaLength > 0 && !Media.radio
                    color: Theme.outlineVariant

                    Rectangle {
                        width: parent.width * root.mediaFraction
                        height: parent.height
                        radius: parent.radius
                        color: Theme.primary

                        Behavior on width {
                            NumberAnimation { duration: 90; easing.type: Easing.Linear }
                        }
                    }
                }

                Orbit.OrbitEqualizer {
                    x: 334

                    anchors.verticalCenter:
                        parent.verticalCenter

                    running:
                        Media.playing

                    accentColor:
                        Media.playing
                            ? Theme.primary
                            : Theme.onSurfaceVariant

                    opacity:
                        Media.present
                            ? 1
                            : 0.35
                }

                Rectangle {
                    x: 334
                    y: 9

                    visible:
                        root.selectedPopup !== "media"
                    width: 1
                    height: 22
                    color: Theme.outlineVariant
                }

                Column {
                    x: 346
                    y: 5

                    visible:
                        root.selectedPopup !== "media"
                    width: 72
                    spacing: -1

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: root.timeText
                        color: Theme.onSurface
                        font.family: Theme.mono
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: root.dateText
                        color: Theme.onSurfaceVariant
                        font.family: Theme.fontPrimary
                        font.pixelSize: 7
                    }
                }
            }

            HoverHandler {
                id: coreHover
                cursorShape: root.mediaWide ? Qt.PointingHandCursor : Qt.ArrowCursor
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.mediaWide
                cursorShape: Qt.PointingHandCursor
                onClicked: root.togglePopup("media")
            }
        }

        Text {
            visible:
                overlay.width >= 1000 &&
                (rightBand.x - (clockCore.x + clockCore.width)) > 130

            anchors {
                left: clockCore.right
                leftMargin: 28
                right: rightBand.left
                rightMargin: 20
                verticalCenter: clockCore.verticalCenter
            }

            text: root.activeTitle.length > 0 ? root.activeTitle : "DESKTOP"
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignRight
            color: Theme.onSurfaceVariant
            opacity: 0.68
            font.family: Theme.fontPrimary
            font.pixelSize: 10
            font.weight: Font.Medium
            z: 5
        }

        Row {
            id: rightBand

            anchors {
                right: parent.right
                rightMargin: 28
                verticalCenter: clockCore.verticalCenter
            }

            spacing: 10
            z: 20

            Orbit.TrayStrip {
                allow: overlay.width >= 1000
            }

            Row {
                id: systemCluster
                spacing: 2

                Orbit.OrbitNode {
                    id: networkNode

                    icon: root.networkIcon()
                    label: root.networkLabel()
                    active: Network.kind.length > 0 || Network.vpnActive
                    warning: Network.kind.length === 0
                    selected: root.selectedPopup === "network"

                    onActivated: root.togglePopup("network")
                }

                Orbit.OrbitNode {
                    id: bluetoothNode

                    icon: root.btConnected > 0 ? "bluetooth_connected" : "bluetooth"
                    label: root.btConnected > 0
                        ? root.btConnected + " DEV"
                        : root.btOn
                            ? "ON"
                            : "OFF"

                    active: root.btOn
                    selected: root.selectedPopup === "bluetooth"
                    opacity: root.btAdapter !== null ? 1 : 0.38
                    clickable: root.btAdapter !== null

                    onActivated: root.togglePopup("bluetooth")
                }

                Orbit.OrbitNode {
                    id: audioNode

                    icon: root.audioMuted ? "volume_off" : "volume_up"
                    label: root.audioAvailable
                        ? root.audioMuted
                            ? "MUTE"
                            : root.audioVolume + "%"
                        : "--"

                    active: root.audioAvailable && !root.audioMuted
                    warning: root.audioMuted
                    selected: root.selectedPopup === "audio"
                    clickable: root.audioAvailable

                    onActivated: root.togglePopup("audio")
                }

                Orbit.OrbitNode {
                    id: batteryNode

                    visible: Battery.present
                    icon: Battery.charging ? "battery_charging_full" : "battery_full"
                    label: Battery.pct + "%"
                    active: Battery.present && !Battery.low
                    warning: Battery.low
                    selected: root.selectedPopup === "battery"

                    onActivated: root.togglePopup("battery")
                }
            }
        }

        Popout.MediaPopout {
            z: 30
            open: root.selectedPopup === "media"
            anchorX: clockCore.x + clockCore.width / 2
            availableWidth: overlay.width
        }

        Popout.NetworkPopout {
            z: 30
            open: root.selectedPopup === "network"
            anchorX: rightBand.x + systemCluster.x + networkNode.x + networkNode.width / 2
            availableWidth: overlay.width
        }

        Popout.BluetoothPopout {
            z: 30
            open: root.selectedPopup === "bluetooth"
            anchorX: rightBand.x + systemCluster.x + bluetoothNode.x + bluetoothNode.width / 2
            availableWidth: overlay.width
        }

        Popout.AudioPopout {
            z: 30
            open: root.selectedPopup === "audio"
            anchorX: rightBand.x + systemCluster.x + audioNode.x + audioNode.width / 2
            availableWidth: overlay.width
        }

        Popout.BatteryPopout {
            z: 30
            open: root.selectedPopup === "battery"
            anchorX: rightBand.x + systemCluster.x + batteryNode.x + batteryNode.width / 2
            availableWidth: overlay.width
        }
    }
}
