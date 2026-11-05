pragma ComponentBehavior: Bound
import QtQuick
import Ryoku.PluginKit.Singletons
import "../service/menu.js" as M
import "../service/themes.js" as Themes

// The Customize page: the theme, and which options the menu offers. Shown in the
// bar panel (when its icon is on) and in the Customize window (Super+Shift+U,
// or `qs -c shell ipc call utsuri customize`). Writes go through svc, which
// keeps them in stateDir/prefs.json.
Column {
    id: page

    property var svc: null
    property real s: 1
    readonly property var catalogue: M.catalogue()

    spacing: 10 * page.s

    component Label: Text {
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: 11 * page.s
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 1.2
    }

    component Note: Text {
        width: page.width
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: 11 * page.s
        wrapMode: Text.Wrap
    }

    component Chip: Rectangle {
        id: chip
        property string label: ""
        property bool off: false
        signal clicked()

        width: chipText.implicitWidth + 20 * page.s
        height: chipText.implicitHeight + 12 * page.s
        radius: Theme.radius
        opacity: chip.off ? 0.45 : 1
        color: chipArea.pressed ? Theme.vermDeep : chipArea.containsMouse ? Theme.threadBg : Theme.tileBg
        border.width: 1
        border.color: chipArea.containsMouse ? Theme.accent : Theme.hair

        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            color: Theme.bright
            font.family: Theme.font
            font.pixelSize: 12 * page.s
            font.strikeout: chip.off
        }
        MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: chip.clicked()
        }
    }

    Label { text: "Theme" }
    Flow {
        width: page.width
        spacing: 8 * page.s
        Repeater {
            model: Themes.THEMES
            delegate: Rectangle {
                id: sw
                required property var modelData
                readonly property var look: Themes.resolve(sw.modelData.id, Theme)
                readonly property bool chosen: !!page.svc && page.svc.themeId === sw.modelData.id
                width: 74 * page.s
                height: 64 * page.s
                radius: Theme.radius
                color: swArea.containsMouse ? Theme.threadBg : Theme.tileBg
                border.width: sw.chosen ? 2 : 1
                border.color: sw.chosen ? Theme.accent : Theme.hair
                // a tiny menu: the body colour inside its accent ring
                Rectangle {
                    x: (parent.width - width) / 2
                    y: 8 * page.s
                    width: 30 * page.s
                    height: width
                    radius: width / 2
                    gradient: Gradient {
                        GradientStop { position: 0; color: sw.look.themed ? sw.look.tint : Qt.rgba(1, 1, 1, 0.55) }
                        GradientStop { position: 1; color: sw.look.themed ? sw.look.tint : Qt.rgba(0.6, 0.7, 1, 0.18) }
                    }
                    border.width: 3 * page.s
                    border.color: sw.look.themed ? sw.look.accent : Qt.rgba(0.85, 0.75, 1, 0.9)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 44 * page.s
                    text: sw.modelData.name
                    color: sw.chosen ? Theme.bright : Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 11 * page.s
                }
                MouseArea {
                    id: swArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: page.svc.setTheme(sw.modelData.id)
                }
            }
        }
    }
    Note { text: "Transparent is the original glass. Matugen uses your Ryoku colours: the wallpaper's while Match wallpaper is on, otherwise your chosen Ryoku theme's, and updates the moment they change." }

    Item {
        width: page.width
        height: optLabel.implicitHeight
        Label { id: optLabel; text: "Menu options" }
        Chip {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: !!page.svc && page.svc.hidden.length > 0
            label: "Turn all back on"
            onClicked: page.svc.showAll()
        }
    }
    Note { text: "Tap an option to turn it off; struck-out options leave the Shift+drag menu and the panel. Tap again to bring it back." }
    Repeater {
        model: page.catalogue
        delegate: Column {
            id: grp
            required property var modelData
            width: page.width
            spacing: 5 * page.s
            Text {
                text: grp.modelData.title
                color: Theme.bright
                font.family: Theme.font
                font.pixelSize: 12 * page.s
                font.bold: true
            }
            Flow {
                width: page.width
                spacing: 5 * page.s
                Repeater {
                    model: grp.modelData.items
                    delegate: Chip {
                        required property var modelData
                        label: modelData.label
                        off: !!page.svc && page.svc.hidden.indexOf(modelData.key) !== -1
                        onClicked: page.svc.setHidden(modelData.key, !off)
                    }
                }
            }
        }
    }
}
