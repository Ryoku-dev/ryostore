pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// KeyboardBacklight is not in this port; members read as empty.
Singleton {
    property bool suppressOsd: false
    property bool keysOnly: false
    property bool initialValueLoaded: true

    property string available: ""
    property string currentValue: ""
    property var levelText: null
    property var levels: null
    property var maxValue: ({})
    property real percentage: 0
    property real ready: 0
    function cycleNext() {
    }
    function cyclePrevious() {
    }
    function setValue() {
    }
}
