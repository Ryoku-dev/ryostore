import QtQuick
import "."

Item {
    id: root
    property real scaleFactor: 1.0

    implicitWidth: 380
    implicitHeight: 245

    // ─── Theme Palette ───
    readonly property color colBg: Theme.colBgTile
    readonly property color colBadgeBg: Theme.colPillBg
    readonly property color colTextPrimary: Theme.colTextPrimary
    readonly property color colTextSecondary: Theme.colTextSecondary
    readonly property color colTextMuted: Theme.isGlass ? "#88A5BA" : "#6B7880"
    readonly property color colTodayCircle: Theme.colAccentGreen
    readonly property color colTodayText: Theme.colBg

    property var todayDate: new Date()
    property string monthName: ""
    property string yearString: ""
    property string fullDateFormatted: ""
    property var calendarModel: []

    function updateCalendar() {
        var now = new Date()
        root.todayDate = now
        var months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
        var daysOfWeek = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

        root.monthName = months[now.getMonth()]
        root.yearString = now.getFullYear().toString()
        root.fullDateFormatted = daysOfWeek[now.getDay()] + ", " + months[now.getMonth()].slice(0, 3) + " " + now.getDate()

        var year = now.getFullYear()
        var month = now.getMonth()
        var firstDay = new Date(year, month, 1).getDay()
        var daysInMonth = new Date(year, month + 1, 0).getDate()
        var daysInPrevMonth = new Date(year, month, 0).getDate()

        var list = []
        for (var i = firstDay - 1; i >= 0; i--) {
            list.push({
                day: (daysInPrevMonth - i).toString(),
                isCurrent: false,
                isToday: false
            })
        }

        var todayNum = now.getDate()
        for (var d = 1; d <= daysInMonth; d++) {
            list.push({
                day: d.toString(),
                isCurrent: true,
                isToday: (d === todayNum)
            })
        }

        var totalNeeded = list.length > 35 ? 42 : 35
        var nextCount = totalNeeded - list.length
        for (var n = 1; n <= nextCount; n++) {
            list.push({
                day: n.toString(),
                isCurrent: false,
                isToday: false
            })
        }

        root.calendarModel = list
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.updateCalendar()
    }

    // ─── Scaled Visual Content ───
    Item {
        id: scaledContent
        width: 380
        height: 245
        scale: root.scaleFactor
        transformOrigin: Item.TopLeft

        // ─── Calendar Card ───
        Rectangle {
            anchors.fill: parent
            color: root.colBg
            radius: 32
            border.color: Theme.borderColor
            border.width: Theme.borderWidth
            clip: true
            antialiasing: true

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1.5
                color: Theme.glassGloss
                visible: Theme.isGlass
            }

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                Row {
                    width: parent.width

                    Column {
                        spacing: 2
                        Text {
                            text: (root.monthName + " " + root.yearString).toUpperCase()
                            color: root.colTextPrimary
                            font.pixelSize: 13
                            font.bold: true
                            font.letterSpacing: 1.0
                            font.family: "Google Sans Flex, Google Sans, Space Grotesk, Inter, sans-serif"
                        }
                        Text {
                            text: root.fullDateFormatted
                            color: root.colTextSecondary
                            font.pixelSize: 11
                            font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                        }
                    }

                    Item {
                        width: Math.max(0, parent.width - (parent.children[0].width + calendarBadge.width))
                        height: 1
                    }

                    Rectangle {
                        id: calendarBadge
                        height: 24
                        width: badgeRow.implicitWidth + 16
                        radius: 12
                        color: root.colBadgeBg
                        antialiasing: true

                        Row {
                            id: badgeRow
                            anchors.centerIn: parent
                            spacing: 6

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 7
                                height: 7
                                radius: 3.5
                                color: root.colTodayCircle
                                antialiasing: true
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "CALENDAR"
                                color: root.colTextPrimary
                                font.pixelSize: 9
                                font.bold: true
                                font.letterSpacing: 0.6
                                font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#1AFFFFFF"
                }

                Grid {
                    width: parent.width
                    columns: 7
                    spacing: 0

                    Repeater {
                        model: ["S", "M", "T", "W", "T", "F", "S"]
                        Item {
                            width: Math.floor(parent.width / 7)
                            height: 18

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: (index === 0 || index === 6) ? "#FFD8D0" : root.colTextSecondary
                                font.pixelSize: 11
                                font.bold: true
                                font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                            }
                        }
                    }
                }

                Grid {
                    width: parent.width
                    columns: 7
                    spacing: 0

                    Repeater {
                        model: root.calendarModel
                        Item {
                            width: Math.floor(parent.width / 7)
                            height: 24

                            Rectangle {
                                visible: modelData.isToday
                                anchors.centerIn: parent
                                width: 22
                                height: 22
                                radius: 11
                                color: root.colTodayCircle
                                antialiasing: true
                            }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.day
                                color: modelData.isToday ? root.colTodayText : (modelData.isCurrent ? root.colTextPrimary : root.colTextMuted)
                                font.pixelSize: 11
                                font.bold: modelData.isToday || modelData.isCurrent
                                font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                            }
                        }
                    }
                }
            }
        }
    }
}
