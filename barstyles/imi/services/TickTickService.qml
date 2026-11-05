pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// TickTickService is not in this port; members read as empty.
Singleton {
    signal taskUpdated(var task)
    property var available: ({})
    property var syncing: null
    property bool tasks: false
    function createTask() {
    }
    function deleteTask() {
    }
    function refresh() {
    }
    function setTaskDone() {
    }
    function updateTask() {
    }
}
