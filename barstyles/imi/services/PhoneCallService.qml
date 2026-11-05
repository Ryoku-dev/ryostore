pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// PhoneCallService is not in this port; members read as empty.
Singleton {
    property var _simulated: null
    property var active: null
    property var adbLive: null
    property var avatarPath: null
    property string callState: ""
    property var displayName: null
    property real stateSince: 0
    function answer() {
    }
    function decline() {
    }
    function silence() {
    }
}
