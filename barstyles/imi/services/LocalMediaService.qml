pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// LocalMediaService is not in this port; members read as empty.
Singleton {
    property var hasSession: null
    property string player: ""
    property string queueSnapshot: ""
}
