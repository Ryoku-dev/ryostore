pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Ryoku.PluginKit.Singletons

// content/FloatingWindow.qml -- the calculator when placed as "Frame popout"
// (see service/Main.qml). A layer-shell surface the plugin owns itself,
// created only while it is open, so -- unlike a frame popout docked to an
// edge -- nothing in the shell auto-dismisses it on hover-out. It closes on
// Esc, the keybind, or a click anywhere outside the calculator, the same way
// the shell's Ask bar and launcher do; the expression is kept in the service,
// so reopening picks it up again. Positioned from the placement's edge +
// align (the Hub's drag-and-drop placer); with no screen set, the compositor
// puts it on the focused output. It respects other layers' exclusive zones,
// so the bar stays visible and clickable.
//
//   edge left/right: align start = top, center = middle, end = bottom
//   edge top/bottom: align start = left, center = middle, end = right
//   edge center:     centred on screen
//
// One full-screen transparent surface holds both the calculator and the
// click-away area (as the Ask bar does): a second surface for the scrim
// leaves the keyboard with whichever one the compositor mapped last, and
// Hyprland and niri disagree about which. The surface never changes size --
// sizing it to the calculator made the compositor reconfigure it on every
// frame of the keypad/shortcut roll animation, which lagged.
PanelWindow {
    id: win

    required property var service

    readonly property string edge: win.service ? win.service.placeEdge : "center"
    readonly property string align: win.service ? win.service.placeAlign : "center"
    readonly property bool vertical: edge === "left" || edge === "right"
    readonly property int gap: 16

    // Where the calculator sits on screen.
    readonly property string hpos: edge === "left" ? "left"
        : edge === "right" ? "right"
        : (!vertical && edge !== "center" && align === "start") ? "left"
        : (!vertical && edge !== "center" && align === "end") ? "right" : "middle"
    readonly property string vpos: edge === "top" ? "top"
        : edge === "bottom" ? "bottom"
        : (vertical && align === "start") ? "top"
        : (vertical && align === "end") ? "bottom" : "middle"

    color: "transparent"
    WlrLayershell.namespace: "quickcalc"
    WlrLayershell.layer: WlrLayer.Top
    // Exclusive on purpose: a keybind-launched quick calculator must take
    // the keyboard the moment it opens. With OnDemand on a focus-follows-mouse
    // compositor it only gets the keyboard once the pointer is over it, and a
    // layer surface can't be reached with the compositor's focus keys. It
    // never traps the user: a click outside it closes it.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Click-away: any press outside the calculator closes it. Presses on the
    // calculator's own background land here too (nothing above takes them),
    // so those are ignored.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: (mouse) => {
            var inside = mouse.x >= view.x && mouse.x < view.x + view.width
                && mouse.y >= view.y && mouse.y < view.y + view.height;
            if (!inside) Qt.callLater(function () { if (win.service) win.service.closeWindow(); });
        }
    }

    CalculatorView {
        id: view
        anchors.fill: undefined // the view fills its host by default; here it sizes itself
        width: implicitWidth
        height: implicitHeight
        x: win.hpos === "left" ? win.gap
           : win.hpos === "right" ? win.width - width - win.gap
           : Math.round((win.width - width) / 2)
        y: win.vpos === "top" ? win.gap
           : win.vpos === "bottom" ? win.height - height - win.gap
           : Math.round((win.height - height) / 2)
        // The shell's frame rounding (Ryoku Settings > Shell), through the
        // public PluginKit Config -- the same on every compositor.
        cornerRadius: Math.max(0, Math.min(40, Number(Config.frameRadius) || 0))
        serviceOverride: win.service
        active: win.visible
        closeHandler: function () { if (win.service) win.service.closeWindow(); }
    }
}
