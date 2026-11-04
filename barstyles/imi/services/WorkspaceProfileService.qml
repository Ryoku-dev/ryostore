pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// WorkspaceProfileService is not in this port; members read as empty.
Singleton {
    property var binaryExists: null
    property var profiles: ({})
    function restoreProfile() {
    }
}
