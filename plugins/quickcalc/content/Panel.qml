pragma ComponentBehavior: Bound
import QtQuick

// content/Panel.qml -- the bar panel a topbarGlyph placement opens under its
// glyph (manifest "panel": {"width": 360}). The host sizes and positions the
// card; this just reports implicitHeight and hosts the same calculator view
// the framePopout placement uses, so the two placements are visually and
// functionally identical -- only how you open them differs.
Item {
    id: root

    property var pluginApi
    property string density: "full"
    property real s: 1
    property real widthBudget: 320
    property bool active: true

    implicitWidth: calc.implicitWidth
    implicitHeight: calc.implicitHeight

    CalculatorView {
        id: calc
        pluginApi: root.pluginApi
        active: root.active
    }
}
