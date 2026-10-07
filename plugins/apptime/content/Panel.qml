// apptime panel: per-day top apps, hours & minutes only (no seconds), in the
// plugin kit's dossier idiom — a MicroLabel eyebrow, vector chevrons and a
// squared tick meter. Browse the archive with the chevrons (or click the day to
// jump back to today). The host draws the card; this content is transparent and
// the host sizes the card from implicitHeight.
import QtQuick
import Ryoku.PluginKit
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
    // the host keeps this content alive after the panel closes, so the browse
    // position is gated on the live open flag (not the always-true `active`).
    readonly property bool panelOpen: pluginApi ? pluginApi.panelOpen : false

    onPanelOpenChanged: if (!panelOpen && service) service.goToday()

    // a squared, static level meter: no timers, reads as a printed gauge.
    component TickMeter: Item {
        id: meter
        property real frac: 0
        property int ticks: 16
        readonly property real gap: 2 * root.s
        readonly property real tickW: Math.max(1, (width - gap * (ticks - 1)) / ticks)
        readonly property int lit: Math.max(frac > 0 ? 1 : 0,
                                            Math.min(ticks, Math.round(frac * ticks)))
        implicitHeight: 4 * root.s

        Repeater {
            model: meter.ticks
            Rectangle {
                required property int index
                x: index * (meter.tickW + meter.gap)
                width: meter.tickW
                height: meter.height
                color: index < meter.lit ? Theme.accent : Theme.hair
                Behavior on color { ColorAnimation { duration: Motion.fast } }
            }
        }
    }

    implicitWidth: root.widthBudget
    implicitHeight: col.implicitHeight + 6 * root.s

    Column {
        id: col
        width: root.width
        spacing: 9 * root.s

        // ---- eyebrow: identity + the day total ----
        Item {
            width: root.width
            height: 13 * root.s

            MicroLabel {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                label: "App Time"
                s: root.s
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.service ? root.service.fmtHM(root.total) : "0m"
                color: Theme.bright
                font.family: Theme.mono
                font.pixelSize: 12.5 * root.s
                font.weight: Font.Medium
            }
        }

        // ---- day nav: older chevron / day / newer chevron, position at right ----
        Item {
            id: head
            width: root.width
            height: 22 * root.s

            GlyphIcon {
                id: prevBtn
                name: "chevron-left"
                width: 15 * root.s
                height: 15 * root.s
                color: root.service && root.service.canOlder
                    ? (prevMa.containsMouse ? Theme.accent : Theme.bright)
                    : Theme.faint
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
            }
            MouseArea {
                id: prevMa
                anchors.fill: prevBtn
                anchors.margins: -5 * root.s
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: root.service ? root.service.canOlder : false
                onClicked: if (root.service) root.service.stepDay(1)
            }

            Text {
                id: dayLabel
                anchors.left: prevBtn.right
                anchors.leftMargin: 10 * root.s
                anchors.verticalCenter: parent.verticalCenter
                text: root.service ? root.service.selLabel : "TODAY"
                color: root.browsing
                    ? (dayMa.containsMouse ? Theme.accent : Theme.bright)
                    : Theme.dim
                font.family: Theme.mono
                font.pixelSize: 11 * root.s
                font.weight: Font.DemiBold
                font.letterSpacing: 1.8 * root.s
                font.capitalization: Font.AllUppercase
            }
            MouseArea {
                id: dayMa
                anchors.fill: dayLabel
                anchors.margins: -4 * root.s
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: root.browsing
                onClicked: if (root.service) root.service.goToday()
            }

            GlyphIcon {
                id: nextBtn
                anchors.left: dayLabel.right
                anchors.leftMargin: 10 * root.s
                anchors.verticalCenter: parent.verticalCenter
                name: "chevron-right"
                width: 15 * root.s
                height: 15 * root.s
                color: root.service && root.service.canNewer
                    ? (nextMa.containsMouse ? Theme.accent : Theme.bright)
                    : Theme.faint
            }
            MouseArea {
                id: nextMa
                anchors.fill: nextBtn
                anchors.margins: -5 * root.s
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: root.service ? root.service.canNewer : false
                onClicked: if (root.service) root.service.stepDay(-1)
            }

            // marginalia: live marker or where this day sits in the archive
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    if (!root.service) return "";
                    if (root.service.selIndex === 0) return "LIVE";
                    return root.service.pad2(root.service.selIndex) + " / "
                        + root.service.pad2(root.service.dates.length);
                }
                color: root.service && root.service.selIndex === 0 ? Theme.accent : Theme.faint
                font.family: Theme.mono
                font.pixelSize: 9.5 * root.s
                font.letterSpacing: 1.2 * root.s
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
            spacing: 11 * root.s
            visible: root.list.length > 0
            topPadding: 4 * root.s
            bottomPadding: 2 * root.s

            Repeater {
                model: root.list
                delegate: Item {
                    id: rowI
                    required property var modelData
                    required property int index
                    width: root.width
                    height: 30 * root.s

                    readonly property real rankW: 20 * root.s
                    readonly property real timeW: 56 * root.s

                    Text {
                        x: 0
                        width: rowI.rankW
                        anchors.verticalCenter: parent.verticalCenter
                        text: String(rowI.index + 1).padStart(2, "0")
                        color: rowI.index === 0 ? Theme.accent : Theme.faint
                        font.family: Theme.mono
                        font.pixelSize: 10 * root.s
                        font.letterSpacing: 0.5 * root.s
                    }
                    Column {
                        x: rowI.rankW + 6 * root.s
                        y: 2 * root.s
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
                        TickMeter {
                            width: parent.width
                            frac: rowI.modelData.fraction
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
            height: 78 * root.s
            visible: root.list.length === 0

            Column {
                anchors.centerIn: parent
                spacing: 7 * root.s

                GlyphIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: root.browsing ? "archive" : "list"
                    width: 22 * root.s
                    height: 22 * root.s
                    color: Theme.faint
                    stroke: 1.6
                }
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
