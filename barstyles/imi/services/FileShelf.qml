pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// FileShelf is not in this port; members read as empty.
Singleton {
    property var count: null
    property var items: null
    property var newest: null
    function add() {
    }
    function clear() {
    }
    function remove() {
    }
}
