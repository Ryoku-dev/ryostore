pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// WindowSwitcher is not in this port; members read as empty.
Singleton {
    property real active: 0
    property string appFilter: ""
    property var appFilterName: null
    property real count: 0
    property var currentAddress: null
    property var enabled: null
    property real entries: 0
    property string landingAddress: ""
    property var peekArming: null
    property real peekDelayMs: 0
    property var peekEntry: null
    property var peekWholeWorkspace: null
    property var peeking: null
    property string presenter: ""
    property list<var> query: []
    property var released: null
    property var screenName: null
    property var selectedAddress: null
    property var selectedEntry: null
    property real selectedIndex: 0
    property real settling: 0
    property real showKeyHints: 0
    property var shown: null
    property var undimRecordPath: null
    property real workspaceAtOpen: 0
    function activate() {
    }
    function closeAt() {
    }
    function dismiss() {
    }
    function hover() {
    }
    function monitorWorkspace() {
    }
    function select() {
    }
    function step() {
    }
    function workspaceEntries() {
    }
}
