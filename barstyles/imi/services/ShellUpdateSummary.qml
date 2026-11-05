pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// ShellUpdateSummary is not in this port; members read as empty.
Singleton {
    property real available: 0
    property var current: null
    property string error: ""
    property real generating: 0
    property string modelTitle: ""
    property string text: ""
    property string unavailableReason: ""
    function summarize() {
    }
}
