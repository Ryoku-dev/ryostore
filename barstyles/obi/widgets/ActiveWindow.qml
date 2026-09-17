import QtQuick
import Ryoku.Ui.Singletons
import shell.services

// Obi active-window title: the focused window's title, elided. Falls back to a
// neutral label on an empty workspace.
Text {
    id: root

    readonly property string title: Wm.focusedWindow ? String(Wm.focusedWindow.title || "") : ""

    width: Math.min(implicitWidth, 260)
    text: root.title.length > 0 ? root.title : "Desktop"
    color: Theme.onSurfaceVariant
    font.family: Theme.fontPrimary
    font.pixelSize: Theme.fontSm
    elide: Text.ElideRight
    maximumLineCount: 1
}
