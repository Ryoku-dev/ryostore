pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// SpeedTestService is not in this port; members read as empty.
Singleton {
    property var lastResult: null
    property string phase: ""
    property real progress: 0
    property string running: ""
    function cancelTest() {
    }
    function formatSpeed() {
    }
    function startTest() {
    }
}
