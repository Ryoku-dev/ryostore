pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// KeypressService is not in this port; members read as empty.
Singleton {
    property var manualEnabled: null
    property var recordingEnabled: null
    function toggleForRecording() {
    }
    function toggleManual() {
    }
}
