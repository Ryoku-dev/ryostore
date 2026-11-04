pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// GoogleTasksService is not in this port; members read as empty.
Singleton {
    signal taskUpdated(var task)
    property var activeAccountEmail: ({})
    property var available: null
    property var syncing: null
    property var tasks: ({})
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
