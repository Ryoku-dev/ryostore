pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.PluginKit.Singletons

Item {
    id: root

    property var pluginApi
    property string density: "full"
    property real s: 1
    property real widthBudget: 360
    property bool active: false
    property string tab: "today"

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
        x: 14 * root.s
        y: 14 * root.s
        width: Math.max(0, root.width - 28 * root.s)
        spacing: 10 * root.s
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
                font.pixelSize: 16 * root.s
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                id: monthText
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.shortMonthLabel()
                color: Theme.faint
                font.family: Theme.mono
                font.pixelSize: 10.5 * root.s
            }
        }

        Text {
            width: parent.width
            text: root.service ? root.service.gregorianText + " · " + root.service.hijriText : ""
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 10.5 * root.s
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        Item {
            width: parent.width
            height: 26 * root.s

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4 * root.s

                Repeater {
                    model: [
                        { value: "today", label: "TODAY" },
                        { value: "week", label: "WEEK" },
                        { value: "month", label: "MONTH" }
                    ]

                    delegate: Rectangle {
                        id: chip
                        required property var modelData
                        width: chipText.implicitWidth + 20 * root.s
                        height: 26 * root.s
                        radius: Theme.radius
                        color: root.tab === modelData.value ? Theme.accent : Theme.ghost

                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: chip.modelData.label
                            color: root.tab === chip.modelData.value ? Theme.cardBot : Theme.dim
                            font.family: Theme.font
                            font.pixelSize: 10 * root.s
                            font.weight: Font.DemiBold
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
                    width: 92 * root.s
                    height: ring.height + 24 * root.s
                    anchors.horizontalCenter: parent.horizontalCenter

                    Canvas {
                        id: ring
                        width: 92 * root.s
                        height: 92 * root.s

                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        Component.onCompleted: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            var cx = width / 2;
                            var cy = height / 2;
                            var radius = (width - 5 * root.s) / 2;
                            ctx.lineWidth = 2.5 * root.s;
                            ctx.lineCap = "round";
                            ctx.beginPath();
                            ctx.arc(cx, cy, radius, 0, Math.PI * 2);
                            ctx.strokeStyle = Theme.hair;
                            ctx.stroke();
                            var amount = root.service ? root.service.progress : 0;
                            if (amount > 0) {
                                ctx.beginPath();
                                ctx.arc(cx, cy, radius, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * amount);
                                ctx.strokeStyle = Theme.accent;
                                ctx.stroke();
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
                        text: root.service && root.service.nextLabel ? "to " + root.service.nextLabel : ""
                        color: Theme.faint
                        font.family: Theme.mono
                        font.pixelSize: 9.5 * root.s
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

            Row {
                id: weekHeader
                width: parent.width
                height: 20 * weekTable.scale

                Text {
                    width: 54 * weekTable.scale
                    anchors.verticalCenter: parent.verticalCenter
                    text: "DAY"
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 9.5 * weekTable.scale
                }

                Repeater {
                    model: ["FAJR", "SUNRISE", "DHUHR", "ASR", "MAGHRIB", "ISHA"]
                    delegate: Text {
                        required property string modelData
                        width: (weekHeader.width - 54 * weekTable.scale) / 6
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        text: modelData
                        color: Theme.faint
                        font.family: Theme.mono
                        font.pixelSize: 9.5 * weekTable.scale
                    }
                }
            }

            Repeater {
                model: weekTable.dayRows
                delegate: Item {
                    id: weekRow
                    required property var modelData
                    width: weekTable.width
                    height: 22 * weekTable.scale

                    Rectangle {
                        anchors.fill: parent
                        visible: weekRow.modelData.today
                        color: Theme.cardTop
                        radius: Theme.radius
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
                        width: 46 * weekTable.scale
                        anchors.verticalCenter: parent.verticalCenter
                        text: weekRow.modelData.day
                        color: weekRow.modelData.today ? Theme.bright : Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 10 * weekTable.scale
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    Row {
                        id: weekTimes
                        x: 54 * weekTable.scale
                        width: parent.width - x
                        height: parent.height

                        Repeater {
                            model: ["fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha"]
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

        Flickable {
            id: monthFlick
            visible: root.tab === "month"
            width: parent.width
            height: Math.min(contentHeight, 300 * root.s)
            contentWidth: width
            contentHeight: monthTable.implicitHeight
            contentY: root.tab === "month" ? Math.max(0, root.todayIndex * 22 * root.s - 88 * root.s) : 0
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: monthTable
                width: monthFlick.width
                property var dayRows: root.service ? root.service.monthRows : []
                property real scale: root.s

                Row {
                    id: monthHeader
                    width: parent.width
                    height: 20 * monthTable.scale

                    Text {
                        width: 54 * monthTable.scale
                        anchors.verticalCenter: parent.verticalCenter
                        text: "DAY"
                        color: Theme.faint
                        font.family: Theme.mono
                        font.pixelSize: 9.5 * monthTable.scale
                    }

                    Repeater {
                        model: ["FAJR", "SUNRISE", "DHUHR", "ASR", "MAGHRIB", "ISHA"]
                        delegate: Text {
                            required property string modelData
                            width: (monthHeader.width - 54 * monthTable.scale) / 6
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignRight
                            text: modelData
                            color: Theme.faint
                            font.family: Theme.mono
                            font.pixelSize: 9.5 * monthTable.scale
                        }
                    }
                }

                Repeater {
                    model: monthTable.dayRows
                    delegate: Item {
                        id: monthRow
                        required property var modelData
                        width: monthTable.width
                        height: 22 * monthTable.scale

                        Rectangle {
                            anchors.fill: parent
                            visible: monthRow.modelData.today
                            color: Theme.cardTop
                            radius: Theme.radius
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
                            width: 46 * monthTable.scale
                            anchors.verticalCenter: parent.verticalCenter
                            text: monthRow.modelData.day
                            color: monthRow.modelData.today ? Theme.bright : Theme.dim
                            font.family: Theme.font
                            font.pixelSize: 10 * monthTable.scale
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Row {
                            id: monthTimes
                            x: 54 * monthTable.scale
                            width: parent.width - x
                            height: parent.height

                            Repeater {
                                model: ["fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha"]
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
