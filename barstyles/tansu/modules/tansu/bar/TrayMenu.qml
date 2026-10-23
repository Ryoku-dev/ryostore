import QtQuick
import QtQuick.Shapes
import "../../../modules/common"
import "../../../modules/common/widgets"

// The right-click menu from Figma: a white card (3px navy outline,
// hard shadow), a "Pin" row on top, then whatever entries the app
// itself publishes — for Discord that's Discord / Open Discord /
// Check for Updates… / Acknowledgements / Quit Discord.
//
// A view only: TrayPopups.qml owns the QsMenuOpener and passes its
// `children` in as `entries`, and acts on the signals. (The one
// Quickshell import is for QsMenuButtonType, to tell checkable
// entries from plain ones.)
Pill {
    id: root

    property var entries: null

    // Real screen pixels per design pixel here (shell scale x the screen's
    // device pixel ratio). The tray glyphs are Shapes drawn through a
    // layer (for anti-aliasing); a layer is made at the item's design
    // size unless it is told otherwise, and the scale then stretches that
    // small picture -- soft above 100%. The owner sets this; 1 = old look.
    property real texel: 1

    property bool pinned: false
    property bool showPin: true
    // The bar's corner-radius setting, so the menu matches the bar.
    property real roundness: 1
    property bool showBack: false

    // The same entry and dismiss as the bar's other popups (TansuPopup.qml): the
    // card grows out of the point it hangs from with a little overshoot (340 ms,
    // OutBack) and shrinks all the way back into it on the way out (170 ms,
    // InCubic), no fade to hide the end: the origin is the pill it belongs to,
    // outside the card, so the whole card goes into it.
    // TrayPopups calls hold() the moment a menu is asked for (the card
    // stays invisible) and pop() once the app's entries have arrived, so
    // the card is never seen on screen while it is still the wrong size
    // or in the wrong place. That includes right-clicking a different icon
    // while one menu is already showing. It calls away() to put the card
    // away, and takes the window down on awayDone().
    //
    // originX / originY is where the card grows from, in the card's own
    // pixels: its top middle by default; TrayPopups puts it on the pill.
    property real originX: width / 2
    property real originY: 0
    property real popProgress: 0
    property bool leaving: false
    signal awayDone()

    function hold() {
        popAnim.stop()
        awayAnim.stop()
        leaving = false
        popProgress = 0
    }
    function pop() {
        awayAnim.stop()
        leaving = false
        popAnim.restart()
    }
    function away() {
        popAnim.stop()
        leaving = true
        awayAnim.restart()
    }

    enabled: !root.leaving

    readonly property int entryCount: entriesRepeater.count

    SequentialAnimation {
        id: popAnim
        ScriptAction { script: root.popProgress = 0 }
        PauseAnimation { duration: 40 }
        NumberAnimation {
            target: root
            property: "popProgress"
            from: 0
            to: 1
            duration: 340
            easing.type: Easing.OutBack
            easing.overshoot: 1.3
        }
    }

    SequentialAnimation {
        id: awayAnim
        NumberAnimation {
            target: root
            property: "popProgress"
            to: 0
            duration: 170
            easing.type: Easing.InCubic
        }
        ScriptAction { script: root.awayDone() }
    }

    // Fades in a touch as it starts, never out: whole until it is in the pill.
    opacity: root.leaving ? 1 : Math.min(1, root.popProgress * 8)
    transform: Scale {
        origin.x: root.originX
        origin.y: root.originY
        xScale: Math.max(0, root.popProgress)
        yScale: Math.max(0, root.popProgress)
    }

    signal pinRequested()
    signal backRequested()
    signal entryTriggered(var entry)
    signal submenuRequested(var entry)

    cornerRadius: Theme.radiusOuter * root.roundness
    ringWidth: Theme.borderWidth
    innerRing: Theme.cardRing
    fillColor: Theme.surface

    readonly property real innerWidth: Math.max(168, col.implicitWidth)

    implicitWidth: innerWidth + 10 + ringWidth * 2
    implicitHeight: col.implicitHeight + 2 + ringWidth * 2 + Theme.shadowOffset

    // The widest a single row can ever get — icon + a full 240px label
    // (TrayMenuRow's own elide cap) + a submenu chevron — from
    // TrayMenuRow's layout constants (leftPad 24, iconSize 18, iconGap
    // 5, maxTextWidth 240, rightPad 16, chevronWidth 14). Keep this in
    // sync with TrayMenuRow.qml if those ever change.
    //
    // TrayPopups reserves the popup's width using this instead of
    // `implicitWidth`, because the real entries (`entries`) only
    // arrive after a right-click, over D-Bus — asynchronously, so
    // sizing off the *actual* menu means the popup is briefly too
    // narrow and then has to widen once they land. Widening after the
    // popup is already on screen means moving it sideways to stay
    // centered, and a Wayland compositor can apply that move and the
    // resize as two separate steps — the exact "wrong place for a
    // moment" glitch the `wantW` comment in TrayPopups.qml describes.
    // Reserving the worst case up front means no app's real menu ever
    // needs more room than what's already there, so opening one only
    // ever adds height below the capsule, never moves anything.
    readonly property real maxRowWidth: 24 + 18 + 5 + 240 + 16 + 14
    readonly property real maxWidth: Math.max(168, maxRowWidth) + 10 + ringWidth * 2

    Column {
        id: col
        x: 5
        y: 1
        width: root.innerWidth

        TrayMenuRow {
            texel: root.texel
            width: col.width
            visible: root.showPin
            text: root.pinned ? "Unpin" : "Pin"
            onClicked: root.pinRequested()

            Item {
                anchors.fill: parent
                rotation: root.pinned ? 180 : 0

                Behavior on rotation {
                    NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
                }

                Shape {
                    layer.enabled: true
                    layer.samples: 4
                    layer.textureSize: Qt.size(Math.max(1, Math.ceil(width * root.texel)),
                                                Math.max(1, Math.ceil(height * root.texel)))

                    ShapePath {
                        strokeColor: Theme.ink
                        strokeWidth: 2
                        fillColor: "transparent"
                        capStyle: ShapePath.FlatCap
                        joinStyle: ShapePath.MiterJoin
                        PathSvg { path: "M14 14L4 4M4 12V4H12" }
                    }
                }
            }
        }

        TrayMenuRow {
            texel: root.texel
            width: col.width
            visible: root.showBack
            text: "Back"
            onClicked: root.backRequested()

            Shape {
                layer.enabled: true
                layer.samples: 4
                layer.textureSize: Qt.size(Math.max(1, Math.ceil(width * root.texel)),
                                            Math.max(1, Math.ceil(height * root.texel)))

                ShapePath {
                    strokeColor: Theme.ink
                    strokeWidth: 2
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    PathSvg { path: "M15 9H4M9 4L4 9L9 14" }
                }
            }
        }

        Repeater {
            id: entriesRepeater
            model: root.entries

            delegate: TrayMenuRow {
                texel: root.texel
                id: entryRow

                required property var modelData

                width: col.width
                separator: entryRow.modelData?.isSeparator ?? false
                text: entryRow.modelData?.text ?? ""
                iconSource: entryRow.modelData?.icon ?? ""
                dim: !(entryRow.modelData?.enabled ?? true)
                hasChildren: entryRow.modelData?.hasChildren ?? false
                checked: entryRow.modelData?.checked ?? false

                onClicked: {
                    if (entryRow.hasChildren)
                        root.submenuRequested(entryRow.modelData)
                    else
                        root.entryTriggered(entryRow.modelData)
                }
            }
        }
    }
}
