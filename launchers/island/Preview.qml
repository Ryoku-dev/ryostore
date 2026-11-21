import QtQuick
import Ryoku.Ui.Singletons

// The still Ryoku Settings shows for Island: the black pill open over the
// desktop, a query typed, the top result on its glass slab.
Item {
    id: root

    property var settings: ({})
    signal editRequested(string key, var value)

    implicitWidth: 720
    implicitHeight: 250

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.darker(Tokens.sun, 2.6) }
            GradientStop { position: 1; color: Qt.darker(Tokens.sun, 1.6) }
        }
    }

    Rectangle {
        id: pill
        width: 440
        height: 214
        anchors.horizontalCenter: parent.horizontalCenter
        y: 18
        radius: 26
        color: "#000000"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.08)

        Text {
            x: 20; y: 16
            text: "⌕  fire"
            color: "#ffffff"
            font.family: Tokens.ui
            font.pixelSize: 17
            font.weight: Font.Medium
        }
        Rectangle { x: 16; y: 50; width: parent.width - 32; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

        Repeater {
            model: [
                { name: "Firefox", sub: "Web Browser" },
                { name: "Firewall", sub: "Network security" },
                { name: "File Roller", sub: "Archive Manager" }
            ]
            delegate: Item {
                id: row
                required property var modelData
                required property int index
                x: 8
                y: 58 + index * 48
                width: pill.width - 16
                height: 46
                // the glass selection slab, drawn flat for the still
                Rectangle {
                    anchors.fill: parent
                    visible: row.index === 0
                    radius: 14
                    color: Qt.rgba(1, 1, 1, 0.09)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.16)
                }
                Rectangle {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28; height: 28; radius: 8
                    color: Qt.rgba(Tokens.sun.r, Tokens.sun.g, Tokens.sun.b, 0.35)
                }
                Column {
                    x: 52
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: row.modelData.name; color: "#ffffff"; font.family: Tokens.ui; font.pixelSize: 13; font.weight: Font.DemiBold }
                    Text { text: row.modelData.sub; color: Qt.rgba(1, 1, 1, 0.55); font.family: Tokens.ui; font.pixelSize: 11 }
                }
            }
        }
    }
}
