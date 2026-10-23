import QtQuick
import Quickshell.Io
import "../../../services"
import "../../../modules/common"
import "../../../modules/common/widgets"

SettingsPage {
    id: page

    readonly property string version: versionFile.loaded ? versionFile.text().trim() : ""

    FileView {
        id: versionFile
        path: Directories.shell + "/VERSION"
        blockLoading: true
        printErrors: false
    }

    SectionCard {
        id: heroCard
        title: "This barstyle"

        Item {
            width: 96
            height: 96

            Rectangle {
                x: Theme.quickFlat ? 0 : 5
                y: 4
                width: 90
                height: 90
                radius: 45
                color: Theme.pLineShadow
                antialiasing: true
            }

            Rectangle {
                width: 90
                height: 90
                radius: 45
                color: Theme.pSurface
                border.width: 5
                border.color: Theme.pLine
                antialiasing: true

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 11
                    radius: width / 2
                    antialiasing: true
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Theme.accentMint }
                        GradientStop { position: 1.0; color: Theme.accentCyan }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        size: 38
                        name: "palette"
                        weight: Theme.settingsIconWeight
                        fill: Theme.iconFill
                        color: Theme.colBorder
                    }
                }
            }
        }

        Column {
            width: page.fullWidth - 96 - 16
            height: 96
            spacing: 2

            Text {
                text: "Tansu"
                color: Theme.pInk
                font.family: Theme.fontFamily
                font.pixelSize: 34
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }

            Text {
                text: "The Tansu bar and phone, ported to Ryoku (GPL-3.0-only)."
                color: Theme.pInkSub
                font.family: Theme.fontFamily
                font.pixelSize: 17
            }

            Row {
                spacing: 10
                topPadding: 8

                SettingChip {
                    label: "Ported by dodo986"
                    icon: "sell"
                    selected: true
                    enabled: false
                }

                SettingChip {
                    label: page.version !== "" ? "v" + page.version : ""
                    icon: "info"
                    enabled: false
                }

                SettingChip {
                    label: SettingsService.changedCount === 0 ? "Default settings"
                        : SettingsService.changedCount + (SettingsService.changedCount === 1 ? " setting changed" : " settings changed")
                    icon: "tune"
                }
            }
        }
    }

    SectionCard {
        title: "Credits"

        Repeater {
            model: [
                { who: "dodo986", what: "This port: the bar and the phone, wired to Ryoku's services" },
                { who: "Blapples", what: "The original shell this barstyle is ported from (GPL-3.0)" },
                { who: "Ryoku", what: "The shell, its services and its Material palette" },
                { who: "Quickshell", what: "The toolkit the bar and the phone are drawn with" },
                { who: "Solar Icon Set", what: "The icons the bar draws" },
                { who: "Material Symbols & Google Sans Flex", what: "Fallback icons, and the letters" },
                { who: "Open-Meteo", what: "Weather data" }
            ]

            delegate: Column {
                required property var modelData
                width: page.halfWidth
                spacing: 1

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: modelData.who
                    color: Theme.pInk
                    font.family: Theme.fontFamily
                    font.pixelSize: 17
                    font.weight: Font.ExtraBold
                    font.styleName: Theme.fontStyleBold
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: modelData.what
                    color: Theme.pInkSub
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                }
            }
        }
    }
}
