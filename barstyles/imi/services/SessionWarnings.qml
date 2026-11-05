pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// SessionWarnings is not in this port; members read as empty.
Singleton {
    property var downloadRunning: null
    property var packageManagerRunning: null
    function refresh() {
    }
}
