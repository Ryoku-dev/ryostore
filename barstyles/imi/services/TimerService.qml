pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
Singleton {
    id: root
    property bool pomodoroRunning: false
    property bool stopwatchRunning: false
    property bool pomodoroBreak: false
    property int pomodoroSecondsLeft: 0
    property int stopwatchTime: 0
}
