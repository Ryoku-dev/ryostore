pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// LocalMediaSelection is not in this port; members read as empty.
Singleton {
    property bool enabled: false
    function chooseMusicFiles() {
    }
    function chooseMusicFolder() {
    }
}
