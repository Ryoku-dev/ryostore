pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// SmartDevicesService is not in this port; members read as empty.
Singleton {
    property string anyDeviceOn: ""
    property real deviceCount: 0
    property list<var> devices: []
    property real hasDevices: 0
    property var heroLevel: null
    property var heroUnit: null
    property var heroValue: null
    property string isRefreshing: ""
    property var statusText: null
    function hsvToHex() {
    }
    function readCache() {
    }
    function refresh() {
    }
    function setDeviceColourHsv() {
    }
    function setDevicePower() {
    }
    function setDeviceWhite() {
    }
    function toggleAll() {
    }
}
