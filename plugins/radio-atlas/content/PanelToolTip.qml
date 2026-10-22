import QtQuick

// Port shim for the Omarchy shell's tooltip bubble. Used with visible, text
// and delay; the bubble sits centred above its parent without stealing layout.
Rectangle {
    id: root

    property string text: ""
    property int delay: 400

    implicitWidth: label.implicitWidth + 16
    implicitHeight: label.implicitHeight + 10

    radius: 6
    color: "#f2f2f2"
    border.width: 1
    border.color: "#98999c"

    visible: false
    z: 5

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        textFormat: Text.PlainText
        color: "#101010"
        font.pixelSize: 12
    }
}
