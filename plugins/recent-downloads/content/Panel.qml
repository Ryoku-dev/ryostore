pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Ryoku.PluginKit.Singletons

Item {
    id: root
    property var pluginApi
    property string density: "full"
    property real s: 1
    property real widthBudget: 340
    property bool active: false
    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property string monoFont: "JetBrainsMono Nerd Font Mono"

    function formatSize(bytes) {
        const n = Number(bytes || 0);
        if (n < 1024) return n + " B";
        if (n < 1024 * 1024) return (n / 1024).toFixed(0) + " KB";
        if (n < 1024 * 1024 * 1024) return (n / (1024 * 1024)).toFixed(1) + " MB";
        return (n / (1024 * 1024 * 1024)).toFixed(1) + " GB";
    }

    function timeAgo(epoch) {
        const minutes = Math.max(0, Math.floor(Date.now() / 1000 - Number(epoch || 0)) / 60);
        if (minutes < 1) return "just now";
        if (minutes < 60) return Math.floor(minutes) + "m ago";
        const hours = Math.floor(minutes / 60);
        if (hours < 24) return hours + "h ago";
        const days = Math.floor(hours / 24);
        return days < 7 ? days + "d ago" : new Date(Number(epoch) * 1000).toLocaleDateString();
    }

    function refreshIfOpen() {
        if (root.active)
            openRefresh.restart()
    }

    onActiveChanged: refreshIfOpen()
    onServiceChanged: refreshIfOpen()
    onPluginApiChanged: refreshIfOpen()
    Component.onCompleted: refreshIfOpen()

    Timer {
        id: openRefresh
        interval: 0
        onTriggered: if (root.active && root.service) root.service.refresh()
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.active && root.service !== null
        onTriggered: if (root.service) root.service.refresh()
    }

    implicitWidth: root.widthBudget
    implicitHeight: column.implicitHeight + 24 * root.s

    Column {
        id: column
        x: 14 * root.s
        y: 12 * root.s
        width: root.width - 28 * root.s
        spacing: 9 * root.s

        Row {
            width: parent.width
            spacing: 8 * root.s
            Column {
                width: parent.width - refreshButton.width - parent.spacing
                spacing: 2 * root.s
                Text {
                    text: "RECENT DOWNLOADS"
                    color: Theme.bright
                    font.family: root.monoFont
                    font.pixelSize: 14 * root.s
                    font.weight: Font.DemiBold
                }
                Text {
                    width: parent.width
                    text: root.service && root.service.downloadDir ? root.service.downloadDir : "Your Downloads folder"
                    color: Theme.dim
                    font.family: root.monoFont
                    font.pixelSize: 10 * root.s
                    elide: Text.ElideMiddle
                }
            }
            Rectangle {
                id: refreshButton
                width: 27 * root.s
                height: width
                radius: Theme.radius
                color: refreshArea.containsMouse ? Theme.accent : Theme.cardTop
                Text {
                    anchors.centerIn: parent
                    text: "\u21bb"
                    color: refreshArea.containsMouse ? Theme.cardBot : Theme.bright
                    font.family: root.monoFont
                    font.pixelSize: 15 * root.s
                }
                MouseArea {
                    id: refreshArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: if (root.service) root.service.refresh()
                }
                ToolTip.visible: refreshArea.containsMouse
                ToolTip.text: "Refresh"
            }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.hair }

        ListView {
            id: downloads
            width: parent.width
            height: Math.min(contentHeight, 6 * 42 * root.s)
            clip: true
            spacing: 2 * root.s
            model: root.service ? root.service.items : []

            delegate: Rectangle {
                required property var modelData
                width: downloads.width
                height: 40 * root.s
                radius: Theme.radius
                color: rowArea.containsMouse ? Theme.cardTop : "transparent"

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 8 * root.s
                    anchors.rightMargin: 8 * root.s
                    spacing: 9 * root.s
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\u2193"
                        color: Theme.accent
                        font.family: root.monoFont
                        font.pixelSize: 15 * root.s
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 38 * root.s
                        spacing: 2 * root.s
                        Text {
                            width: parent.width
                            text: modelData.name || "Downloaded file"
                            color: Theme.bright
                            font.family: root.monoFont
                            font.pixelSize: 11 * root.s
                            elide: Text.ElideMiddle
                        }
                        Text {
                            text: root.formatSize(modelData.size) + "  ·  " + root.timeAgo(modelData.modified)
                            color: Theme.dim
                            font.family: root.monoFont
                            font.pixelSize: 9 * root.s
                        }
                    }
                }

                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: if (root.service) root.service.openFile(modelData.path)
                    ToolTip.visible: containsMouse
                    ToolTip.text: modelData.path || ""
                    ToolTip.delay: 500
                }
            }

            Text {
                anchors.centerIn: parent
                width: parent.width - 16 * root.s
                visible: downloads.count === 0
                text: root.service && root.service.error ? root.service.error
                    : (root.service && root.service.refreshing ? "Looking for recent files…" : "No recent downloads")
                color: Theme.dim
                font.family: root.monoFont
                font.pixelSize: 11 * root.s
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }

        Rectangle {
            width: parent.width
            height: 32 * root.s
            radius: Theme.radius
            color: folderArea.containsMouse ? Theme.accent : Theme.cardTop
            Text {
                anchors.centerIn: parent
                text: "Open Downloads folder"
                color: folderArea.containsMouse ? Theme.cardBot : Theme.bright
                font.family: root.monoFont
                font.pixelSize: 10 * root.s
            }
            MouseArea {
                id: folderArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: if (root.service) root.service.openFolder()
            }
        }
    }
}
