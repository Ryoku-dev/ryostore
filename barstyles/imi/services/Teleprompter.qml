pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// Teleprompter is not in this port; members read as empty.
Singleton {
    property var available: null
    property var boxWidth: null
    property var compactBoxHeight: null
    property var dragHovering: null
    property var expandedBoxWidth: null
    property var featureEnabled: null
    property var holdVisible: null
    property var qml: null
    property var running: null
    function start() {
    }
    function startFromClipboard() {
    }
}
