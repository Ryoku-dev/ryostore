import QtQuick
import "../../../modules/common"

// Shared building block: a thick navy outline with a white "ring"
// gap between the outline and the actual colored fill, sitting on a
// flat offset "hard" shadow. Confirmed straight from the current
// Figma file — every pill in the bar uses this exact three-layer
// structure (outline -> white ring -> color), just with different
// ring widths (8px is the default everywhere except Media, which
// uses 5px). Set fillColor for a flat fill or fillGradient for the
// cyan/mint gradient pills; the ring itself is plain white unless a
// caller sets ringColorTop/ringColorBottom (the dock's hover/running
// glow — see Dock.qml). Anything declared inside a Pill lands on top
// of the fill.
//
// Inside a bar drawn in the Capsule style (see `capsule` below) all of that is
// dropped: the pill is one flat, fully rounded chip with no outline, ring or shadow.
// On a flat bar it is Theme.capChipHeight tall and centred in whatever box the caller
// gave it; on a standing bar (`capsuleV`) it is the whole box (less the shadow's room at
// the bottom), so the two-line texts have room.
//
// A popup card that hangs off a Capsule bar is not inside the bar, so it cannot
// find `capsuleBar` up the tree. Its owner (TansuPopup, TrayPopups) sets
// `capRim` instead: the card keeps its own shape but takes the bar's colours --
// outline = the bar's rim, hard shadow = the bar's shadow, ring and fill = the
// bar's body.
Item {
    id: root

    readonly property bool capsule: Theme.capsuleFor(root)
    readonly property bool capsuleV: root.capsule && Theme.capsuleVerticalFor(root)
    readonly property real barVWidth: root.capsule ? Theme.capVChip : Theme.barVPillWidth
    property bool capKeepsFill: false
    property bool capRim: false
    property bool bare: false
    property bool flat: false

    readonly property bool classicScope: Theme.classicFor(root)

    property color fillColor: classicScope ? Theme.pSurface : Theme.surface
    property Gradient fillGradient: null
    property real cornerRadius: height / 2
    property real ringWidth: 8

    // The bar's corner-radius setting (Status_Bar sets it), found up the tree
    // so every module follows the bar. 1 for anything outside the bar.
    readonly property real barRoundness: {
        for (let p = root.parent; p; p = p.parent)
            if (p.barRoundness !== undefined)
                return p.barRoundness
        return 1
    }
    readonly property real effectiveRadius: Math.max(0, root.cornerRadius * root.barRoundness)

    property real innerRing: 0

    // Outline thickness, and where the hard shadow sits. The bar's pills
    // only ever drop it straight down (shadowDy 4, shadowDx 0); the Quick
    // Panel's buttons cast it down-right and change all three between
    // their OFF and ON looks, which is why they're properties here.
    property real borderWidth: Theme.borderWidth
    property real shadowDx: 0
    property real shadowDy: Theme.shadowOffset

    property color ringColorTop: classicScope ? Theme.pRingWhite : Theme.ringWhite
    property color ringColorBottom: classicScope ? Theme.pRingWhite : Theme.ringWhite

    readonly property real capWidth: width - shadowDx
    readonly property real capHeight: height - shadowDy
    default property alias content: fill.data

    // Physical-button press state. Pill itself never listens for
    // clicks (callers each have their own MouseArea, with their own
    // hit-test shape) — bind this to that MouseArea's own "pressed"
    // so the cap below reacts to the real press/release, not just a
    // completed click.
    property bool pressed: false

    implicitHeight: Theme.pillHeight + shadowDy

    // Fixed hard shadow — never moves. It's what the cap below either
    // reveals (raised) or fully covers (pressed).
    Rectangle {
        visible: !root.capsule && !root.bare && !root.flat
        x: root.shadowDx
        y: root.shadowDy
        width: root.capWidth
        height: root.capHeight
        radius: root.effectiveRadius
        color: root.capRim ? Theme.capShade
            : (root.classicScope ? Theme.pLineShadow : Theme.lineShadow)
        antialiasing: true
    }

    Item {
        id: surface
        x: root.capsule ? 0 : (root.pressed && !root.flat ? root.shadowDx : 0)
        y: root.capsule ? (root.capsuleV ? 0 : (root.height - surface.height) / 2) + (root.pressed ? 1 : 0)
                        : (root.pressed ? (root.flat ? 1 : root.shadowDy) : 0)
        width: root.capsule ? root.width : root.capWidth
        height: root.capsule ? (root.capsuleV ? Math.max(0, root.height - root.shadowDy)
                                              : Math.min(root.height, Theme.capChipHeight))
                             : root.capHeight

        Behavior on x {
            NumberAnimation {
                duration: root.pressed ? 80 : 260
                easing.type: root.pressed ? Easing.OutQuad : Easing.OutBack
                easing.overshoot: root.pressed ? 0 : 2.2
            }
        }

        Behavior on y {
            NumberAnimation {
                duration: root.pressed ? 80 : 260
                easing.type: root.pressed ? Easing.OutQuad : Easing.OutBack
                easing.overshoot: root.pressed ? 0 : 2.2
            }
        }

        Rectangle {
            id: face
            visible: !root.capsule && !root.bare
            anchors.fill: parent
            radius: root.effectiveRadius
            border.width: root.borderWidth
            border.color: root.capRim ? Theme.capRim
                : (root.classicScope ? Theme.pLine : Theme.line)
            antialiasing: true

            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: root.capRim ? Theme.capBody : root.ringColorTop
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                GradientStop {
                    position: 1.0
                    color: root.capRim ? Theme.capBody : root.ringColorBottom
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }
        }

        Rectangle {
            id: fill
            anchors.fill: face
            anchors.margins: root.capsule ? 0 : root.ringWidth
            radius: root.capsule ? Math.min(width, height) / 2 * root.barRoundness
                : Math.max(0, root.effectiveRadius - root.ringWidth)
            color: root.bare ? "transparent"
                : (root.capsule
                    ? (root.capKeepsFill ? root.fillColor : Theme.capChip)
                    : (root.capRim ? Theme.capBody
                        : (root.fillGradient ? "transparent" : root.fillColor)))
            gradient: (root.capsule || root.capRim || root.bare) ? null : root.fillGradient

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }
            antialiasing: true
        }

        Rectangle {
            anchors.fill: fill
            radius: fill.radius
            color: "transparent"
            border.width: root.innerRing
            border.color: root.capRim ? Theme.capBody : root.ringColorTop
            visible: root.innerRing > 0 && !root.capsule && !root.bare
            antialiasing: true
        }
    }
}
