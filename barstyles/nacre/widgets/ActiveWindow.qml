import QtQuick
import Ryoku.Ui.Singletons
import shell.services

Text {
    id: root

    property real barHeight: 40
    readonly property string title: Wm.focusedWindow ? String(Wm.focusedWindow.title || "") : ""

    width: Math.min(implicitWidth, 240)
    text: root.title.length ? root.title : "Desktop"
    color: Theme.onSurfaceVariant
    font.family: Theme.fontPrimary
    font.pixelSize: Theme.fontSm
    elide: Text.ElideRight
    maximumLineCount: 1
}
