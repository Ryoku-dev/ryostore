pragma ComponentBehavior: Bound
import QtQuick
import "."

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
    implicitWidth: wdg.implicitWidth
    implicitHeight: wdg.implicitHeight
    readonly property real sc: (root.widthBudget > 0 && wdg.implicitWidth > 0)
        ? Math.min(1.25, Math.max(0.6, root.widthBudget / wdg.implicitWidth)) : 1
    transform: Scale { origin.x: 0; origin.y: 0; xScale: root.sc; yScale: root.sc }
    WeatherWidget { id: wdg }
}
