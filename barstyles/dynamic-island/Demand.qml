import QtQuick

// Checks in with Hub while `active`, so background work (the media position
// tick, the visualizer) only runs while something on screen draws it.
QtObject {
    id: root
    property string kind: ""
    property bool active: false
    property bool _held: false
    function _sync() {
        if (active === _held) return;
        _held = active;
        Hub.want(kind, active);
    }
    onActiveChanged: _sync()
    Component.onCompleted: _sync()
    Component.onDestruction: if (_held) Hub.want(kind, false)
}
