import QtQuick
import Quickshell.Widgets

// Rounded album art with a crossfade and a fallback glyph.
ClippingRectangle {
    id: root
    property string source: ""
    color: Theme.fill2

    Image {
        id: img
        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        sourceSize.width: 320
        sourceSize.height: 320
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 350 } }
    }
    Icon {
        anchors.centerIn: parent
        visible: img.status !== Image.Ready
        text: "music_note"
        fill: 1
        size: Math.max(10, root.width * 0.45)
        color: Theme.fg3
    }
}
