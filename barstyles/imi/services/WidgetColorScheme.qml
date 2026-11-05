pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// WidgetColorScheme is not in this port; members read as empty.
Singleton {
    property var accentColor: null
    property real cardBgColor: 0
    property real highlightCircleColor: 0
    property var innerShapeColor: null
    property real outlineColor: 0
    property var pillBgColor: null
    property var pillFillColor: null
    property var subtextColorOnBg: null
    property real textColorOnBg: 0
    property var textColorOnPillFill: null
    property var textColorOnPillTrack: null
    function tintBackground() {
    }
}
