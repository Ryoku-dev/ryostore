import QtQuick
import Quickshell.Widgets

// Squircle app icon with a glyph fallback.
Item {
    id: root
    property string source: ""
    property string fallback: "notifications"
    property color fallbackColor: Theme.accent
    property real size: 38
    implicitWidth: size
    implicitHeight: size

    readonly property bool ok: img.status === Image.Ready

    Rectangle {
        anchors.fill: parent
        radius: root.size * 0.24
        visible: !root.ok
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.lighter(root.fallbackColor, 1.15) }
            GradientStop { position: 1; color: Qt.darker(root.fallbackColor, 1.15) }
        }
        Icon {
            anchors.centerIn: parent
            text: root.fallback
            fill: 1
            size: root.size * 0.55
            color: "#ffffff"
        }
    }
    ClippingRectangle {
        anchors.fill: parent
        radius: root.size * 0.24
        color: "transparent"
        visible: root.ok
        Image {
            id: img
            anchors.fill: parent
            source: root.source
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
            mipmap: true
            sourceSize.width: root.size * 2
            sourceSize.height: root.size * 2
        }
    }
}
