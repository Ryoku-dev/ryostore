pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// Fingerprint is not in this port; members read as empty.
Singleton {
    property var busy: null
    property var deviceAvailable: null
    property real hasEnrolled: 0
    function probeDevice() {
    }
}
