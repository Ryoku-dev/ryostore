pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// SearchRegistry is not in this port; members read as empty.
Singleton {
    property string currentSearch: ""
}
