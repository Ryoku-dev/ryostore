pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// RemindersService is not in this port; members read as empty.
Singleton {
    property var activeCount: null
    property var allDayTime: null
    property var reminders: ({})
    property var ringing: null
    property real ringingLevel: 0
    property real snoozeMinutes: 0
    property var upcoming: null
    function category() {
    }
    function complete() {
    }
    function create() {
    }
    function dueAt() {
    }
    function isOverdue() {
    }
    function open() {
    }
    function reminder() {
    }
    function snooze() {
    }
    function stopRinging() {
    }
    function toggleChecklistItem() {
    }
    function whenText() {
    }
}
