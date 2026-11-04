pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// DictationService is not in this port; members read as empty.
Singleton {
    property var available: null
    property var bridgeInstalled: null
    property bool busy: false
    property real elapsedMs: 0
    property real languageBadge: 0
    property var qualityLabel: null
    property var recording: null
    property list<var> transcribing: []
    property real waveform: 0
    function discard() {
    }
    function stop() {
    }
    function toggle() {
    }
}
