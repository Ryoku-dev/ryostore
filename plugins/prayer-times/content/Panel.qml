pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.PluginKit.Singletons

Item {
    id: root

    property var pluginApi
    property string density: "full"
    property real s: 1
    property real widthBudget: 380
    property bool active: false
    property string tab: "today"

    // every dimension the panel draws comes from here: one place to tune, and the
    // week and month tables can no longer drift apart from each other
    readonly property QtObject m: QtObject {
        readonly property real s: root.s
        readonly property real pad: 14 * s
        readonly property real gap: 10 * s
        readonly property real rowH: 22 * s
        readonly property real headH: 18 * s
        readonly property real dayCol: 44 * s
        readonly property real ring: 92 * s
        readonly property real gutter: 8 * s
        readonly property int monthRows: 13
    }

    readonly property var tabs: [
        { value: "today", label: "TODAY" },
        { value: "week", label: "WEEK" },
        { value: "month", label: "MONTH" },
        { value: "holidays", label: "HOLIDAYS" }
    ]

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property int todayIndex: {
        if (!service || !service.monthRows)
            return 0;
        for (var i = 0; i < service.monthRows.length; ++i) {
            if (service.monthRows[i].today)
                return i;
        }
        return 0;
    }
    readonly property bool holidaySoon: {
        if (!service)
            return false;
        if (service.holidayToday)
            return true;
        var match = service.nextHolidayText.match(/ in ([0-9]+) day/);
        return match !== null && parseInt(match[1], 10) <= 7;
    }

    function shortMonthLabel() {
        if (!service)
            return "";
        var parts = service.monthLabel.split(" ");
        return parts.length === 2 ? parts[0].substring(0, 3) + " " + parts[1] : service.monthLabel;
    }

    implicitWidth: root.widthBudget
    implicitHeight: service ? col.implicitHeight + 28 * s : unavailable.implicitHeight + 28 * s

    Column {
        id: col
        x: root.m.pad
        y: root.m.pad
        width: Math.max(0, root.width - 2 * root.m.pad)
        spacing: root.m.gap
        visible: root.service !== null

        Item {
            width: parent.width
            height: Math.max(cityText.implicitHeight, monthText.implicitHeight)

            Text {
                id: cityText
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, parent.width - monthText.implicitWidth - 8 * root.s)
                text: root.service ? root.service.cityName : ""
                color: Theme.bright
                font.family: Theme.display
                font.pixelSize: 17 * root.s
                font.letterSpacing: 0.2 * root.s
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Rectangle {
                id: monthChip
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: monthText.implicitWidth + 14 * root.s
                height: monthText.implicitHeight + 6 * root.s
                radius: Theme.radius
                color: "transparent"
                border.width: 1 * root.s
                border.color: Theme.hair

                Text {
                    id: monthText
                    anchors.centerIn: parent
                    text: root.shortMonthLabel()
                    color: Theme.dim
                    font.family: Theme.mono
                    font.pixelSize: 10 * root.s
                    font.letterSpacing: 0.4 * root.s
                }
            }
        }

        Text {
            width: parent.width
            text: root.service ? root.service.gregorianText + " · " + root.service.hijriText : ""
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 10.5 * root.s
            font.letterSpacing: 0.2 * root.s
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        Rectangle {
            width: parent.width
            height: 1 * root.s
            color: Theme.hair
            opacity: 0.6
        }

        Item {
            width: parent.width
            height: 26 * root.s

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4 * root.s

                Repeater {
                    model: root.tabs

                    delegate: Rectangle {
                        id: chip
                        required property var modelData
                        readonly property bool selected: root.tab === modelData.value
                        readonly property bool hovered: chipHover.hovered
                        width: chipText.implicitWidth + 22 * root.s
                        height: 26 * root.s
                        radius: Theme.radius
                        color: selected ? Theme.accent : (hovered ? Theme.ghost : "transparent")
                        border.width: selected ? 0 : 1 * root.s
                        border.color: Theme.hair

                        HoverHandler {
                            id: chipHover
                            cursorShape: Qt.PointingHandCursor
                        }

                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: chip.modelData.label
                            color: root.tab === chip.modelData.value ? Theme.cardBot : Theme.dim
                            font.family: Theme.font
                            font.pixelSize: 10 * root.s
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.6 * root.s
                        }

                        TapHandler {
                            onTapped: root.tab = chip.modelData.value
                        }
                    }
                }
            }
        }

        Item {
            visible: root.tab === "today"
            width: parent.width
            height: todayColumn.implicitHeight

            Column {
                id: todayColumn
                width: parent.width
                spacing: 4 * root.s

                Item {
                    id: ringItem
                    width: root.m.ring
                    height: ring.height + 24 * root.s
                    anchors.horizontalCenter: parent.horizontalCenter

                    Canvas {
                        id: ring
                        width: root.m.ring
                        height: root.m.ring

                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        Component.onCompleted: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            var cx = width / 2;
                            var cy = height / 2;
                            var radius = (width - 5 * root.s) / 2;
                            ctx.lineWidth = 3.2 * root.s;
                            ctx.lineCap = "round";
                            ctx.beginPath();
                            ctx.arc(cx, cy, radius, 0, Math.PI * 2);
                            ctx.strokeStyle = Theme.hair;
                            ctx.globalAlpha = 0.9;
                            ctx.stroke();
                            ctx.globalAlpha = 1;
                            var amount = root.service ? root.service.progress : 0;
                            if (amount > 0) {
                                ctx.beginPath();
                                ctx.arc(cx, cy, radius, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * amount);
                                ctx.strokeStyle = Theme.accent;
                                ctx.stroke();
                                var tip = -Math.PI / 2 + Math.PI * 2 * amount;
                                ctx.beginPath();
                                ctx.arc(cx + Math.cos(tip) * radius, cy + Math.sin(tip) * radius, 3.2 * root.s, 0, Math.PI * 2);
                                ctx.fillStyle = Theme.accent;
                                ctx.fill();
                            }
                        }
                    }

                    Connections {
                        target: root.service
                        function onProgressChanged() {
                            ring.requestPaint();
                        }
                    }

                    Text {
                        anchors.centerIn: ring
                        width: ring.width - 12 * root.s
                        horizontalAlignment: Text.AlignHCenter
                        text: root.service ? root.service.countdownText : ""
                        color: Theme.bright
                        font.family: Theme.display
                        font.pixelSize: 17 * root.s
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    Text {
                        y: ring.height + 5 * root.s
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: root.service && root.service.nextLabel ? ("TO " + root.service.nextLabel.toUpperCase()) : ""
                        color: Theme.dim
                        font.family: Theme.mono
                        font.pixelSize: 9.5 * root.s
                        font.letterSpacing: 0.8 * root.s
                    }
                }

                Repeater {
                    model: root.service ? root.service.rows : []

                    delegate: Item {
                        id: prayerRow
                        required property var modelData
                        width: todayColumn.width
                        height: 26 * root.s
                        opacity: modelData.isPast ? 0.45 : 1

                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 2 * root.s
                            height: 18 * root.s
                            radius: Theme.radius
                            color: Theme.accent
                            visible: prayerRow.modelData.isNext
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            text: prayerRow.modelData.label
                            color: prayerRow.modelData.isNext ? Theme.bright : Theme.dim
                            font.family: Theme.font
                            font.pixelSize: 12.5 * root.s
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: prayerRow.modelData.time
                            color: prayerRow.modelData.isNow ? Theme.accent : (prayerRow.modelData.isNext ? Theme.bright : Theme.dim)
                            font.family: Theme.mono
                            font.pixelSize: 12.5 * root.s
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: text.length > 0
                    text: root.service ? root.service.nightText : ""
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 10 * root.s
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    width: parent.width
                    visible: text.length > 0
                    text: root.service ? root.service.qiblaText : ""
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 10 * root.s
                }

                Text {
                    width: parent.width
                    visible: text.length > 0
                    text: root.service ? (root.service.holidayToday || root.service.nextHolidayText) : ""
                    color: root.holidaySoon ? Theme.gold : Theme.dim
                    font.family: Theme.mono
                    font.pixelSize: 10 * root.s
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
        }

        Column {
            id: weekTable
            visible: root.tab === "week"
            width: parent.width
            property var dayRows: root.service ? root.service.weekRows : []
            property real scale: root.s
            readonly property real rowH: root.m.rowH
            readonly property real headH: root.m.headH
            readonly property real dayCol: root.m.dayCol

            Row {
                id: weekHeader
                width: parent.width
                height: weekTable.headH

                Text {
                    width: weekTable.dayCol
                    anchors.verticalCenter: parent.verticalCenter
                    text: "DAY"
                    leftPadding: 8 * (weekTable.scale)
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 8 * weekTable.scale
                }

                Repeater {
                    model: root.service ? root.service.prayerShortLabels : []
                    delegate: Text {
                        required property string modelData
                        width: (weekHeader.width - weekTable.dayCol) / 6
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        rightPadding: 2 * weekTable.scale
                        text: modelData
                        color: Theme.faint
                        font.family: Theme.mono
                        font.pixelSize: 8 * weekTable.scale
                    }
                }
            }

            Repeater {
                model: weekTable.dayRows
                delegate: Item {
                    id: weekRow
                    required property var modelData
                    width: weekTable.width
                    height: weekTable.rowH

                    Rectangle {
                        anchors.fill: parent
                        visible: weekRow.modelData.today
                        color: Theme.accent
                        opacity: 0.20
                        radius: Theme.radius
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3 * weekTable.scale
                        height: 13 * weekTable.scale
                        radius: Theme.radius
                        visible: weekRow.modelData.today
                        color: Theme.accent
                    }

                    Rectangle {
                        x: 0
                        anchors.verticalCenter: parent.verticalCenter
                        width: 4 * weekTable.scale
                        height: 4 * weekTable.scale
                        radius: Theme.radius
                        visible: weekRow.modelData.holiday.length > 0
                        color: Theme.gold
                    }

                    Text {
                        x: 8 * weekTable.scale
                        width: weekTable.dayCol - 10 * weekTable.scale
                        anchors.verticalCenter: parent.verticalCenter
                        text: weekRow.modelData.day
                        color: weekRow.modelData.today ? Theme.bright : Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 10 * weekTable.scale
                        font.weight: weekRow.modelData.today ? Font.DemiBold : Font.Normal
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    Row {
                        id: weekTimes
                        x: weekTable.dayCol
                        width: parent.width - x
                        height: parent.height

                        Repeater {
                            model: root.service ? root.service.prayerKeys : []
                            delegate: Text {
                                id: weekTime
                                required property string modelData
                                width: weekTimes.width / 6
                                height: weekTimes.height
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignRight
                                text: weekRow.modelData[modelData]
                                color: weekRow.modelData.today ? Theme.bright : Theme.dim
                                font.family: Theme.mono
                                font.pixelSize: 10 * weekTable.scale
                            }
                        }
                    }
                }
            }
        }

        Column {
            id: monthSection
            visible: root.tab === "month"
            width: parent.width
            spacing: 2 * root.s

                    Row {
                        id: monthHeader
                        width: parent.width - 10 * monthTable.scale
                        height: monthTable.headH

                        Text {
                            width: monthTable.dayCol
                            anchors.verticalCenter: parent.verticalCenter
                            text: "DAY"
                            leftPadding: 8 * (monthTable.scale)
                            color: Theme.faint
                            font.family: Theme.mono
                            font.pixelSize: 8 * monthTable.scale
                        }

                        Repeater {
                            model: root.service ? root.service.prayerShortLabels : []
                            delegate: Text {
                                required property string modelData
                                width: (monthHeader.width - monthTable.dayCol) / 6
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: Text.AlignRight
                                rightPadding: 2 * monthTable.scale
                                text: modelData
                                color: Theme.faint
                                font.family: Theme.mono
                                font.pixelSize: 8 * monthTable.scale
                            }
                        }
                    }
            Flickable {
                id: monthFlick
                width: parent.width
                height: Math.min(contentHeight, root.m.rowH * root.m.monthRows)
                contentWidth: width
                contentHeight: monthTable.implicitHeight
                contentY: root.tab === "month" ? Math.max(0, (root.todayIndex - 4) * root.m.rowH) : 0
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: monthTable
                    width: monthFlick.width
                    property var dayRows: root.service ? root.service.monthRows : []
                    property real scale: root.s
                readonly property real rowH: root.m.rowH
                readonly property real headH: root.m.headH
                readonly property real dayCol: root.m.dayCol


                    Repeater {
                        model: monthTable.dayRows
                        delegate: Item {
                            id: monthRow
                            required property var modelData
                            width: monthTable.width
                            height: monthTable.rowH

                            Rectangle {
                                anchors.fill: parent
                                visible: monthRow.modelData.today
                                color: Theme.accent
                                opacity: 0.20
                                radius: Theme.radius
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 3 * monthTable.scale
                                height: 13 * monthTable.scale
                                radius: Theme.radius
                                visible: monthRow.modelData.today
                                color: Theme.accent
                            }

                            Rectangle {
                                x: 0
                                anchors.verticalCenter: parent.verticalCenter
                                width: 4 * monthTable.scale
                                height: 4 * monthTable.scale
                                radius: Theme.radius
                                visible: monthRow.modelData.holiday.length > 0
                                color: Theme.gold
                            }

                            Text {
                                x: 8 * monthTable.scale
                                width: monthTable.dayCol - 10 * monthTable.scale
                                anchors.verticalCenter: parent.verticalCenter
                                text: monthRow.modelData.day
                                color: monthRow.modelData.today ? Theme.bright : Theme.dim
                                font.family: Theme.font
                                font.pixelSize: 10 * monthTable.scale
                                font.weight: monthRow.modelData.today ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            Row {
                                id: monthTimes
                                x: monthTable.dayCol
                                width: parent.width - x - 10 * monthTable.scale
                                height: parent.height

                                Repeater {
                                    model: root.service ? root.service.prayerKeys : []
                                    delegate: Text {
                                        id: monthTime
                                        required property string modelData
                                        width: monthTimes.width / 6
                                        height: monthTimes.height
                                        verticalAlignment: Text.AlignVCenter
                                        horizontalAlignment: Text.AlignRight
                                        text: monthRow.modelData[modelData]
                                        color: monthRow.modelData.today ? Theme.bright : Theme.dim
                                        font.family: Theme.mono
                                        font.pixelSize: 10 * monthTable.scale
                                    }
                                }
                            }
                        }
                    }
                }

                // visible scroll affordance: the month table is taller than its viewport
                Rectangle {
                    id: monthThumb
                    readonly property real track: monthFlick.height - height
                    readonly property real span: Math.max(1, monthFlick.contentHeight - monthFlick.height)
                    x: monthFlick.width - width - 2 * root.s
                    width: 3 * root.s
                    radius: 1.5 * root.s
                    color: Theme.hair
                    opacity: 0.7
                    visible: monthFlick.contentHeight > monthFlick.height
                    height: Math.max(24 * root.s, monthFlick.height * monthFlick.height / Math.max(1, monthFlick.contentHeight))
                    y: monthFlick.contentY + track * (monthFlick.contentY / span)
                }
            }
        }

        // upcoming holidays: the next six, not just the nearest
        Column {
            id: holidayView
            visible: root.tab === "holidays"
            width: parent.width
            spacing: 0

            Repeater {
                model: root.service ? root.service.holidayRows : []

                delegate: Item {
                    id: holRow
                    required property var modelData
                    width: holidayView.width
                    height: 40 * root.s

                    Rectangle {
                        x: 1 * root.s
                        width: 5 * root.s
                        height: width
                        radius: width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: holRow.modelData.soon ? Theme.gold : Theme.hair
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 15 * root.s
                        anchors.right: parent.right
                        anchors.rightMargin: 70 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2 * root.s

                        Text {
                            width: parent.width
                            text: holRow.modelData.name
                            color: Theme.bright
                            font.family: Theme.font
                            font.pixelSize: 11.5 * root.s
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: holRow.modelData.date + "  \u00b7  " + holRow.modelData.hijri
                            color: Theme.faint
                            font.family: Theme.mono
                            font.pixelSize: 9 * root.s
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: holRow.modelData.when
                        color: holRow.modelData.soon ? Theme.gold : Theme.dim
                        font.family: Theme.mono
                        font.pixelSize: 9.5 * root.s
                    }
                }
            }
        }

    }

    Text {
        id: unavailable
        anchors.centerIn: parent
        visible: root.service === null
        text: "Prayer times unavailable"
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: 12 * root.s
    }
}
