pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// OskAutoShow is not in this port; members read as empty.
Singleton {
    property real autoShown: 0
    property var enabled: null
}
