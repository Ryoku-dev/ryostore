pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// PhoneAppIconService is not in this port; members read as empty.
Singleton {
    property var batchSize: null
    property var enabled: null
    property var fetched: null
    property var fetching: null
    function clearCache() {
    }
    function fetchMissing() {
    }
    function iconFor() {
    }
}
