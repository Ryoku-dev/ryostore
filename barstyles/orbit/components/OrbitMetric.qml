import QtQuick
import shell.services

Item {
    id: root

    property string label: ""
    property string value: ""
    property bool accent: false
    property bool warning: false

    implicitWidth: 88
    implicitHeight: 36

    Rectangle {
        x: 0
        y: 1
        width: root.accent || root.warning ? 18 : 8
        height: 1
        radius: 1

        color: root.warning
            ? Theme.error
            : root.accent
                ? Theme.primary
                : Theme.outlineVariant

        opacity: root.accent || root.warning ? 0.85 : 0.45

        Behavior on width {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }
    }

    Text {
        x: 0
        y: 7
        text: root.label
        color: Theme.onSurfaceVariant
        font.family: Theme.mono
        font.pixelSize: 8
        font.letterSpacing: 0.8
    }

    Text {
        x: 0
        y: 19
        width: parent.width
        text: root.value
        elide: Text.ElideRight

        color: root.warning
            ? Theme.error
            : root.accent
                ? Theme.primary
                : Theme.onSurface

        font.family: Theme.mono
        font.pixelSize: 11
        font.weight: Font.Medium
    }
}
