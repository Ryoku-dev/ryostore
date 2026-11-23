import QtQuick

// A hotplug-safe copy of a ShellScreen's geometry for per-screen windows.
//
// Binding sizes straight to `modelData.width/height` re-evaluates them while the
// output is being torn down: the ShellScreen is destroyed (or reports a 0x0
// geometry after `screenDestroyed`) and every dependent binding writes the new
// value into items whose QQuickWindow is already going away. Qt then crashes in
// QQuickWindowPrivate::dirtyItem / QQuickItemPrivate::dirty (from setHeight, or
// from ~QQuickItem → setParentItem). This happens whenever a monitor is
// unplugged, disabled, or drops hotplug while in DPMS standby.
//
// ScreenGeom keeps the last valid geometry: it follows `geometryChanged` while
// the screen is alive and simply stops updating when it goes null or 0x0, so the
// window is destroyed with the geometry it had, never resized on the way out.
Item {
    id: g
    visible: false
    width: 0
    height: 0

    property var screen: null

    property real sx: 0
    property real sy: 0
    property real sw: 0
    property real sh: 0
    property string sname: ""
    readonly property bool valid: sw > 0 && sh > 0

    function sync() {
        const s = g.screen;
        if (!s || !(s.width > 0) || !(s.height > 0))
            return;
        if (g.sx !== s.x) g.sx = s.x;
        if (g.sy !== s.y) g.sy = s.y;
        if (g.sw !== s.width) g.sw = s.width;
        if (g.sh !== s.height) g.sh = s.height;
        if (s.name && g.sname !== s.name) g.sname = s.name;
    }

    // name is constant and readable at once, so a newly bound screen never keeps the previous
    // screen's name while its geometry is still 0x0; geometry follows on the next valid sync()
    onScreenChanged: {
        if (g.screen && g.screen.name && g.sname !== g.screen.name)
            g.sname = g.screen.name;
        sync();
    }
    Component.onCompleted: sync()

    Connections {
        target: g.screen
        ignoreUnknownSignals: true
        function onGeometryChanged() { g.sync(); }
    }
}
