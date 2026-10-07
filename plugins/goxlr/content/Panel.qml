import QtQuick
import Ryoku.PluginKit.Singletons

// content/Panel.qml: the bar panel. A compact per-channel volume mixer plus
// mic mute, scoped to what fits a 360px-wide dropdown. Routing, effects, the
// sampler, lighting and profile switching stay in the GoXLR Utility window;
// this plugin only ever sends SetVolume, SetFaderMuteState and
// SetCoughMuteState, the same requests its own web UI makes.
Item {
    id: root

    property var pluginApi
    property string density: "full"
    property real s: 1
    property real widthBudget: 360
    property bool active: false

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property var channels: service ? service.channelList : []
    readonly property bool connected: service ? service.connected : false

    function channelLabel(name) {
        const labels = {
            "Mic": "Mic",
            "LineIn": "Line In",
            "Console": "Console",
            "System": "System",
            "Game": "Game",
            "Chat": "Chat",
            "Sample": "Sample",
            "Music": "Music",
            "Headphones": "Headphones",
            "MicMonitor": "Mic Monitor",
            "LineOut": "Line Out"
        };
        return labels[name] || name;
    }

    width: root.widthBudget
    implicitWidth: root.widthBudget
    implicitHeight: col.implicitHeight + 24 * root.s

    Column {
        id: col
        x: 12 * root.s
        y: 12 * root.s
        width: root.width - 24 * root.s
        spacing: 10 * root.s

        Text {
            text: "GoXLR"
            color: Theme.bright
            font.family: Theme.display
            font.pixelSize: 16 * root.s
        }

        Text {
            visible: !root.connected
            width: parent.width
            wrapMode: Text.WordWrap
            text: (root.service && root.service.lastError === "unreachable") ? "Daemon unreachable \u2014 is goxlr-daemon running?" : "No GoXLR connected."
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 12 * root.s
        }

        Text {
            visible: root.connected
            width: parent.width
            elide: Text.ElideRight
            text: [root.service ? root.service.deviceType : "", root.service ? root.service.profileName : ""].filter(t => t && t.length > 0).join("  \u00b7  ")
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 11 * root.s
        }

        // Mic mute gets its own large target: the one action worth reaching
        // without scrolling to the Mic row below.
        Rectangle {
            id: micButton
            visible: root.connected
            width: parent.width
            height: micLabel.implicitHeight + 16 * root.s
            radius: Theme.radius
            readonly property bool muted: root.service ? root.service.channelMuted("Mic") : false
            color: micArea.pressed ? Theme.vermDeep : (muted ? Theme.vermDeep : Theme.tileBg)

            Text {
                id: micLabel
                anchors.centerIn: parent
                text: micButton.muted ? "Mic muted \u2014 click to unmute" : "Mute mic"
                color: Theme.bright
                font.family: Theme.font
                font.pixelSize: 13 * root.s
            }

            MouseArea {
                id: micArea
                anchors.fill: parent
                onClicked: if (root.service)
                    root.service.toggleMicMute()
            }
        }

        Flickable {
            id: flick
            visible: root.connected
            width: parent.width
            height: Math.min(channelColumn.implicitHeight, 360 * root.s)
            contentWidth: width
            contentHeight: channelColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: channelColumn
                width: flick.width
                spacing: 10 * root.s

                Repeater {
                    model: root.channels

                    delegate: Item {
                        id: chRow
                        required property string modelData
                        readonly property string channelName: modelData
                        readonly property var raw: (root.service && root.service.volumes) ? root.service.volumes[channelName] : undefined
                        readonly property bool muted: root.service ? root.service.channelMuted(channelName) : false
                        readonly property bool muteable: channelName === "Mic" || channelName === "MicMonitor" || (root.service ? root.service.faderFor(channelName) !== null : false)

                        width: channelColumn.width
                        height: 26 * root.s

                        Text {
                            id: nameLabel
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 72 * root.s
                            elide: Text.ElideRight
                            text: root.channelLabel(chRow.channelName)
                            color: chRow.muted ? Theme.vermDeep : Theme.bright
                            font.family: Theme.font
                            font.pixelSize: 12 * root.s
                        }

                        Item {
                            id: track
                            anchors.left: nameLabel.right
                            anchors.leftMargin: 8 * root.s
                            anchors.right: valueLabel.left
                            anchors.rightMargin: 8 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            height: 6 * root.s

                            Rectangle {
                                anchors.fill: parent
                                radius: height / 2
                                color: Theme.hair
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                height: parent.height
                                radius: height / 2
                                width: parent.width * Math.max(0, Math.min(1, (chRow.raw || 0) / 255))
                                color: chRow.muted ? Theme.vermDeep : Theme.accent
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -8 * root.s
                                onPressed: mouse => trackSlide(mouse.x)
                                onPositionChanged: mouse => {
                                    if (pressed)
                                        trackSlide(mouse.x);
                                }
                                function trackSlide(x) {
                                    var ratio = Math.max(0, Math.min(1, (x + 8 * root.s) / track.width));
                                    if (root.service)
                                        root.service.setVolume(chRow.channelName, Math.round(ratio * 255));
                                }
                            }
                        }

                        Text {
                            id: valueLabel
                            anchors.right: muteBtn.visible ? muteBtn.left : parent.right
                            anchors.rightMargin: muteBtn.visible ? 8 * root.s : 0
                            anchors.verticalCenter: parent.verticalCenter
                            width: 40 * root.s
                            horizontalAlignment: Text.AlignRight
                            text: (root.service && chRow.raw !== undefined) ? root.service.volumeText(chRow.raw) : "--"
                            color: Theme.dim
                            font.family: Theme.font
                            font.pixelSize: 12 * root.s
                        }

                        Rectangle {
                            id: muteBtn
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 22 * root.s
                            height: 22 * root.s
                            radius: Theme.radius
                            visible: chRow.muteable
                            color: muteArea.pressed ? Theme.vermDeep : (chRow.muted ? Theme.vermDeep : Theme.tileBg)

                            Text {
                                anchors.centerIn: parent
                                text: "\u2716"
                                color: Theme.bright
                                font.family: Theme.mono
                                font.pixelSize: 10 * root.s
                            }

                            MouseArea {
                                id: muteArea
                                anchors.fill: parent
                                onClicked: if (root.service)
                                    root.service.toggleChannelMute(chRow.channelName)
                            }
                        }
                    }
                }
            }
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Routing, effects, the sampler, lighting and profiles aren't covered here \u2014 open the GoXLR Utility for those."
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 10 * root.s
        }
    }
}
