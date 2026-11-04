pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// PhoneMirrorService is not in this port; members read as empty.
Singleton {
    property string attached: ""
    property real cornerRadius: 0
    property var deviceAspect: null
    property var deviceHeight: null
    property var deviceWidth: null
    property list<var> lastError: []
    property var layerNamespace: null
    property var running: null
    property real screenName: 0
    property var toplevel: null
    property var touchRect: null
    property var touchWanted: null
    property var wanted: null
    function detachToWindow() {
    }
    function goBack() {
    }
    function goHome() {
    }
    function goRecents() {
    }
    function openNotifications() {
    }
    function reassertGeometry() {
    }
    function togglePower() {
    }
    function volumeDown() {
    }
    function volumeUp() {
    }
}
