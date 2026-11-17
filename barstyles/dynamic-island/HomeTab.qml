pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell

// iOS-style widget board: Clock + Weather · Calendar · Activity rings · Batteries/Shortcuts · Now Playing/Notifications
Item {
    id: root
    property string screenName: ""
    readonly property real col: (width - 24) / 3
    readonly property real rowH: (height - 12) / 2

    // Apple Fitness ring colours
    readonly property color moveC: Theme.dark ? "#fa114f" : "#e6004c"
    readonly property color exerC: Theme.dark ? "#a6ff00" : "#6cc400"
    readonly property color standC: Theme.dark ? "#00f0ff" : "#00b7c7"

    component Stat: Column {
        id: st
        property string label: ""
        property string value: ""
        property color tint: "white"
        Txt { text: st.label; size: 10; weight: Font.DemiBold; color: Theme.fg2 }
        Txt { text: st.value; size: 14; weight: Font.DemiBold; color: st.tint }
    }

    component ShortcutTile: Rectangle {
        id: sc
        property string icon: ""
        property string label: ""
        property color tint: Theme.accent
        signal clicked()
        width: (parent.width - 6) / 2
        height: 46
        radius: 14
        color: Theme.alpha(tint, scMa.containsMouse ? 0.95 : 0.85)
        scale: scMa.pressed ? 0.94 : 1
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
        Icon { x: 9; y: 7; text: sc.icon; size: 16; fill: 1; color: "#ffffff" }
        Txt { x: 9; anchors.bottom: parent.bottom; anchors.bottomMargin: 6; text: sc.label; size: 10.5; weight: Font.DemiBold; color: "#ffffff" }
        MouseArea { id: scMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sc.clicked() }
    }

    // ═══════════ Row 1 ═══════════
    // Clock + Weather (wide)
    Widget {
        id: clockW
        x: 0; y: 0
        width: root.col * 2 + 12
        height: root.rowH
        pad: 16

        Column {
            id: clockCol
            width: 186
            anchors.verticalCenter: parent.verticalCenter
            spacing: -2
            Txt { text: Hub.greeting; size: 12.5; weight: Font.DemiBold; color: Theme.accent }
            Row {
                spacing: 3
                Txt { id: bigTime; text: Hub.fmtClock(Hub.now, false, false); size: 56; weight: Font.Light }
                Column {
                    anchors.bottom: bigTime.baseline
                    Txt { visible: Hub.ampm !== ""; text: Hub.ampm; size: 13; weight: Font.DemiBold; color: Theme.fg2 }
                    Txt { visible: Config.s.showSeconds; text: Hub.pad2(Hub.now.getSeconds()); size: 16; color: Theme.fg3 }
                }
            }
            Txt { text: Qt.formatDate(Hub.now, "dddd, d MMMM"); size: 13; color: Theme.fg2 }
        }

        Rectangle {
            id: vsep
            anchors.left: clockCol.right
            anchors.leftMargin: 12
            width: 1
            height: parent.height
            color: Theme.sep
        }

        // weather
        Item {
            anchors.left: vsep.right
            anchors.leftMargin: 16
            anchors.right: parent.right
            height: parent.height
            visible: Config.s.weather

            Column {
                visible: Hub.wTemp === ""
                anchors.centerIn: parent
                spacing: 4
                Icon { anchors.horizontalCenter: parent.horizontalCenter; text: "cloud_sync"; size: 26; color: Theme.fg3 }
                Txt { anchors.horizontalCenter: parent.horizontalCenter; text: Hub.locStatus !== "" ? Hub.locStatus : "Loading weather…"; size: 11.5; color: Theme.fg3; width: Math.min(implicitWidth, 200); wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter }
            }
            Item {
                anchors.fill: parent
                visible: Hub.wTemp !== ""
                Row {
                    id: place
                    spacing: 3
                    Icon { text: Hub.locSource === "Manual" ? "location_on" : "near_me"; size: 12; fill: 1; color: Theme.fg2; anchors.verticalCenter: parent.verticalCenter }
                    Txt { text: Hub.wPlace; size: 12; weight: Font.DemiBold; color: Theme.fg2; width: Math.min(implicitWidth, place.parent.width * 0.5) }
                }
                Row {
                    id: tempRow
                    anchors.top: place.bottom
                    anchors.topMargin: 0
                    spacing: 6
                    Txt { text: Hub.wTemp; size: 34; weight: Font.Light }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Icon { text: Hub.weatherSymbol(Hub.wDesc); size: 20; fill: 1; color: Hub.weatherColor(Hub.wDesc) }
                    }
                }
                Column {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 6
                    Txt { anchors.right: parent.right; text: Hub.wDesc; size: 11.5; weight: Font.DemiBold; width: Math.min(implicitWidth, place.parent.width * 0.42); horizontalAlignment: Text.AlignRight }
                    Txt { anchors.right: parent.right; text: "H:" + Hub.wHigh + "  L:" + Hub.wLow; size: 11; color: Theme.fg2 }
                }
                Row {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    Repeater {
                        model: Hub.wHourly.slice(0, 5)
                        Column {
                            id: hr
                            required property var modelData
                            width: parent.width / Math.max(1, Math.min(5, Hub.wHourly.length))
                            spacing: 3
                            Txt { anchors.horizontalCenter: parent.horizontalCenter; text: hr.modelData.label; size: 10; color: Theme.fg2 }
                            Icon { anchors.horizontalCenter: parent.horizontalCenter; text: Hub.weatherSymbol(hr.modelData.desc, hr.modelData.night); size: 17; fill: 1; color: Hub.weatherColor(hr.modelData.desc, hr.modelData.night) }
                            Txt { anchors.horizontalCenter: parent.horizontalCenter; text: hr.modelData.temp; size: 11.5; weight: Font.DemiBold }
                        }
                    }
                }
            }
        }
    }

    // Calendar
    Widget {
        id: calW
        x: root.col * 2 + 24; y: 0
        width: root.col
        height: root.rowH
        pad: 12
        property int monthOffset: 0
        readonly property int viewMonth: (((Hub.now.getMonth() + monthOffset) % 12) + 12) % 12
        readonly property int viewYear: Hub.now.getFullYear() + Math.floor((Hub.now.getMonth() + monthOffset) / 12)

        WheelHandler { onWheel: e => calW.monthOffset += e.angleDelta.y > 0 ? -1 : 1 }
        TapHandler { onDoubleTapped: calW.monthOffset = 0 }

        Txt {
            id: monthLbl
            x: 4
            text: Qt.locale().standaloneMonthName(calW.viewMonth).toUpperCase() + (calW.monthOffset !== 0 ? " " + calW.viewYear : "")
            size: 10.5
            weight: Font.Bold
            color: Theme.red
        }
        DayOfWeekRow {
            id: dow
            anchors.top: monthLbl.bottom
            anchors.topMargin: 3
            width: parent.width
            locale: grid.locale
            padding: 0
            spacing: 0
            delegate: Txt {
                required property var model
                text: model.narrowName
                size: 9
                weight: Font.DemiBold
                color: Theme.fg3
                horizontalAlignment: Text.AlignHCenter
            }
        }
        MonthGrid {
            id: grid
            anchors.top: dow.bottom
            anchors.bottom: parent.bottom
            width: parent.width
            month: calW.viewMonth
            year: calW.viewYear
            locale: Qt.locale()
            padding: 0
            spacing: 0
            delegate: Item {
                id: cell
                required property var model
                implicitWidth: 20
                implicitHeight: 15
                Rectangle {
                    anchors.centerIn: parent
                    width: 18; height: 18; radius: 9
                    visible: cell.model.today
                    color: Theme.red
                }
                Txt {
                    anchors.centerIn: parent
                    text: cell.model.day
                    size: 10
                    weight: cell.model.today ? Font.Bold : Font.Medium
                    opacity: cell.model.month === grid.month ? 1 : 0
                    color: cell.model.today ? "#ffffff" : Theme.fg
                }
            }
        }
    }

    // ═══════════ Row 2 ═══════════
    // Activity rings (CPU / Memory / Disk)
    Widget {
        x: 0; y: root.rowH + 12
        width: root.col
        height: root.rowH
        pad: 14

        Item {
            id: rings
            width: 96; height: 96
            anchors.verticalCenter: parent.verticalCenter
            Ring { anchors.fill: parent; thickness: 11; color: root.moveC; value: Hub.cpu }
            Ring { anchors.fill: parent; anchors.margins: 12.5; thickness: 11; color: root.exerC; value: Hub.mem }
            Ring { anchors.fill: parent; anchors.margins: 25; thickness: 11; color: root.standC; value: Hub.disk }
        }
        Column {
            anchors.left: rings.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5
            Stat { label: "CPU"; value: Math.round(Hub.cpu * 100) + "%"; tint: root.moveC }
            Stat { label: "Memory"; value: Hub.memUsedGb.toFixed(1) + " GB"; tint: root.exerC }
            Stat { label: "Disk"; value: Math.round(Hub.disk * 100) + "%"; tint: root.standC }
        }
    }

    // Batteries (if any) or Shortcuts
    Widget {
        x: root.col + 12; y: root.rowH + 12
        width: root.col
        height: root.rowH
        pad: 12

        // Batteries
        Item {
            anchors.fill: parent
            visible: Hub.batteryDevices.length > 0
            Txt { text: "Batteries"; size: 11; weight: Font.DemiBold; color: Theme.fg2; x: 4 }
            Row {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 8
                spacing: 10
                Repeater {
                    model: Hub.batteryDevices.slice(0, 3)
                    Column {
                        id: bd
                        required property var modelData
                        spacing: 6
                        Item {
                            width: 52; height: 52
                            Ring {
                                anchors.fill: parent
                                thickness: 5
                                value: bd.modelData.level
                                color: bd.modelData.charging || bd.modelData.level > 0.2 ? Theme.green : Theme.red
                                trackColor: Theme.fill2
                            }
                            Icon { anchors.centerIn: parent; text: bd.modelData.icon; size: 20; fill: 1 }
                        }
                        Txt { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(bd.modelData.level * 100) + "%"; size: 12; weight: Font.DemiBold }
                    }
                }
            }
        }

        // Shortcuts
        Item {
            anchors.fill: parent
            visible: Hub.batteryDevices.length === 0
            Txt { text: "Shortcuts"; size: 11; weight: Font.DemiBold; color: Theme.fg2; x: 4 }
            Grid {
                anchors.bottom: parent.bottom
                width: parent.width
                columns: 2
                spacing: 6
    
                ShortcutTile { icon: "screenshot_region"; label: "Screenshot"; tint: Theme.blue; onClicked: Hub.screenshot() }
                ShortcutTile { icon: "colorize"; label: "Pick Colour"; tint: Theme.pink; onClicked: Hub.colorPick() }
                ShortcutTile { icon: "timer"; label: "Timer 25m"; tint: Theme.orange; onClicked: Hub.startTimer(1500) }
                ShortcutTile { icon: "lock"; label: "Lock"; tint: Theme.indigo; onClicked: Hub.session("lock") }
            }
        }
    }

    // Now Playing or Notifications
    Widget {
        x: root.col * 2 + 24; y: root.rowH + 12
        width: root.col
        height: root.rowH
        pad: 12
        hoverable: true
        onClicked: Hub.player ? (Hub.tab = 1) : Notifs.toggleCenter(root.screenName)

        Item {
            anchors.fill: parent
            visible: Hub.player !== null
            ArtImage {
                id: npArt
                width: 52; height: 52; radius: 12
                source: Hub.artUrl
            }
            Visualizer {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 6
                count: 4
                maxHeight: 16
                visible: Hub.playing
            }
            Column {
                anchors.top: npArt.bottom
                anchors.topMargin: 8
                width: parent.width
                Txt { width: parent.width; text: Hub.player ? (Hub.player.trackTitle || "Unknown") : ""; size: 13; weight: Font.DemiBold }
                Txt { width: parent.width; text: Hub.player ? (Hub.player.trackArtist || Hub.player.identity) : ""; size: 11.5; color: Theme.fg2 }
            }
            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: 34; height: 34; radius: 17
                color: Theme.fg
                Icon { anchors.centerIn: parent; text: Hub.playing ? "pause" : "play_arrow"; size: 20; fill: 1; color: Theme.dark ? "#000000" : "#ffffff" }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Hub.player.togglePlaying() }
            }
        }

        Item {
            anchors.fill: parent
            visible: Hub.player === null
            Row {
                spacing: 6
                x: 4
                Icon { text: Notifs.dnd ? "bedtime" : "notifications"; size: 15; fill: 1; color: Notifs.dnd ? Theme.indigo : Theme.red }
                Txt { text: Notifs.dnd ? "Do Not Disturb" : "Notifications"; size: 11; weight: Font.DemiBold; color: Theme.fg2 }
            }
            Column {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 4
                Txt { anchors.horizontalCenter: parent.horizontalCenter; text: Notifs.visibleCount; size: 40; weight: Font.Light }
                Txt { anchors.horizontalCenter: parent.horizontalCenter; text: Notifs.visibleCount === 1 ? "notification" : "notifications"; size: 11.5; color: Theme.fg2 }
            }
            Txt {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                text: Hub.uptime !== "" ? "Up " + Hub.uptime : ""
                size: 10.5
                color: Theme.fg3
            }
        }
    }
}
