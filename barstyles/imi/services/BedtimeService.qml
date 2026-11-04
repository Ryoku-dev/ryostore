pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// BedtimeService is not in this port; members read as empty.
Singleton {
    property var enabled: null
    property string phase: ""
    property var targetTime: null
    property var windDownMinutes: null
}
