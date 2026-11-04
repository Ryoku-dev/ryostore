pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// AskpassService is not in this port; members read as empty.
Singleton {
    property bool current: false
    property string currentStyle: ""
    property var focusNow: null
    property var polkitOnIsland: null
    property var revision: null
    property var waitingCount: null
    function cancel() {
    }
    function submit() {
    }
}
