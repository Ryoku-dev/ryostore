import "../../common"
import "../../common/widgets"
import "../../../services"
import QtQuick
import QtQuick.Layouts
import "../../../shared" as Shared
import "../../../popouts" as Popouts

BarWidgetSwitcher {
    id: root
    property bool borderless: Config.options.bar.borderless
    property bool showDate: Config.options.bar.verbose
    property var today: new Date()
    readonly property string dateTimeString: DateTime.time
    readonly property bool hasAmPm: dateTimeString.toLowerCase().includes("am") || dateTimeString.toLowerCase().includes("pm")

    HoverHandler { id: hh }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: 11
        color: hh.hovered ? Qt.rgba(0, 0, 0, 0.18) : "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    Shared.Popout {
        target: root
        targetHovered: hh.hovered
        preferredWidth: 320
        preferredHeight: 220
        namespace: "ryoku-bar-popout"
        content: Component {
            Popouts.CalendarPopout {}
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.today = new Date()
    }

    colDefault: Component {
        ColumnLayout {
            id: column
            anchors.centerIn: parent
            spacing: root.hasAmPm ? Appearance.spacing.space25 : 0

            Column {
                Layout.alignment: Qt.AlignHCenter
                spacing: -Appearance.spacing.space50

                Repeater {
                    model: root.dateTimeString.split(/[: ]/)
                    delegate: StyledText {
                        required property string modelData
                        width: implicitWidth
                        horizontalAlignment: Text.AlignHCenter
                        font.letterSpacing: -0.2
                        font.features: { "tnum": 1 }
                        font.pixelSize: {
                            if (modelData.match(/am|pm/i))
                                return Appearance.font.pixelSize.smaller;
                            else
                                return Appearance.font.pixelSize.large;
                        }
                        font.weight: {
                            if (modelData.match(/am|pm/i))
                                return Font.Normal;
                            else
                                return Font.Bold;
                        }
                        color: Appearance.colors.colOnLayer1
                        text: modelData
                    }
                }
            }
        }
    }

    colMaterial: Component {
        ColumnLayout {
            id: column
            anchors.centerIn: parent
            spacing: root.hasAmPm ? Appearance.spacing.space25 : 0

            Column {
                Layout.alignment: Qt.AlignHCenter
                spacing: -Appearance.spacing.space50

                Repeater {
                    model: root.dateTimeString.split(/[: ]/)
                    delegate: StyledText {
                        required property string modelData
                        width: implicitWidth
                        horizontalAlignment: Text.AlignHCenter
                        font.letterSpacing: -0.2
                        font.features: { "tnum": 1 }
                        font.pixelSize: {
                            if (modelData.match(/am|pm/i))
                                return Appearance.font.pixelSize.smaller;
                            else
                                return Appearance.font.pixelSize.large;
                        }
                        font.weight: {
                            if (modelData.match(/am|pm/i))
                                return Font.Normal;
                            else
                                return Font.Bold;
                        }
                        color: Appearance.colors.colOnPrimaryContainer
                        text: modelData
                    }
                }
            }
        }
    }

    rowDefault: Component {
        RowLayout {
            spacing: Appearance.spacing.space50
            StyledText {
                visible: root.showDate
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
                text: DateTime.longDate
            }
            StyledText {
                visible: root.showDate
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
                text: "•"
            }
            StyledText {
                font.pixelSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnLayer1
                text: DateTime.time
                font.letterSpacing: -0.4
                font.features: { "tnum": 1 }
            }
        }
    }

    rowMaterial: Component {
        RowLayout {
            spacing: 6
            Layout.alignment: Qt.AlignVCenter

            StyledText {
                visible: root.showDate
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnPrimaryContainer
                opacity: 0.85
                text: DateTime.longDate
                Layout.alignment: Qt.AlignVCenter
                leftPadding: 6
            }

            StyledText {
                visible: root.showDate
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnPrimaryContainer
                opacity: 0.4
                text: "·"
                Layout.alignment: Qt.AlignVCenter
            }

            StyledText {
                id: timeText
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnPrimaryContainer
                font.weight: Font.Bold
                text: DateTime.time
                font.features: { "tnum": 1 }
                font.letterSpacing: -0.2
                Layout.alignment: Qt.AlignVCenter
                rightPadding: 6
            }
        }
    }
}
