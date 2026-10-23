import Quickshell
import Quickshell.Hyprland
import QtQuick
import "../../../services"
import "../../../modules/common"
import "../../../modules/common/widgets"

// The frame the bar's playful popups (Calendar, Battery, Weather, Media, Discord) share, so each
// of those files is only its own card. It is what BatteryPopup / WeatherPopup
// used to repeat: a HyprlandFocusGrab that dismisses on a click anywhere else
// (the bar's own window excepted), a PopupWindow that the bar places under its
// button (Bar.qml popupX / popupY / popupGravity, so it follows the bar to any
// edge), and the card drawn inside a ScaleHost so it matches the monitor's scale.
//
// What it adds:
//   - the card pops in (a little overshoot) out of the edge the bar is on, and
//     shrinks all the way back into it on the way out, the same language as the
//     desktop clock. The window stays up until the swallow is
//     done. Press the next popup's button before it is: the old card is put
//     away at once (services/PopupHandoff.qml), so two never show together.
//   - the window is only unmapped a few frames AFTER the card has shrunk to
//     nothing (`settling`), so the last picture the compositor gets is an empty
//     one. Unmapped the moment `reveal` hit 0, the last picture it had was the
//     frame before, with a small copy of the card still in it, and Hyprland
//     faded that frozen copy out: a small card that stays and fades. The taller
//     the card, the more of it is left in that frame (the media panel's turntable
//     is the tallest).
//   - a `bare` card (the equalizer console) goes in and out the same
//     way as every other card: it grows out of its pill and shrinks all the way
//     back into it. (It used to shrink to the nearest point on the window's
//     edge instead; that is gone so Media and Discord match Weather, Battery
//     and Calendar.)
//   - `reveal` (0..1, overshooting a little) is public, so a card can stage its
//     own entrance: cascades, springs, anything keyed to it.
//   - Escape closes; every other key is handed on through `keyed(event)`.
//
// Use it like this: everything declared inside lands on the card's face, whose
// size is `contentWidth` x `contentHeight` (design pixels).
//
//   TansuPopup {
//       id: root
//       contentWidth: 328
//       contentHeight: stack.implicitHeight + 32
//       Column { id: stack; x: 16; y: 16; ... }
//   }
//
// The window is `bleed` bigger than the card on every side except the one
// facing the bar, so a sticker that sits a few pixels over the card's edge, or
// the pop's overshoot, is not cut off. (Nothing may poke out on the bar's side:
// the window starts there.)
Scope {
    id: host

    property var parentWindow: null
    property Item anchorItem: null
    property bool open: false

    property bool centered: false

    readonly property real uiScale: host.parentWindow && host.parentWindow.uiScale ? host.parentWindow.uiScale : 1

    readonly property bool capsuleStyle: !!host.parentWindow && host.parentWindow.barStyle === 3
    // The bar's corner-radius setting, so the card matches the bar it hangs off.
    readonly property real roundness: host.parentWindow && host.parentWindow.barRoundness !== undefined
        ? host.parentWindow.barRoundness : 1

    property real contentWidth: 320
    property real contentHeight: 200

    readonly property real bleed: 14

    readonly property string barEdge: host.parentWindow && host.parentWindow.barPosition
        ? host.parentWindow.barPosition : "top"
    readonly property real padT: !host.centered && host.barEdge === "top" ? 6 : host.bleed
    readonly property real padB: !host.centered && host.barEdge === "bottom" ? 6 : host.bleed
    readonly property real padL: !host.centered && host.barEdge === "left" ? 0 : host.bleed
    readonly property real padR: !host.centered && host.barEdge === "right" ? 0 : host.bleed

    property real reveal: 0

    property bool settling: false

    function settle() {
        host.settling = true
        settleTimer.restart()
    }

    Timer {
        id: settleTimer
        interval: 80
        onTriggered: host.settling = false
    }

    readonly property int gravity: host.parentWindow ? host.parentWindow.popupGravity : (Edges.Bottom | Edges.Right)
    readonly property real windowLeft: popup.anchor.rect.x - ((host.gravity & Edges.Left) ? popup.implicitWidth : 0)
    readonly property real windowTop: popup.anchor.rect.y - ((host.gravity & Edges.Top) ? popup.implicitHeight : 0)

    readonly property real originX: host.centered ? card.width / 2 : host.anchorItem
        ? (host.anchorCenterX - host.windowLeft) / host.uiScale - host.padL
        : host.contentWidth / 2
    readonly property real originY: host.centered ? card.height / 2 : host.anchorItem
        ? (host.anchorCenterY - host.windowTop) / host.uiScale - host.padT
        : (host.barEdge === "bottom" ? host.contentHeight : 0)

    signal closeRequested()
    signal keyed(var event)

    default property alias content: body.data

    property bool bare: false
    property alias bareContent: bareBody.data

    readonly property real anchorCenterX: {
        void host.open
        return anchorItem ? anchorItem.mapToItem(null, anchorItem.width / 2, 0).x : 0
    }

    readonly property real anchorCenterY: {
        void host.open
        return anchorItem ? anchorItem.mapToItem(null, 0, anchorItem.height / 2).y : 0
    }

    readonly property bool grabWanted: open
    onGrabWantedChanged: {
        if (grabWanted)
            grabDelay.restart()
        else {
            grabDelay.stop()
            grab.active = false
        }
    }

    Timer {
        id: grabDelay
        interval: 80
        onTriggered: grab.active = host.grabWanted
    }

    HyprlandFocusGrab {
        id: grab
        windows: [popup, host.parentWindow]
        onCleared: host.closeRequested()
    }

    Connections {
        target: host

        function onOpenChanged() {
            if (host.open) {
                PopupHandoff.opening()
                swallow.stop()
                settleTimer.stop()
                host.settling = false
                popIn.restart()
            } else {
                popIn.stop()
                swallow.restart()
            }
        }
    }

    Connections {
        target: PopupHandoff

        function onSerialChanged() {
            if (!host.open && host.reveal > 0) {
                swallow.stop()
                popIn.stop()
                host.reveal = 0
                host.settle()
            }
        }
    }

    NumberAnimation {
        id: popIn
        target: host
        property: "reveal"
        to: 1
        duration: 340
        easing.type: Easing.OutBack
        easing.overshoot: 1.3
    }

    NumberAnimation {
        id: swallow
        target: host
        property: "reveal"
        to: 0
        duration: 170
        easing.type: Easing.InCubic
        onFinished: host.settle()
    }

    PopupWindow {
        id: popup
        visible: (host.open || host.reveal > 0.001 || host.settling) && host.parentWindow !== null

        anchor.window: host.parentWindow
        anchor.rect.x: host.centered && host.parentWindow && host.parentWindow.screen
            ? Math.round((host.parentWindow.screen.width - implicitWidth) / 2) + ((host.gravity & Edges.Left) ? implicitWidth : 0)
            : (host.parentWindow ? host.parentWindow.popupX(host.anchorCenterX, host.anchorCenterY, implicitWidth, implicitHeight) : 0)
        anchor.rect.y: host.centered && host.parentWindow && host.parentWindow.screen
            ? Math.round((host.parentWindow.screen.height - implicitHeight) / 2) + ((host.gravity & Edges.Top) ? implicitHeight : 0)
            : (host.parentWindow ? host.parentWindow.popupY(host.anchorCenterX, host.anchorCenterY, implicitWidth, implicitHeight) : 0)
        anchor.gravity: host.parentWindow ? host.parentWindow.popupGravity : (Edges.Bottom | Edges.Right)

        implicitWidth: Math.ceil((card.width + host.padL + host.padR) * host.uiScale)
        implicitHeight: Math.ceil((card.height + host.padT + host.padB) * host.uiScale)
        color: "transparent"

        // Keyboard. Best effort: it works whenever the compositor hands this
        // popup keyboard focus; the mouse never depends on it.
        Item {
            anchors.fill: parent
            focus: true
        }

        ScaleHost {
            anchors.fill: parent
            factor: host.uiScale
            enabled: host.open

            Item {
                id: stage

                // Grows out of its button from nothing, and shrinks all the way
                // back into it. It fades in a touch as it starts, but never out: it
                // is whole until it has gone into the pill.
                x: host.padL
                y: host.padT
                width: card.width
                height: card.height
                opacity: host.open ? Math.min(1, host.reveal * 8) : 1
                transform: Scale {
                    origin.x: host.originX
                    origin.y: host.originY
                    xScale: Math.max(0, host.reveal)
                    yScale: Math.max(0, host.reveal)
                }

                Pill {
                    id: card
                    visible: !host.bare
                    capRim: host.capsuleStyle
                    cornerRadius: Theme.radiusOuter * host.roundness
                    ringWidth: Theme.borderWidth
                    innerRing: Theme.cardRing
                    fillColor: Theme.surface
                    implicitWidth: host.contentWidth + 2 * Theme.borderWidth
                    implicitHeight: host.contentHeight + 2 * Theme.borderWidth + Theme.shadowOffset

                    Item {
                        id: body
                        anchors.fill: parent
                    }
                }

                Item {
                    id: bareBody
                    width: card.width
                    height: card.height
                    visible: host.bare
                }
            }
        }
    }
}
