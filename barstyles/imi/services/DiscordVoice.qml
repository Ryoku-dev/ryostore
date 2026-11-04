pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// DiscordVoice is not in this port; members read as empty.
Singleton {
    property var channel: ({})
    property string currentUser: ""
    property real deafened: 0
    property var inVoice: ({})
    property string muted: ""
    property real participants: 0
    property string status: ""
    function avatarUrl() {
    }
    function setDeafened() {
    }
    function setMuted() {
    }
}
