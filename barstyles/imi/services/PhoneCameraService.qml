pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// PhoneCameraService is not in this port; members read as empty.
Singleton {
    property string activeIp: ""
    property var activePort: null
    property string available: ""
    property string connecting: ""
    property string detectedDistro: ""
    property var elapsedMs: null
    property string lastError: ""
    property string missingDeps: ""
    property string running: ""
    property list<var> videoDevice: []
    function flipCamera() {
    }
    function openExternalPreview() {
    }
    function refresh() {
    }
    function setRotation() {
    }
    function startCamera() {
    }
    function stopCamera() {
    }
    function toggleCamera() {
    }
    function toggleMirror() {
    }
}
