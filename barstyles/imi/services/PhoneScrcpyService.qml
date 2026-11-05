pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// PhoneScrcpyService is not in this port; members read as empty.
Singleton {
    property real appModeSupported: 0
    property var apps: null
    property string appsLoading: ""
    property string available: ""
    property var embedLaunching: null
    property var embedRunning: null
    property real filteredApps: 0
    property var mirrorElapsedMs: null
    property var mirrorLaunchError: null
    property real mirrorLaunching: 0
    property real mirrorRunning: 0
    property real recordingElapsedMs: 0
    property var recordingLaunching: null
    property var recordingRunning: null
    property var sessions: null
    function _fmtDuration() {
    }
    function focusApp() {
    }
    function isAppFavorite() {
    }
    function isAppRunning() {
    }
    function launchApp() {
    }
    function launchMirror() {
    }
    function openMirrorWindow() {
    }
    function refreshApps() {
    }
    function restartMirror() {
    }
    function setSearchQuery() {
    }
    function stopAllApps() {
    }
    function stopApp() {
    }
    function stopMirror() {
    }
    function stopMirroring() {
    }
    function toggleAppFavorite() {
    }
    function toggleRecording() {
    }
}
