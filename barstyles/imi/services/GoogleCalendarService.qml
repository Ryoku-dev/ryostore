pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// GoogleCalendarService is not in this port; members read as empty.
Singleton {
    property var activeAccountEmail: null
    property var authenticating: null
    property string available: ""
    property var credentialsConfigured: null
    function disconnect() {
    }
    function startOAuth() {
    }
}
