pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Ryoku.PluginKit.Singletons
import "../content"

// The Customize page in its own window, for when the bar icon is off: Super+Shift+U
// (the bind in hypr/trigger.lua) or `qs -c shell ipc call utsuri customize`.
// A dimmed overlay with a centred card; Esc, Done or a click outside closes it.
Scope {
    id: win

    property var svc: null
    property var screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    property bool open: false

    function toggle(onScreen) {
        if (!win.open && onScreen)
            win.screen = onScreen;
        win.open = !win.open;
    }

    LazyLoader {
        active: win.open
        PanelWindow {
            id: surface
            screen: win.screen
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "utsuri-customize"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            exclusionMode: ExclusionMode.Ignore
            anchors { left: true; right: true; top: true; bottom: true }
            color: Qt.rgba(0, 0, 0, 0.35)

            MouseArea {   // a click outside the card closes
                anchors.fill: parent
                onClicked: win.open = false
            }

            Rectangle {
                id: card
                readonly property real pad: 18
                width: 420
                height: Math.min(head.height + page.implicitHeight + 3 * pad, surface.height - 80)
                anchors.centerIn: parent
                radius: Math.max(Theme.radius, 12)
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.cardTop }
                    GradientStop { position: 1; color: Theme.cardBot }
                }
                border.width: 1
                border.color: Theme.border
                focus: true
                Keys.onEscapePressed: win.open = false

                MouseArea { anchors.fill: parent }   // clicks on the card stay on the card

                Item {
                    id: head
                    x: card.pad
                    y: card.pad
                    width: card.width - 2 * card.pad
                    height: done.height
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Utsuri · Customize"
                        color: Theme.bright
                        font.family: Theme.display
                        font.pixelSize: 17
                    }
                    Rectangle {
                        id: done
                        anchors.right: parent.right
                        width: doneText.implicitWidth + 24
                        height: doneText.implicitHeight + 12
                        radius: Theme.radius
                        color: doneArea.pressed ? Theme.vermDeep : Theme.accent
                        Text {
                            id: doneText
                            anchors.centerIn: parent
                            text: "Done"
                            color: Theme.cardBot
                            font.family: Theme.font
                            font.pixelSize: 12
                        }
                        MouseArea {
                            id: doneArea
                            anchors.fill: parent
                            onClicked: win.open = false
                        }
                    }
                }

                Flickable {
                    x: card.pad
                    y: head.y + head.height + card.pad
                    width: card.width - 2 * card.pad
                    height: card.height - y - card.pad
                    contentWidth: width
                    contentHeight: page.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Customize {
                        id: page
                        width: parent.width
                        svc: win.svc
                    }
                }
            }
        }
    }
}
