pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// ProgressService is not in this port; members read as empty.
Singleton {
    property var hasActiveJobs: null
    property var jobs: null
}
