import QtQuick
import Ryoku.PluginKit.Singletons

// The four FSRS ratings. Again is tinted with the accent because it is the one
// answer that changes the card's future materially; the rest stay quiet.
//
// Surfaces come from the wallpaper's own container roles rather than a white
// overlay, so the row picks up the palette's HUE and not just its brightness.
// Scheme.role() falls through to the given base when a role is absent, so a
// partial colors.json can never paint these black.
Row {
    id: row

    property real s: 1
    // { "1": "1m", "2": "6m", "3": "10m", "4": "16d" } - what each button will
    // actually do to THIS card, computed by the scheduler itself.
    property var preview: null
    property bool showIntervals: true
    signal graded(int rating)

    readonly property bool hasPreview: row.showIntervals && !!row.preview

    spacing: 6 * row.s

    Repeater {
        model: [
            { label: "Again", rating: 1, warn: true },
            { label: "Hard",  rating: 2, warn: false },
            { label: "Good",  rating: 3, warn: false },
            { label: "Easy",  rating: 4, warn: false }
        ]

        delegate: Rectangle {
            id: btn
            required property var modelData

            width: Math.max(label.implicitWidth, gap.implicitWidth) + 18 * row.s
            height: (row.hasPreview ? 34 : 26) * row.s
            radius: 7 * row.s

            readonly property bool warn: btn.modelData.warn === true
            readonly property color rest: Scheme.role("secondaryContainer", Theme.sheen)
            color: hover.containsPress ? Qt.darker(btn.rest, 1.18)
                 : hover.hovered       ? Qt.lighter(btn.rest, 1.14)
                                       : btn.rest
            border.width: 1
            border.color: btn.warn ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.55)
                                   : Scheme.line

            // the press dip the shell's own chrome uses
            scale: hover.containsPress ? 0.96 : 1.0
            Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
            Behavior on color { ColorAnimation { duration: 110 } }

            Column {
                anchors.centerIn: parent
                spacing: 1 * row.s

                Text {
                    id: label
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: btn.modelData.label
                    color: btn.warn ? Theme.accent
                                    : Scheme.role("onSecondaryContainer", Theme.bright)
                    font.family: Theme.font
                    font.pixelSize: 11 * row.s
                    font.weight: Font.Medium
                }

                Text {
                    id: gap
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: row.hasPreview
                    height: visible ? implicitHeight : 0
                    text: row.preview ? (row.preview[btn.modelData.rating] || "") : ""
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 9 * row.s
                }
            }

            HoverHandler { id: hover }
            TapHandler { onTapped: row.graded(btn.modelData.rating) }
        }
    }
}
