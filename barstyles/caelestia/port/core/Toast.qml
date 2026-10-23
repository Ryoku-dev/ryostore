import QtQuick

// One toast of the Toaster: closes after its timeout, and stays until every
// item that locked it (its on-screen card) lets go.
QtObject {
    id: toast

    enum Type {
        Info,
        Success,
        Warning,
        Error
    }

    property string title
    property string message
    property string icon
    property int type: Toast.Info
    property int timeout
    property bool closed: false
    property var _locks: []

    signal finishedClose

    readonly property string resolvedIcon: icon || ["info", "radio_button_checked_unread", "warning", "error"][type]
    readonly property int resolvedTimeout: timeout > 0 ? timeout : [5000, 5000, 7000, 10000][type]

    function close(): void {
        closed = true;
        if (_locks.length === 0)
            finishedClose();
    }

    function lock(sender: QtObject): void {
        _locks = _locks.concat([sender]);
        sender.destroyed.connect(() => unlock(sender));
    }

    function unlock(sender: QtObject): void {
        const i = _locks.indexOf(sender);
        if (i < 0)
            return;
        _locks = _locks.filter(s => s !== sender);
        if (closed)
            close();
    }

    property Timer _timer: Timer {
        interval: toast.resolvedTimeout
        running: true
        onTriggered: toast.close()
    }
}
