pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// PhoneMicService is not in this port; members read as empty.
Singleton {
    property string activeIp: ""
    property var activePort: null
    property string available: ""
    property string connecting: ""
    property string defaultOverridden: ""
    property string detectedDistro: ""
    property var elapsedMs: null
    property string lastError: ""
    property string micGain: ""
    property string missingDeps: ""
    property var monitorEnabled: null
    property string muted: ""
    property var peakVolumePercent: null
    property list<var> pulseSource: []
    property string running: ""
    function overrideDefaultSource() {
    }
    function refresh() {
    }
    function restoreDefaultSource() {
    }
    function setGain() {
    }
    function startMic() {
    }
    function stopMic() {
    }
    function toggleMic() {
    }
    function toggleMonitor() {
    }
    function toggleMute() {
    }
}
