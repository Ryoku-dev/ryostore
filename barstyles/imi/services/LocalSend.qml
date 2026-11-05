pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// LocalSend is not in this port; members read as empty.
Singleton {
    property var available: null
    property string currentTransfer: ""
    property list<var> discoveredDevices: []
    property list<var> droppedFiles: []
    property real scanning: 0
    property real sending: 0
    property string serverRunning: ""
    function acceptTransfer() {
    }
    function addDroppedFile() {
    }
    function clearDroppedFiles() {
    }
    function denyTransfer() {
    }
    function formatFileSize() {
    }
    function openFilePicker() {
    }
    function removeDroppedFile() {
    }
    function sendToDevice() {
    }
    function startScanning() {
    }
    function startServer() {
    }
    function stopScanning() {
    }
    function stopServer() {
    }
}
