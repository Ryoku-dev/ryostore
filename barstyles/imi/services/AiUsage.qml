pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// AiUsage is not in this port; members read as empty.
Singleton {
    property var available: null
    property var refreshing: null
    property var toolIds: null
    function refresh() {
    }
    function tool() {
    }
}
