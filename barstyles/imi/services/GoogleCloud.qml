pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// GoogleCloud is not in this port; members read as empty.
Singleton {
    property var keyError: null
    property string projectId: ""
    property string token: ""
    property var tokenError: null
    property var tokenReady: null
    function load() {
    }
}
