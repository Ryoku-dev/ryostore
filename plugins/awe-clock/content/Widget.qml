pragma ComponentBehavior: Bound
import QtQuick
import "."

// Thin host adapter: draws the ported Awe widget at its native size and scales
// the whole tile to the width the host budgets it.
Item {
    id: root

    property var pluginApi
    property var screen
    property bool active
    property string density: "compact"
    property real s: 1
    property real widthBudget: 0

    // Accent handoff: the host sets accentColor and flips accentFromHost; only push the override
    // while the flag is on, otherwise clear it so the theme keeps its own palette.
    property color accentColor: "transparent"
    property bool accentFromHost: false
    onAccentColorChanged: Theme.accentOverride = root.accentFromHost ? root.accentColor : "transparent"
    onAccentFromHostChanged: Theme.accentOverride = root.accentFromHost ? root.accentColor : "transparent"

    readonly property real fitScale: (root.widthBudget > 0 && wdg.implicitWidth > 0)
        ? Math.min(1.25, Math.max(0.6, root.widthBudget / wdg.implicitWidth)) : 1

    implicitWidth: wdg.implicitWidth * root.fitScale
    implicitHeight: wdg.implicitHeight * root.fitScale

    transform: Scale { origin.x: 0; origin.y: 0; xScale: root.fitScale; yScale: root.fitScale }

    Clock {
        id: wdg
    }
}
