pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// DockerService is not in this port; members read as empty.
Singleton {
    property list<var> containers: []
    property var dockerAvailable: null
    property string dockerRunning: ""
    property var isLoading: null
    property string runningCount: ""
    property real totalMemoryMb: 0
    function containerAction() {
    }
    function openInBrowser() {
    }
    function openLogs() {
    }
    function openShell() {
    }
    function refreshForPopup() {
    }
    function requestConsumer() {
    }
    function toggleDockerService() {
    }
}
