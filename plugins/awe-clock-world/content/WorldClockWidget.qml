import QtQuick
import "."

Item {
    id: root
    // UI Shape & Layout Styles:
    // 0: Classic M3 Card, 1: Floating Multi-Pills, 2: 2-Column Grid Tiles, 3: Arch Expressive
    property int shapeStyleIndex: 0
    property var styleNames: ["Classic Card", "Floating Pills", "Grid Tiles", "Arch Expressive"]

    implicitWidth: 290
    implicitHeight: root.shapeStyleIndex === 2 ? 80 + Math.ceil(root.cities.length / 2) * 68 : (root.shapeStyleIndex === 1 ? 60 + root.cities.length * 42 : 70 + Math.max(2, root.cities.length) * 34)

    // Cities List with timezone offsets in hours
    property var cities: [
        { name: "London", zone: "UTC", offset: 0, tag: "UTC+0" },
        { name: "New York", zone: "EDT", offset: -4, tag: "UTC-4" },
        { name: "Tokyo", zone: "JST", offset: 9, tag: "UTC+9" }
    ]

    property var currentTime: new Date()

    function getTimeForOffset(offsetHours) {
        var now = root.currentTime
        var utcMs = now.getTime() + (now.getTimezoneOffset() * 60000)
        var cityDate = new Date(utcMs + (offsetHours * 3600000))
        var h = cityDate.getHours()
        var m = cityDate.getMinutes()
        var h12 = h % 12 || 12
        var ampm = h >= 12 ? "PM" : "AM"
        var isNight = h < 6 || h >= 19
        return {
            timeStr: (h12 < 10 ? "0" + h12 : h12) + ":" + (m < 10 ? "0" + m : m),
            ampm: ampm,
            isNight: isNight
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.currentTime = new Date()
    }

    // Theme Palette
    readonly property color colBg: Theme.colBg
    readonly property color colPillBg: Theme.colPillBg
    readonly property color colAccent: Theme.colAccent
    readonly property color colAccentSun: Theme.colAccentWarning
    readonly property color colAccentMoon: Theme.colAccentWarm
    readonly property color colTextPrimary: Theme.colTextPrimary
    readonly property color colTextSecondary: Theme.colTextSecondary

    // ─── Scaled Visual Content ───
    Item {
        id: scaledContent
        width: 290
        height: (root.shapeStyleIndex === 2 ? 80 + Math.ceil(root.cities.length / 2) * 68 : (root.shapeStyleIndex === 1 ? 60 + root.cities.length * 42 : 70 + Math.max(2, root.cities.length) * 34))
        transformOrigin: Item.TopLeft

        // Double-click cycles the layout style (in-memory only); press still falls through for host drag.
        MouseArea {
            anchors.fill: parent
            propagateComposedEvents: true
            onDoubleClicked: (mouse) => {
                root.shapeStyleIndex = (root.shapeStyleIndex + 1) % 4
                mouse.accepted = false
            }
        }

        // ════════════════════════════════════════════════════════════════
        // VARIANT 0: Classic M3 Elevated Card (shapeStyleIndex === 0)
        // ════════════════════════════════════════════════════════════════
        Rectangle {
            visible: root.shapeStyleIndex === 0
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
                anchors.margins: 14
                spacing: 8

                // Header Row
                Row {
                    width: parent.width

                    Rectangle {
                        height: 22
                        width: b0Row.implicitWidth + 16
                        radius: 11
                        color: root.colPillBg
                        antialiasing: true

                        Row {
                            id: b0Row
                            anchors.centerIn: parent
                            spacing: 6

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 7
                                height: 7
                                radius: 3.5
                                color: root.colAccent
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "TIMEZONES"
                                color: "#FFFFFF"
                                font.pixelSize: 9
                                font.bold: true
                                font.letterSpacing: 0.6
                                font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                            }
                        }
                    }

                    Item {
                        width: Math.max(0, parent.width - parent.children[0].width - r0Row.width)
                        height: 1
                    }

                    Row {
                        id: r0Row
                        spacing: 6
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            height: 20
                            width: st0Text.implicitWidth + 10
                            radius: 10
                            color: root.colPillBg
                            antialiasing: true

                            Text {
                                id: st0Text
                                anchors.centerIn: parent
                                text: root.styleNames[root.shapeStyleIndex]
                                color: root.colAccent
                                font.pixelSize: 9
                                font.bold: true
                                font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                            }
                        }

                    }
                }

                // City List
                Column {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: root.cities

                        Rectangle {
                            width: parent.width
                            height: 28
                            radius: 14
                            color: root.colPillBg
                            antialiasing: true

                            property var timeInfo: root.getTimeForOffset(modelData.offset)

                            Row {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 8

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: timeInfo.isNight ? root.colAccentMoon : root.colAccentSun
                                    antialiasing: true
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.name
                                    color: "#FFFFFF"
                                    font.pixelSize: 11
                                    font.bold: true
                                    font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                                }

                                Item {
                                    width: Math.max(0, parent.width - 8 - 80 - t0Row.width)
                                    height: 1
                                }

                                Row {
                                    id: t0Row
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: timeInfo.timeStr
                                        color: "#FFFFFF"
                                        font.pixelSize: 12
                                        font.bold: true
                                        font.family: "Google Sans Flex, Google Sans, Inter, monospace"
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: timeInfo.ampm
                                        color: "#9CA8AC"
                                        font.pixelSize: 9
                                        font.bold: true
                                        font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                                    }

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 14
                                        width: off0Text.implicitWidth + 8
                                        radius: 7
                                        color: "#1FFFFFFF"
                                        antialiasing: true

                                        Text {
                                            id: off0Text
                                            anchors.centerIn: parent
                                            text: modelData.tag
                                            color: root.colAccent
                                            font.pixelSize: 8
                                            font.bold: true
                                            font.family: "Google Sans Flex, Google Sans, Inter, monospace"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ════════════════════════════════════════════════════════════════
        // VARIANT 1: Floating Multi-Pill Pods (shapeStyleIndex === 1)
        // ════════════════════════════════════════════════════════════════
        Column {
            visible: root.shapeStyleIndex === 1
            anchors.fill: parent
            spacing: 6

            // Floating Header Pill
            Rectangle {
                width: parent.width
                height: 30
                radius: 15
                color: root.colBg
                border.color: "#1FFFFFFF"
                border.width: 1.5
                antialiasing: true

                Row {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 7
                        height: 7
                        radius: 3.5
                        color: root.colAccent
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "TIMEZONES · PODS"
                        color: "#FFFFFF"
                        font.pixelSize: 9
                        font.bold: true
                        font.letterSpacing: 0.5
                        font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                    }

                }
            }

            // Stacked Floating Stadium Pods
            Repeater {
                model: root.cities

                Rectangle {
                    width: parent.width
                    height: 36
                    radius: 18
                    color: root.colBg
                    border.color: "#1FFFFFFF"
                    border.width: 1.5
                    antialiasing: true

                    property var timeInfo: root.getTimeForOffset(modelData.offset)

                    Row {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 10
                            height: 10
                            radius: 5
                            color: timeInfo.isNight ? root.colAccentMoon : root.colAccentSun
                            antialiasing: true
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.name
                            color: "#FFFFFF"
                            font.pixelSize: 12
                            font.bold: true
                            font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                        }

                        Item {
                            width: Math.max(0, parent.width - 100 - t1Row.width)
                            height: 1
                        }

                        Row {
                            id: t1Row
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: timeInfo.timeStr
                                color: root.colAccent
                                font.pixelSize: 13
                                font.bold: true
                                font.family: "Google Sans Flex, Google Sans, Inter, monospace"
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: timeInfo.ampm
                                color: "#9CA8AC"
                                font.pixelSize: 9
                                font.bold: true
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                height: 16
                                width: off1Text.implicitWidth + 8
                                radius: 8
                                color: root.colPillBg
                                antialiasing: true

                                Text {
                                    id: off1Text
                                    anchors.centerIn: parent
                                    text: modelData.tag
                                    color: "#FFFFFF"
                                    font.pixelSize: 8
                                    font.bold: true
                                    font.family: "Google Sans Flex, Google Sans, Inter, monospace"
                                }
                            }
                        }
                    }
                }
            }
        }

        // ════════════════════════════════════════════════════════════════
        // VARIANT 2: 2-Column Grid Tiles (shapeStyleIndex === 2)
        // ════════════════════════════════════════════════════════════════
        Rectangle {
            visible: root.shapeStyleIndex === 2
            anchors.fill: parent
            color: root.colBg
            radius: 32
            border.color: "#1FFFFFFF"
            border.width: 1.5
            antialiasing: true

            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                // Header
                Row {
                    width: parent.width

                    Rectangle {
                        height: 22
                        width: b2Row.implicitWidth + 16
                        radius: 11
                        color: root.colPillBg
                        antialiasing: true

                        Row {
                            id: b2Row
                            anchors.centerIn: parent
                            spacing: 6

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 7
                                height: 7
                                radius: 3.5
                                color: root.colAccent
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "TIMEZONES · GRID"
                                color: "#FFFFFF"
                                font.pixelSize: 9
                                font.bold: true
                                font.letterSpacing: 0.5
                                font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                            }
                        }
                    }

                }

                // Grid Tiles
                Grid {
                    width: parent.width
                    columns: 2
                    spacing: 6

                    Repeater {
                        model: root.cities

                        Rectangle {
                            width: (parent.width - 6) / 2
                            height: 60
                            radius: 18
                            color: root.colPillBg
                            antialiasing: true

                            property var timeInfo: root.getTimeForOffset(modelData.offset)

                            Column {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 2

                                Row {
                                    width: parent.width

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 6
                                        height: 6
                                        radius: 3
                                        color: timeInfo.isNight ? root.colAccentMoon : root.colAccentSun
                                    }

                                    Item { width: 4; height: 1 }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.name
                                        color: "#9CA8AC"
                                        font.pixelSize: 10
                                        font.bold: true
                                        elide: Text.ElideRight
                                        width: parent.width - 50
                                    }

                                    Item { width: Math.max(0, parent.width - 6 - (parent.width - 50) - 30); height: 1 }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.tag
                                        color: root.colAccent
                                        font.pixelSize: 8
                                        font.bold: true
                                    }
                                }

                                Text {
                                    text: timeInfo.timeStr + " " + timeInfo.ampm
                                    color: "#FFFFFF"
                                    font.pixelSize: 14
                                    font.bold: true
                                    font.family: "Google Sans Flex, Google Sans, Inter, monospace"
                                }
                            }
                        }
                    }
                }
            }
        }

        // ════════════════════════════════════════════════════════════════
        // VARIANT 3: Arch Expressive (shapeStyleIndex === 3)
        // ════════════════════════════════════════════════════════════════
        Rectangle {
            visible: root.shapeStyleIndex === 3
            anchors.fill: parent
            color: root.colBg
            radius: 40
            border.color: root.colAccent
            border.width: 1.5
            antialiasing: true

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 8

                // Header Arched Arch
                Row {
                    width: parent.width

                    Rectangle {
                        height: 24
                        width: b3Row.implicitWidth + 18
                        radius: 12
                        color: root.colAccent
                        antialiasing: true

                        Row {
                            id: b3Row
                            anchors.centerIn: parent
                            spacing: 6

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 7
                                height: 7
                                radius: 3.5
                                color: "#1E2A30"
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "EXPRESSIVE ARCH"
                                color: "#1E2A30"
                                font.pixelSize: 9
                                font.bold: true
                                font.letterSpacing: 0.6
                                font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                            }
                        }
                    }

                }

                // Vertical Timeline Flow
                Column {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: root.cities

                        Rectangle {
                            width: parent.width
                            height: 28
                            radius: 14
                            color: root.colPillBg
                            antialiasing: true

                            property var timeInfo: root.getTimeForOffset(modelData.offset)

                            Row {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 8

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: timeInfo.isNight ? root.colAccentMoon : root.colAccentSun
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.name
                                    color: "#FFFFFF"
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                Item {
                                    width: Math.max(0, parent.width - 8 - 80 - t3Row.width)
                                    height: 1
                                }

                                Row {
                                    id: t3Row
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: timeInfo.timeStr
                                        color: root.colAccent
                                        font.pixelSize: 12
                                        font.bold: true
                                        font.family: "Google Sans Flex, Google Sans, Inter, monospace"
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: timeInfo.ampm
                                        color: "#9CA8AC"
                                        font.pixelSize: 9
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
