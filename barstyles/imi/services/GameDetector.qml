pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// GameDetector is not in this port; members read as empty.
Singleton {
    property var gameRunning: null
    property var primaryMatch: null
    property var qml: null
    property var rawFocused: null
    property real rawRunning: 0
    property var reason: null
    function acquire() {
    }
    function addExtraClass() {
    }
    function release() {
    }
    function removeExtraClass() {
    }
    function statusText() {
    }
}
