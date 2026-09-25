pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// Persistent service for the tile. The content reads everything from here
// through pluginApi.mainInstance when a widget needs a live object that
// survives the tile being hidden or re-mounted.
Item {
    id: svc

    property var pluginApi

}
