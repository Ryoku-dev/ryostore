pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// SongRec is not in this port; members read as empty.
Singleton {
    property var monitorSource: null
    property string monitorSourceString: ""
    property var recognizedTrack: ({})
    property string running: ""
    function openOnYouTube() {
    }
    function toggleMonitorSource() {
    }
    function toggleRunning() {
    }
}
