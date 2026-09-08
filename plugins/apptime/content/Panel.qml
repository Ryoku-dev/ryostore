// apptime panel: per-day top apps, hours & minutes only (no seconds), with
// usage bars. Browse the archive with the chevrons (or click the date to jump
// back to today). The host draws the card; this content is transparent and the
// host sizes the card from implicitHeight.
import QtQuick
import Ryoku.PluginKit.Singletons

Item {
    id: root

    property var pluginApi
    property string density: "full"
    property real s: 1
    property real widthBudget: 320
    property bool active: false

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property var list: service ? service.selTopList : []
    readonly property int total: service ? service.selTotalSeconds : 0
    readonly property bool browsing: service ? !service.selIsToday : false

    implicitWidth: root.widthBudget
    implicitHeight: col.implicitHeight + 6 * root.s

    Column {
        id: col
        width: root.width
        spacing: 8 * root.s

        // ---- header: nav chevrons + day + day total ----
        Item {
            id: head
            width: root.width
            height: 20 * root.s

            // older day
            Text {
                id: prevBtn
                x: 0
                width: 16 * root.s
                anchors.verticalCenter: parent.verticalCenter
                text: "\u2039"
                color: prevMa.containsMouse
                    ? (service && service.canOlder ? Theme.accent : Theme.faint)
                    : (service && service.canOlder ? Theme.bright : Theme.faint)
                font.family: Theme.mono
                font.pixelSize: 16 * root.s
                horizontalAlignment: Text.AlignHCenter
            }
            MouseArea {
                id: prevMa
                anchors.fill: prevBtn
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: service ? service.canOlder : false
                onClicked: if (service) service.stepDay(1)
            }

            // brand dot
            Rectangle {
                id: dot
                width: 6 * root.s
                height: 6 * root.s
                radius: 1.5 * root.s
                color: Theme.brand
                anchors.left: prevBtn.right
                anchors.leftMargin: 4 * root.s
                anchors.verticalCenter: parent.verticalCenter
            }

            // day label ("TODAY" or "Sep 3"); click jumps back to today
            Text {
                id: dayLabel
                text: service ? service.selLabel : "TODAY"
                color: root.browsing
                    ? (dayMa.containsMouse ? Theme.accent : Theme.bright)
                    : Theme.dim
                font.family: Theme.mono
                font.pixelSize: 10 * root.s
                font.weight: Font.DemiBold
                font.letterSpacing: 1.6 * root.s
                font.capitalization: Font.AllUppercase
                anchors.left: dot.right
                anchors.leftMargin: 7 * root.s
                anchors.verticalCenter: parent.verticalCenter
            }
            MouseArea {
                id: dayMa
                anchors.fill: dayLabel
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: root.browsing
                onClicked: if (service) service.goToday()
            }

            // newer day
            Text {
                id: nextBtn
                anchors.left: dayLabel.right
                anchors.leftMargin: 7 * root.s
                width: 16 * root.s
                anchors.verticalCenter: parent.verticalCenter
                text: "\u203A"
                color: nextMa.containsMouse
                    ? (service && service.canNewer ? Theme.accent : Theme.faint)
                    : (service && service.canNewer ? Theme.bright : Theme.faint)
                font.family: Theme.mono
                font.pixelSize: 16 * root.s
                horizontalAlignment: Text.AlignHCenter
            }
            MouseArea {
                id: nextMa
                anchors.fill: nextBtn
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: service ? service.canNewer : false
                onClicked: if (service) service.stepDay(-1)
            }

            // day total
            Text {
                text: service ? service.fmtHM(root.total) : "0m"
                color: root.browsing ? Theme.dim : Theme.bright
                font.family: Theme.mono
                font.pixelSize: 12.5 * root.s
                font.weight: Font.Medium
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ---- hair separator ----
        Rectangle {
            width: root.width
            height: 1
            color: Theme.hair
        }

        // ---- ranked apps of the selected day ----
        Column {
            id: listCol
            width: root.width
            spacing: 12 * root.s
            visible: root.list.length > 0
            topPadding: 6 * root.s
            bottomPadding: 2 * root.s

            Repeater {
                model: root.list
                delegate: Item {
                    id: rowI
                    required property var modelData
                    required property int index
                    width: root.width
                    height: 30 * root.s

                    readonly property real rankW: 16 * root.s
                    readonly property real timeW: 58 * root.s

                    Text {
                        x: 0
                        width: rowI.rankW
                        anchors.verticalCenter: parent.verticalCenter
                        text: rowI.index + 1
                        color: Theme.faint
                        font.family: Theme.mono
                        font.pixelSize: 10 * root.s
                    }
                    Column {
                        x: rowI.rankW + 8 * root.s
                        y: 3 * root.s
                        width: root.width - x - rowI.timeW - 8 * root.s
                        spacing: 5 * root.s

                        Text {
                            width: parent.width
                            text: rowI.modelData.label
                            elide: Text.ElideRight
                            color: Theme.bright
                            font.family: Theme.font
                            font.pixelSize: 12.5 * root.s
                        }
                        Item {
                            width: parent.width
                            height: 3 * root.s

                            Rectangle {
                                anchors.fill: parent
                                radius: 1.5 * root.s
                                color: Theme.hair
                            }
                            Rectangle {
                                width: parent.width * rowI.modelData.fraction
                                height: parent.height
                                radius: 1.5 * root.s
                                color: Theme.accent
                            }
                        }
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: rowI.timeW
                        horizontalAlignment: Text.AlignRight
                        text: rowI.modelData.text
                        color: Theme.dim
                        font.family: Theme.mono
                        font.pixelSize: 11.5 * root.s
                    }
                }
            }
        }

        // ---- empty state ----
        Item {
            id: emptyBox
            width: root.width
            height: 72 * root.s
            visible: root.list.length === 0

            Column {
                anchors.centerIn: parent
                spacing: 5 * root.s

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.browsing ? "Nothing tracked that day"
                                        : "No tracked activity yet"
                    color: Theme.bright
                    font.family: Theme.font
                    font.pixelSize: 12.5 * root.s
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !root.browsing
                    text: "Focus an app window and it counts here."
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
                }
            }
        }
    }
}
