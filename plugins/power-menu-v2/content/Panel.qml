import QtQuick
import QtQuick.Effects
import Ryoku.PluginKit.Singletons

// Profile-style power panel: avatar, name, Ryoku version badge, host and uptime,
// a Settings button, then the session actions in one sunken group. All colour
// comes from the plugin kit Theme, so the panel follows the Ryoku theme.
Item {
    id: root

    property var pluginApi
    property string density: "full"
    property real s: 1
    property real widthBudget: 280
    property bool active: false

    readonly property var service: pluginApi ? pluginApi.mainInstance : null

    // Local geometry and tints. The kit's Theme.radius is 0, so the rounded
    // corners of this design are held here.
    readonly property real groupRadius: 10 * root.s
    readonly property real smallRadius: 4 * root.s
    readonly property real avatarSize: 64 * root.s
    readonly property color hoverFill: Qt.rgba(Theme.bright.r, Theme.bright.g, Theme.bright.b, 0.09)
    readonly property color armedFill: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
    readonly property color sunken: Qt.rgba(0, 0, 0, 0.25)

    readonly property var shownActions: {
        var list = root.service ? root.service.actions : [];
        return list.filter(function(a) { return root.service.enabled(a.id); });
    }

    function glyph(code) {
        return String.fromCodePoint(code);
    }

    implicitWidth: root.widthBudget
    implicitHeight: col.implicitHeight + 36 * root.s

    onActiveChanged: if (root.active && root.service) root.service.refresh()
    Component.onCompleted: if (root.service) root.service.refresh()

    // Keep the uptime fresh while the panel stays open.
    Timer {
        interval: 60000
        repeat: true
        running: root.visible
        onTriggered: if (root.service) root.service.refresh()
    }

    Column {
        id: col
        y: 24 * root.s
        width: root.width
        spacing: 6 * root.s

        // ── avatar ──
        Item {
            id: avatar
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.avatarSize
            height: root.avatarSize

            readonly property bool ready: photo.status === Image.Ready
            readonly property real fz: root.service ? root.service.zoom : 1
            readonly property real fx: root.service ? root.service.focalX : 0.5
            readonly property real fy: root.service ? root.service.focalY : 0.5

            // Placeholder: neutral disc with a person glyph.
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Theme.hair
                visible: !avatar.ready

                Text {
                    anchors.centerIn: parent
                    text: root.glyph(0xF0004)
                    color: Theme.dim
                    font.family: Theme.mono
                    font.pixelSize: 32 * root.s
                }
            }

            // The hero image, scaled to cover the circle and positioned so the
            // Hub's focal point sits in the centre (clamped to the image edges).
            Item {
                id: crop
                anchors.fill: parent
                clip: true
                visible: false
                layer.enabled: true

                Image {
                    id: photo
                    source: root.service && root.service.avatarPath !== "" ? "file://" + root.service.avatarPath : ""
                    asynchronous: true
                    cache: true
                    sourceSize.width: 384
                    fillMode: Image.Stretch
                    smooth: true

                    readonly property real iw: Math.max(1, implicitWidth)
                    readonly property real ih: Math.max(1, implicitHeight)
                    readonly property real k: Math.max(crop.width / iw, crop.height / ih) * avatar.fz

                    width: iw * k
                    height: ih * k
                    x: Math.min(0, Math.max(crop.width - width, crop.width / 2 - avatar.fx * width))
                    y: Math.min(0, Math.max(crop.height - height, crop.height / 2 - avatar.fy * height))
                }
            }

            Item {
                id: circleMask
                anchors.fill: parent
                visible: false
                layer.enabled: true

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "black"
                }
            }

            MultiEffect {
                anchors.fill: parent
                visible: avatar.ready
                source: crop
                maskEnabled: true
                maskSource: circleMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }
        }

        Item { width: 1; height: 2 * root.s }

        // ── name ──
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, root.width - 32 * root.s)
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.service ? root.service.name : ""
            color: Theme.bright
            font.family: Theme.mono
            font.pixelSize: 16 * root.s
            font.weight: Font.Medium
        }

        // ── version badge ──
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.service !== null && root.service.version !== ""
            width: badge.implicitWidth + 16 * root.s
            height: badge.implicitHeight + 5 * root.s
            radius: root.smallRadius
            color: Theme.accent

            Text {
                id: badge
                anchors.centerIn: parent
                text: "Ryoku " + (root.service ? root.service.version : "")
                color: Theme.cardBot
                font.family: Theme.mono
                font.pixelSize: 11 * root.s
                font.weight: Font.Medium
            }
        }

        // ── host · uptime ──
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: text !== ""
            text: root.service ? root.service.subtitle : ""
            color: Theme.dim
            font.family: Theme.mono
            font.pixelSize: 11 * root.s
        }

        Item { width: 1; height: 6 * root.s }

        // ── settings ──
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: settingsRow.implicitWidth + 24 * root.s
            height: settingsRow.implicitHeight + 10 * root.s
            radius: root.smallRadius
            color: settingsArea.containsMouse ? root.hoverFill : "transparent"
            border.width: 1
            border.color: Theme.hair
            Behavior on color { ColorAnimation { duration: 120 } }

            Row {
                id: settingsRow
                anchors.centerIn: parent
                spacing: 6 * root.s

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.glyph(0xF0493)
                    color: Theme.bright
                    font.family: Theme.mono
                    font.pixelSize: 13 * root.s
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Settings"
                    color: Theme.bright
                    font.family: Theme.mono
                    font.pixelSize: 12 * root.s
                }
            }

            MouseArea {
                id: settingsArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.service) root.service.openSettings()
            }
        }

        Item { width: 1; height: 10 * root.s }

        // ── action group ──
        Rectangle {
            id: group
            visible: root.shownActions.length > 0
            x: 12 * root.s
            width: root.width - 24 * root.s
            height: actionsCol.implicitHeight + 2
            radius: root.groupRadius
            color: root.sunken
            border.width: 1
            border.color: Theme.hair

            Column {
                id: actionsCol
                x: 1
                y: 1
                width: parent.width - 2

                Repeater {
                    model: root.shownActions

                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index

                        readonly property bool armedNow: root.service !== null && root.service.armed === row.modelData.id
                        readonly property bool hot: area.containsMouse
                        readonly property bool isFirst: row.index === 0
                        readonly property bool isLast: row.index === root.shownActions.length - 1
                        readonly property color fill: row.armedNow ? root.armedFill : (row.hot ? root.hoverFill : "transparent")
                        readonly property color ink: row.armedNow ? Theme.accent : (row.hot ? Theme.bright : Theme.dim)

                        width: actionsCol.width
                        height: 36 * root.s

                        // Highlight that follows the group's rounded corners on
                        // the first and last rows: a rounded rectangle stretched
                        // past the side that meets a neighbour row, then clipped,
                        // so only the outer corners stay round (no alpha overlap).
                        Item {
                            anchors.fill: parent
                            clip: true

                            Rectangle {
                                readonly property real r: (row.isFirst || row.isLast) ? root.groupRadius - 1 : 0
                                readonly property real extTop: row.isFirst ? 0 : r
                                readonly property real extBottom: row.isLast ? 0 : r
                                y: -extTop
                                width: parent.width
                                height: parent.height + extTop + extBottom
                                radius: r
                                color: row.fill
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 16 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10 * root.s

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 18 * root.s
                                text: root.glyph(row.modelData.glyph)
                                color: row.ink
                                font.family: Theme.mono
                                font.pixelSize: 15 * root.s
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.modelData.label
                                color: row.ink
                                font.family: Theme.mono
                                font.pixelSize: 13 * root.s
                                font.weight: row.armedNow ? Font.Medium : Font.Normal
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: row.armedNow
                                text: "\u00B7 confirm"
                                color: Theme.accent
                                font.family: Theme.mono
                                font.pixelSize: 11 * root.s
                            }
                        }

                        MouseArea {
                            id: area
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (root.service) root.service.run(row.modelData.id)
                        }
                    }
                }
            }
        }
    }
}
