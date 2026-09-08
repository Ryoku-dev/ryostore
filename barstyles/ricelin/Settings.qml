pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * 設 SETTINGS index: a short list of categories. Each row carries its kanji,
 * name and caption, and morphs the pill into that category's sub-surface.
 * Arrow keys move the focused row with the glowing seam and Return opens it.
 */
SettingsSurface {
    id: root

    implicitHeight: content.implicitHeight

    rows: [
        { item: appearanceRow, kind: "nav", surface: "appearance" },
        { item: lookRow, kind: "nav", surface: "look" },
    ]

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SettingsHeader {
            s: root.s
            glyph: "設"
            title: "SETTINGS"
        }

        SettingsRow {
            id: appearanceRow
            surface: root
            captionOnFocus: true
            icon: "sparkles"
            name: "Appearance"
            sub: "Clock, glyphs & visualizer"

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === appearanceRow ? Theme.cream : Theme.iconDim
                stroke: 2.2
            }
        }

        SettingsRow {
            id: lookRow
            surface: root
            captionOnFocus: true
            icon: "app-window"
            name: "Look"
            sub: "Pill look"

            GlyphIcon {
                width: 16 * root.s
                height: 16 * root.s
                name: "chevron-right"
                color: root.focusRowItem === lookRow ? Theme.cream : Theme.iconDim
                stroke: 2.2
            }
        }
    }
}
