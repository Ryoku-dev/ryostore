pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// PortWatcher is not in this port; members read as empty.
Singleton {
    property var actionBusy: ({})
    property var actionMessage: null
    property string actionSuccess: ""
    property string available: ""
    property var busyPortId: ({})
    property real connectionCount: 0
    property real count: 0
    property real enabled: 0
    property var errorMessage: null
    property string exposedCount: ""
    property var lastUpdated: null
    property real refreshing: 0
    property var visiblePorts: ({})
    function addressFor() {
    }
    function copyAddress() {
    }
    function openInBrowser() {
    }
    function refresh() {
    }
    function stopPort() {
    }
    function urlFor() {
    }
}
