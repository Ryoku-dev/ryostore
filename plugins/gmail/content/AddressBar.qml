import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    property string directory: ""
    signal navigateToDirectory(string path)

    Layout.fillWidth: true
    implicitHeight: 38
    radius: 8
    color: (typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colLayer1 : "#222228"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10

        MaterialSymbol {
            text: "folder"
            iconSize: 16
            color: (typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colPrimary : "#ff5252"
        }

        Text {
            Layout.fillWidth: true
            text: root.directory
            font.family: (typeof Appearance !== "undefined" && Appearance && Appearance.font && Appearance.font.family) ? Appearance.font.family.mono : "monospace"
            font.pixelSize: 12
            color: "#ffffff"
            elide: Text.ElideMiddle
        }
    }
}
