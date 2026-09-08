pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import "../../../services"
import ".."

// Kirigami-free app icon. The shell's runtime does not ship
// org.kde.kirigami, so wrapping Kirigami.Icon here made every component
// that instantiates an AppIcon fail to load (the workspaces widget's
// per-workspace app icons among them - the bar drew an empty slot with
// only the edit-mode delete button left). Quickshell's own IconImage
// covers the one thing the bar needed from Kirigami.Icon: a square
// themed icon whose size one property controls.
//
// `animated` stays as a compatibility no-op: Kirigami.Icon crossfaded
// on source change, and the workspaces widget binds it to suppress the
// image-missing flicker. IconImage swaps sources in place, so there is
// nothing to fade and nothing to suppress.
IconImage {
    id: root

    property real implicitSize: 26
    property bool animated: false

    implicitWidth: implicitSize
    implicitHeight: implicitSize
}
