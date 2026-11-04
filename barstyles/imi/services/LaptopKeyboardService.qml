pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// LaptopKeyboardService is not in this port; members read as empty.
Singleton {
    property var disabled: null
    property var keydDetected: null
    function toggle() {
    }
}
