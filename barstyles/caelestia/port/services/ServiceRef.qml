import QtQml

// Sysinfo and StatsFeed stay idle unless at least one active consumer claims them.
QtObject {
    id: root

    property var service: null
    property var _claimed: null

    function _release(svc: var): void {
        if (!svc)
            return;
        try {
            if (typeof svc.unref === "function")
                svc.unref(root);
            else if (typeof svc.setActive === "function")
                svc.setActive(root, false);
        } catch (e) {}
    }

    function _acquire(svc: var): void {
        if (!svc)
            return;
        if (typeof svc.ref === "function")
            svc.ref(root);
        else if (typeof svc.setActive === "function")
            svc.setActive(root, true);
    }

    function _sync(): void {
        if (_claimed === service)
            return;
        _release(_claimed);
        _claimed = service;
        _acquire(_claimed);
    }

    onServiceChanged: _sync()
    Component.onCompleted: _sync()
    Component.onDestruction: {
        _release(_claimed);
        _claimed = null;
    }
}
