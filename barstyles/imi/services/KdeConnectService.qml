pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// KdeConnectService is not in this port; members read as empty.
Singleton {
    property var _enabled: null
    property var _timeTick: null
    property real activeDevice: 0
    property list<var> activeDeviceDisplayName: []
    property var activeDeviceId: ({})
    property list<var> activeReachable: []
    property real adbReachable: 0
    property real appNameList: 0
    property real available: 0
    property var checkAdbProc: null
    property var checkPythonDbusProc: null
    property var checkScrcpyProc: null
    property string detectedDistro: ""
    property bool devices: false
    property list<var> groupsByAppName: []
    property real hasDevices: 0
    property real notificationCount: 0
    property list<var> notifications: []
    property var pendingPairRequests: null
    property string pinnedAdbHost: ""
    property var recentDevices: null
    property var remoteKeyboardActive: null
    property string resolvedWirelessHost: ""
    property string scrcpyAvailable: ""
    property real scrcpyElapsedMs: 0
    property var scrcpyLaunchError: null
    property var scrcpyLaunching: null
    property string scrcpyMissingDeps: ""
    property real scrcpyRunning: 0
    property var serviceEnabled: null
    property var statusText: null
    function _probeAdb() {
    }
    function acceptPairing() {
    }
    function adbScreenshot() {
    }
    function adbTogglePower() {
    }
    function browseFiles() {
    }
    function considerTransferNotification() {
    }
    function declinePairing() {
    }
    function discardAllNotifications() {
    }
    function discardNotification() {
    }
    function dispatchActionFeedback() {
    }
    function enableWirelessAdb() {
    }
    function findMyPhone() {
    }
    function focusScrcpyWindow() {
    }
    function isIgnoredNotification() {
    }
    function openExtendedUnlockSettings() {
    }
    function openNotificationIntent() {
    }
    function promptWirelessConnect() {
    }
    function refreshDevices() {
    }
    function replyNotification() {
    }
    function requestNotificationsRefresh() {
    }
    function selectDevice() {
    }
    function sendAction() {
    }
    function sendClipboard() {
    }
    function sendFile() {
    }
    function sendPing() {
    }
    function sendRemoteKey() {
    }
    function sendRemoteText() {
    }
    function shareText() {
    }
    function shareUrl() {
    }
}
