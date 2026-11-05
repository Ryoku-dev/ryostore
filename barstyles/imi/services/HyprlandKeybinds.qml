pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// HyprlandKeybinds is not in this port; members read as empty.
Singleton {
    property string defaultKeybinds: ""
    property string userKeybinds: ""
    function dispatchBinding() {
    }
}
