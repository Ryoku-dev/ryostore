pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Ryoku.PluginKit.Singletons

// content/FloatingWindow.qml -- the calculator when placed as "Frame popout"
// (see service/Main.qml). A layer-shell surface the plugin owns itself,
// created only while it is open, so -- unlike a frame popout docked to an
// edge -- nothing in the shell auto-dismisses it: it stays until Esc or the
// keybind. Positioned from the placement's edge + align (the Hub's
// drag-and-drop placer); with no screen set, the compositor puts it on the
// focused output. It respects other layers' exclusive zones (the bar).
//
//   edge left/right: align start = top, center = middle, end = bottom
//   edge top/bottom: align start = left, center = middle, end = right
//   edge center:     centred on screen
//
// The surface never changes size. It is a full-height transparent column,
// as wide as the calculator, and the calculator moves and grows inside it.
// An input mask limits clicks to the calculator, so the rest of the column
// passes them through to the windows underneath. Sizing the surface to the
// calculator instead made the compositor reconfigure it on every frame of
// the keypad/shortcut roll animation, which lagged.
PanelWindow {
    id: win

    required property var service

    readonly property string edge: win.service ? win.service.placeEdge : "center"
    readonly property string align: win.service ? win.service.placeAlign : "center"
    readonly property bool vertical: edge === "left" || edge === "right"
    readonly property int gap: 16

    // Where the calculator sits inside the column.
    readonly property string vpos: edge === "top" ? "top"
        : edge === "bottom" ? "bottom"
        : (vertical && align === "start") ? "top"
        : (vertical && align === "end") ? "bottom" : "middle"

    color: "transparent"
    WlrLayershell.namespace: "quickcalc"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0

    anchors {
        top: true
        bottom: true
        left: win.edge === "left" || ((win.edge === "top" || win.edge === "bottom") && win.align === "start")
        right: win.edge === "right" || ((win.edge === "top" || win.edge === "bottom") && win.align === "end")
    }
    margins {
        top: win.gap
        bottom: win.gap
        left: win.gap
        right: win.gap
    }

    implicitWidth: view.implicitWidth

    mask: Region { item: view }

    CalculatorView {
        id: view
        anchors.fill: undefined // the view fills its host by default; here it sizes itself
        width: win.width
        height: implicitHeight
        y: win.vpos === "top" ? 0
           : win.vpos === "bottom" ? win.height - height
           : Math.round((win.height - height) / 2)
        // The shell's frame rounding (Ryoku Settings > Shell), through the
        // public PluginKit Config -- the same on every compositor.
        cornerRadius: Math.max(0, Math.min(40, Number(Config.frameRadius) || 0))
        serviceOverride: win.service
        active: win.visible
        closeHandler: function () { if (win.service) win.service.closeWindow(); }
    }
}
