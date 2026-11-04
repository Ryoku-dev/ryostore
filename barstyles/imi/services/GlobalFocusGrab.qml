pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Ryoku.Ui.Singletons as RyokuUi

// Shared click-outside focus grab. Uses the host's focus-grab bridge when the
// compositor offers one (Wm.caps.focusGrab); otherwise stays inert and callers
// keep their toggle-off fallbacks.
// "Persistent" is for windows that should always be included but not closed on
// dismiss, like the bar. "Dismissable" is for stuff like sidebars.
Singleton {
    id: root

    signal dismissed

    property list<var> persistent: []
    property list<var> dismissable: []
    readonly property bool available: RyokuUi.Wm.caps.focusGrab === true

    function dismiss() {
        root.dismissable = [];
        root.dismissed();
    }

    function addPersistent(window) {
        if (root.persistent.indexOf(window) === -1) {
            root.persistent = [...root.persistent, window];
        }
    }

    function removePersistent(window) {
        var index = root.persistent.indexOf(window);
        if (index !== -1) {
            root.persistent = root.persistent.filter((w, i) => i !== index);
        }
    }

    function addDismissable(window) {
        if (root.dismissable.indexOf(window) === -1) {
            root.dismissable = [...root.dismissable, window];
        }
    }

    function removeDismissable(window) {
        var index = root.dismissable.indexOf(window);
        if (index !== -1) {
            root.dismissable = root.dismissable.filter((w, i) => i !== index);
        }
    }

    function hasActive(element) {
        return element?.activeFocus || Array.from(element?.children).some(child => hasActive(child));
    }

    property QtObject _bridge: null
    property var _component: null

    function _syncBridge() {
        if (!root._bridge)
            return;
        root._bridge.active = root.dismissable.length > 0;
        root._bridge.windows = [...root.dismissable, ...root.persistent];
    }

    readonly property bool _canBridge: RyokuUi.Wm.caps.focusGrab === true
    on_CanBridgeChanged: root._build()
    Component.onCompleted: root._build()
    onPersistentChanged: root._syncBridge()
    onDismissableChanged: root._syncBridge()

    function _build() {
        if (root._bridge || !RyokuUi.Wm.caps.focusGrab)
            return;
        if (!root._component)
            root._component = Qt.createComponent("Ryoku.Wm.Hyprland", "FocusGrabBridge");
        const c = root._component;
        if (c.status === Component.Loading) {
            c.statusChanged.connect(root._build);
            return;
        }
        if (c.status !== Component.Ready)
            return;
        const b = c.createObject(root, { active: false, windows: [] });
        if (!b)
            return;
        b.cleared.connect(root.dismiss);
        root._bridge = b;
        root._syncBridge();
    }
}
