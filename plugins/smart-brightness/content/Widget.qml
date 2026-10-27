pragma ComponentBehavior: Bound

import QtQuick

// One adaptive view: bar glyph at "glyph", desktop tile at "compact". The
// service (pluginApi.mainInstance) does the watching either way — enabling the
// plugin is what keeps Smart Brightness alive, not which host shows the UI.
Item {
    id: root

    property var pluginApi
    property var screen
    property bool active: false
    property string density: "glyph"
    property real s: 1
    property real widthBudget: 0
    property bool open: false
    property real reveal: 0
    property bool tabActive: false
    signal requestClose()

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
