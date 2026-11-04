pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// Ydotool is not in this port; members read as empty.
Singleton {
    property var latchLocked: null
    property var latchOff: null
    property var latched: null
    property var shiftKeys: null
    property var shiftMode: null
    function press() {
    }
    function release() {
    }
    function releaseAllKeys() {
    }
    function releaseShiftKeys() {
    }
    function tapKey() {
    }
    function toggleLatch() {
    }
}
