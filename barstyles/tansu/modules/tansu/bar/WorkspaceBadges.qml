import QtQuick
import "../../../modules/common"
import "../../../modules/common/widgets"

// Workspace switcher, drawn natively (Pill.qml) instead of from
// exported PNG/SVG assets — no image files to manage, and it's true
// vector at every size since nothing's ever rasterized.
//
// Pure UI (no Quickshell imports): tell it which workspace is active
// and it emits requested(n) when the user clicks a badge or scrolls
// over the row.
//
// Figma spec this follows:
//   idle badge   36 x 36, the theme accent fill, 8px white ring
//   active badge 42 x 42, the same accent, grows from centre
//   gap 6, one accent for every badge
//
// Behavior: no hover magnification (no macOS-dock cursor tracking).
// Every badge keeps its original 36x36 box in the row at all times —
// nothing is ever resized or squashed, and the row itself never
// reflows. The active badge is made "42px" purely by scaling it up in
// place around its own centre. Every badge on its left shifts further
// left, and every badge on its right shifts further right, by exactly
// the extra radius that zoom adds — so the gap right next to the
// active badge keeps matching every other gap, and the whole row
// reads as splitting evenly around whichever badge is active (works
// the same whether that's an end badge or one in the middle). Both
// the zoom and the shift ease in with a soft bounce (Behavior below)
// rather than snapping or morphing — only scale/position animate,
// width and height never do, so the badge's real dimensions never
// change.
Item {
    id: root

    property int active: 1
    property int count: 5

    property var occupied: []

    readonly property var ids: {
        const out = []
        for (let i = 1; i <= root.count; i++)
            out.push(i)
            const extra = []
            for (const w of root.occupied)
                if (w > root.count && extra.indexOf(w) < 0)
                    extra.push(w)
                    if (root.active > root.count && extra.indexOf(root.active) < 0)
                        extra.push(root.active)
                        extra.sort((a, b) => a - b)
                        return out.concat(extra)
    }
    readonly property int total: root.ids.length

    readonly property bool capsule: Theme.capsuleFor(root)

    property bool vertical: false
    // The bar's corner-radius setting (the capsule style's dots follow it too).
    property real roundness: 1

    signal requested(int workspace)

    readonly property real gap: 6
    readonly property real idleSize: 36

    // Standing bar only: the most length (px) the column may take, worked out by
    // Status_Bar.qml from what the rest of the bar leaves free (-1 = no limit).
    // With 10 workspaces the column is taller than that on most screens, and a
    // bar that cannot fit its middle group drops the whole group, so instead the
    // column shows only the badges around the active workspace: as many as fit
    // (never fewer than 3), and the window follows the active workspace as you
    // switch or scroll.
    property real maxLength: -1
    readonly property real slotLen: root.capsule ? Theme.capDot + Theme.capGap : root.idleSize + Theme.shadowOffset + root.gap
    readonly property int shown: {
        if (!root.vertical || root.maxLength < 0)
            return root.total
            const extra = root.capsule ? Theme.capDotActive - Theme.capDot : 0
            const fit = Math.floor((root.maxLength - extra + root.gap) / root.slotLen)
            return Math.max(Math.min(3, root.total), Math.min(root.total, fit))
    }
    readonly property int first: Math.max(0, Math.min(root.total - root.shown,
                                                      root.active - 1 - Math.floor(root.shown / 2)))

    readonly property real numberNudge: 2
    readonly property real activeSize: 42

    readonly property real activeZoom: activeSize / idleSize

    readonly property real neighborShift: root.capsule ? 0 : (activeSize - idleSize) / 2

    // Every badge wears the theme's accent (Ryoku.Theme.primary, through
    // Theme.accentCyan), idle or active, so nothing on the bar ever takes a
    // colour from outside the palette. The active one is set apart by size
    // alone: it scales up to activeSize and the row parts around it.
    readonly property color badgeColor: Theme.accentCyan

    height: root.capsule ? (root.vertical ? dotRow.height + Theme.shadowOffset : Theme.capDot)
    : (root.vertical ? row.height : activeSize + Theme.shadowOffset)
    width: root.capsule ? (root.vertical ? Theme.capDot : dotRow.width) : (root.vertical ? activeSize : row.width)
    implicitHeight: height
    implicitWidth: width

    Item {
        id: row
        width: root.vertical ? root.idleSize : root.total * root.idleSize + (root.total - 1) * root.gap
        height: root.vertical
        ? root.shown * (root.idleSize + Theme.shadowOffset) + (root.shown - 1) * root.gap
        : root.idleSize + Theme.shadowOffset
        x: root.vertical ? (root.width - width) / 2 : 0
        y: root.vertical ? 0 : root.height - height - 6

        Repeater {
            id: repeater
            model: root.capsule ? 0 : root.total

            // Fixed-size wrapper: this is always exactly idleSize, so
            // the Row's layout never reflows when the active
            // workspace changes. Any visual growth happens on the
            // Pill inside it via a transform, not a size change.
            delegate: Item {
                id: wrap

                required property int index
                readonly property int number: root.ids[index]
                readonly property bool isActive: root.active === number
                readonly property real shift: number < root.active ? -root.neighborShift
                : number > root.active ? root.neighborShift
                : 0
                readonly property real xOffset: root.vertical ? 0 : shift
                readonly property real yOffset: root.vertical ? shift : 0

                // root.active is a live reflection of the real,
                // external compositor state (see Bar.qml) — it
                // updates the same way whether a switch came from
                // clicking this badge, scrolling, or a Hyprland
                // keybind that never touched this bar at all. So a
                // keyboard-shortcut switch has no local press to
                // react to; instead, whichever badge NEWLY becomes
                // active pulses itself: a quick programmatic
                // press-then-pop, same animation a click gives.
                property bool keyPulse: false

                // Swallows that auto-pulse for a moment right after
                // THIS badge was the one physically clicked — the
                // real MouseArea press/release below already gave it
                // tactile feedback, so there's no need to pulse it a
                // second time once Hyprland confirms the switch a
                // beat later.
                property bool suppressPulse: false

                onIsActiveChanged: {
                    if (isActive && !suppressPulse) {
                        keyPulse = true
                        pulseRelease.restart()
                    }
                }

                Timer {
                    id: pulseRelease
                    interval: 90
                    onTriggered: wrap.keyPulse = false
                }

                Timer {
                    id: suppressGrace
                    interval: 400 // covers the round-trip to Hyprland and back
                    onTriggered: wrap.suppressPulse = false
                }

                // Place in the drawn window (the whole row unless the column is
                // cut short, see maxLength); badges outside it are not drawn.
                readonly property int slot: index - root.first
                visible: !root.vertical || (slot >= 0 && slot < root.shown)

                width: root.idleSize
                height: root.idleSize + Theme.shadowOffset
                x: root.vertical ? 0 : index * (root.idleSize + root.gap)
                y: root.vertical ? slot * (root.idleSize + Theme.shadowOffset + root.gap) : 0

                Pill {
                    id: badge
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: wrap.xOffset
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: wrap.yOffset

                    cornerRadius: Theme.radiusBadge
                    ringWidth: 8
                    fillColor: root.badgeColor

                    // Always the original 36px box — the "grows to
                    // 42px when selected" look comes entirely from
                    // the scale below, never from resizing this.
                    width: root.idleSize
                    height: root.idleSize + Theme.shadowOffset

                    scale: wrap.isActive ? root.activeZoom : 1.0

                    pressed: badgeArea.pressed || wrap.keyPulse

                    // Soft bounce on the way in and out — tuned down
                    // from a full dock-style overshoot so it reads as
                    // smooth rather than springy. Only scale/position
                    // ease; width and height are never animated, so
                    // the badge's real size never morphs.
                    Behavior on scale {
                        NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                    }
                    Behavior on anchors.horizontalCenterOffset {
                        NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                    }
                    Behavior on anchors.verticalCenterOffset {
                        NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                    }

                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -Theme.shadowOffset / 2 + root.numberNudge
                        color: Theme.colBorder
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        font.weight: Font.ExtraBold
                        font.styleName: Theme.fontStyleBold
                        text: wrap.number
                    }
                }

                MouseArea {
                    id: badgeArea
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: wrap.xOffset
                    anchors.verticalCenterOffset: wrap.yOffset
                    width: root.activeSize
                    height: root.activeSize + Theme.shadowOffset
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.requested(wrap.number)
                    onPressed: wrap.suppressPulse = true
                    onReleased: suppressGrace.restart()
                    onCanceled: suppressGrace.restart()
                }
            }
        }
    }

    Grid {
        id: dotRow
        visible: root.capsule
        columns: root.vertical ? 1 : Math.max(1, root.total)
        anchors.verticalCenter: root.vertical ? undefined : parent.verticalCenter
        anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
        spacing: Theme.capGap

        Repeater {
            model: root.capsule ? root.total : 0

            delegate: Item {
                id: dot

                required property int index
                readonly property int number: root.ids[index]
                readonly property bool isActive: root.active === number

                readonly property int slot: index - root.first
                visible: !root.vertical || (slot >= 0 && slot < root.shown)

                width: dot.isActive && !root.vertical ? Theme.capDotActive : Theme.capDot
                height: dot.isActive && root.vertical ? Theme.capDotActive : Theme.capDot

                Behavior on width {
                    NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                }
                Behavior on height {
                    NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                }

                scale: dotArea.pressed ? 0.88 : 1.0
                Behavior on scale {
                    NumberAnimation { duration: dotArea.pressed ? 70 : 200; easing.type: Easing.OutBack; easing.overshoot: 2 }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2 * root.roundness
                    color: Theme.capRim
                    antialiasing: true
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: Theme.capDotRing
                    radius: height / 2 * root.roundness
                    color: Theme.capWsColors[(dot.number - 1) % Theme.capWsColors.length]
                    antialiasing: true
                }

                // Half the gap each side, so neighbours never overlap and the
                // 18 px dot is an easy target.
                MouseArea {
                    id: dotArea
                    anchors.fill: parent
                    anchors.margins: -Theme.capGap / 2
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.requested(dot.number)
                }
            }
        }
    }

    // Spans the whole row purely to catch scroll-to-switch; it no
    // longer tracks cursor position, so there's nothing left for
    // hoverEnabled to do. acceptedButtons: NoButton means it never
    // intercepts a press, so clicks fall straight through to each
    // badge's own MouseArea.
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        acceptedButtons: Qt.NoButton

        property bool ready: true
        Timer {
            id: cooldown
            interval: 140
            onTriggered: hoverArea.ready = true
        }

        onWheel: wheel => {
            if (!ready)
                return
                const dir = wheel.angleDelta.y < 0 ? 1 : -1
                const i = root.ids.indexOf(root.active)
                let next = -1
                if (i >= 0 && i + dir >= 0 && i + dir < root.total) {
                    next = root.ids[i + dir]
                } else if (dir > 0 && (root.active <= root.count || root.occupied.indexOf(root.active) >= 0)) {
                    next = root.active + 1
                }
                if (next >= 1) {
                    root.requested(next)
                    ready = false
                    cooldown.restart()
                }
        }
    }
}
