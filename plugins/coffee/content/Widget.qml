pragma ComponentBehavior: Bound

import QtQuick

// content/Widget.qml is the one view the host mounts in every host. It only
// dispatches on density: the bar glyph at "glyph", the desktop tile at
// "compact". All state comes from the service (pluginApi.mainInstance); a left
// click on the bar toggles the panel and never mutates anything.
Item {
    id: root

    // Host-set; read only, never assign.
    property var pluginApi
    property var screen
    property bool active: false
    property string density: "glyph"
    property real s: 1
    property real widthBudget: 0

    readonly property bool isGlyph: density === "glyph"
    readonly property var view: isGlyph ? glyphLoader.item : cardLoader.item

    implicitWidth: view ? view.implicitWidth : 18 * s
    implicitHeight: view ? view.implicitHeight : 18 * s

    Loader {
        id: glyphLoader
        active: root.isGlyph
        sourceComponent: Glyph {
            pluginApi: root.pluginApi
            active: root.active
            s: root.s
            widthBudget: root.widthBudget
        }
    }

    Loader {
        id: cardLoader
        active: !root.isGlyph
        sourceComponent: Card {
            pluginApi: root.pluginApi
            active: root.active
            density: root.density
            s: root.s
            widthBudget: root.widthBudget
        }
    }
}
