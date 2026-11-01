pragma ComponentBehavior: Bound
import QtQuick
import Ryoku.PluginKit.Singletons

// content/Panel.qml: the bar panel. Every action lives here, never on the bar
// glyph. Shows connection state, public/VPN IP, current region, connect /
// disconnect, a button to open the PIA app window, and a favorite-region
// switcher with a searchable browser of every region piactl knows about.
Item {
    id: root

    property var pluginApi
    property string density: "full"
    property real s: 1
    property real widthBudget: 360
    property bool active: false

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property string state: service ? service.connectionState : "Unknown"
    readonly property bool connected: root.state === "Connected"
    readonly property bool busy: service ? service.busy : false
    readonly property string region: service ? service.region : ""
    readonly property string pubIp: service ? service.pubIp : ""
    readonly property string vpnIp: service ? service.vpnIp : ""
    readonly property var favoriteRegions: service ? service.favoriteRegions : []
    readonly property var regionIds: service ? service.regionIds : []

    readonly property color stateColor: {
        switch (root.state) {
        case "Connected": return Theme.accent;
        case "Interrupted": return Theme.vermDeep ?? Theme.dim;
        case "Connecting":
        case "Reconnecting":
        case "DisconnectingToReconnect":
        case "Disconnecting": return Theme.dim;
        default: return Theme.dim;
        }
    }

    property string regionFilter: ""

    readonly property var filteredRegions: {
        const q = root.regionFilter.trim().toLowerCase();
        const all = root.regionIds;
        if (!q.length)
            return all.slice(0, 40);
        return all.filter(id => id.toLowerCase().indexOf(q) !== -1).slice(0, 40);
    }

    implicitWidth: root.widthBudget
    implicitHeight: col.implicitHeight + 24 * root.s

    Column {
        id: col
        x: 12 * root.s
        y: 12 * root.s
        width: root.width - 24 * root.s
        spacing: 10 * root.s

        Text {
            text: "PIA VPN"
            color: Theme.bright
            font.family: Theme.display
            font.pixelSize: 16 * root.s
        }

        // -- status block --------------------------------------------------
        Row {
            spacing: 8 * root.s
            Rectangle {
                width: 9 * root.s
                height: 9 * root.s
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                color: root.stateColor
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.state + (root.busy ? "…" : "")
                color: Theme.bright
                font.family: Theme.font
                font.pixelSize: 13 * root.s
            }
        }

        Text {
            text: "Region: " + (root.region.length ? root.region : "—")
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 12 * root.s
        }
        Text {
            text: "Public IP: " + (root.pubIp.length ? root.pubIp : "—")
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 12 * root.s
        }
        Text {
            visible: root.connected && root.vpnIp.length > 0
            text: "VPN IP: " + root.vpnIp
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 12 * root.s
        }
        Text {
            visible: service && service.lastError.length > 0
            text: service ? service.lastError : ""
            color: Theme.vermDeep ?? Theme.dim
            font.family: Theme.font
            font.pixelSize: 11 * root.s
            wrapMode: Text.WordWrap
            width: col.width
        }

        // -- action buttons -------------------------------------------------
        Row {
            spacing: 8 * root.s

            Rectangle {
                width: connectLabel.implicitWidth + 24 * root.s
                height: connectLabel.implicitHeight + 12 * root.s
                radius: Theme.radius
                color: connectArea.pressed ? Theme.vermDeep : Theme.accent
                opacity: root.busy ? 0.6 : 1

                Text {
                    id: connectLabel
                    anchors.centerIn: parent
                    text: root.connected ? "DISCONNECT" : "CONNECT"
                    color: Theme.cardBot
                    font.family: Theme.font
                    font.pixelSize: 12 * root.s
                }

                MouseArea {
                    id: connectArea
                    anchors.fill: parent
                    enabled: !root.busy
                    onClicked: {
                        if (!root.service)
                            return;
                        if (root.connected)
                            root.service.disconnectVpn();
                        else
                            root.service.connectVpn();
                    }
                }
            }

            Rectangle {
                width: openLabel.implicitWidth + 24 * root.s
                height: openLabel.implicitHeight + 12 * root.s
                radius: Theme.radius
                color: openArea.pressed ? Theme.tint5 ?? Theme.dim : "transparent"
                border.width: Theme.border ?? 1
                border.color: Theme.line ?? Theme.dim

                Text {
                    id: openLabel
                    anchors.centerIn: parent
                    text: "OPEN APP"
                    color: Theme.bright
                    font.family: Theme.font
                    font.pixelSize: 12 * root.s
                }

                MouseArea {
                    id: openArea
                    anchors.fill: parent
                    onClicked: if (root.service) root.service.openApp()
                }
            }
        }

        // -- favorites --------------------------------------------------
        Text {
            visible: root.favoriteRegions.length > 0
            text: "Favorites"
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 12 * root.s
        }

        Repeater {
            model: root.favoriteRegions
            delegate: Row {
                required property string modelData
                width: col.width
                spacing: 8 * root.s

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData === root.region ? ("\u25C6 " + modelData) : modelData
                    color: modelData === root.region ? Theme.accent : Theme.bright
                    font.family: Theme.font
                    font.pixelSize: 12 * root.s
                    width: col.width - 60 * root.s
                    elide: Text.ElideRight

                    MouseArea {
                        anchors.fill: parent
                        onClicked: if (root.service) root.service.useRegion(modelData)
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u2605"
                    color: Theme.accent
                    font.pixelSize: 12 * root.s

                    MouseArea {
                        anchors.fill: parent
                        onClicked: if (root.service) root.service.toggleFavorite(modelData)
                    }
                }
            }
        }

        // -- all regions: search + browse -----------------------------------
        Text {
            text: "All regions"
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 12 * root.s
        }

        Rectangle {
            width: col.width
            height: filterInput.implicitHeight + 10 * root.s
            radius: Theme.radius
            color: "transparent"
            border.width: Theme.border ?? 1
            border.color: Theme.line ?? Theme.dim

            TextInput {
                id: filterInput
                anchors.fill: parent
                anchors.margins: 6 * root.s
                color: Theme.bright
                font.family: Theme.font
                font.pixelSize: 12 * root.s
                clip: true
                text: root.regionFilter
                onTextChanged: root.regionFilter = text
            }
        }

        Flickable {
            id: flick
            width: col.width
            height: Math.min(regionCol.implicitHeight, 180 * root.s)
            contentWidth: width
            contentHeight: regionCol.implicitHeight
            clip: true

            Column {
                id: regionCol
                width: flick.width
                spacing: 4 * root.s

                Repeater {
                    model: root.filteredRegions
                    delegate: Row {
                        required property string modelData
                        width: regionCol.width
                        spacing: 8 * root.s

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData
                            color: modelData === root.region ? Theme.accent : Theme.dim
                            font.family: Theme.font
                            font.pixelSize: 12 * root.s
                            width: regionCol.width - 60 * root.s
                            elide: Text.ElideRight

                            MouseArea {
                                anchors.fill: parent
                                onClicked: if (root.service) root.service.useRegion(modelData)
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            readonly property bool fav: root.favoriteRegions.indexOf(modelData) !== -1
                            text: fav ? "\u2605" : "\u2606"
                            color: fav ? Theme.accent : Theme.dim
                            font.pixelSize: 12 * root.s

                            MouseArea {
                                anchors.fill: parent
                                onClicked: if (root.service) root.service.toggleFavorite(modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
