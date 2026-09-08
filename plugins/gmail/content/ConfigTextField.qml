import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    property string text: ""
    property string icon: ""
    property string tooltip: ""
    property alias placeholderText: textFieldWidget.placeholderText
    property alias inputText: textFieldWidget.text
    property alias textField: textFieldWidget
    property Component rightAction: null

    Layout.fillWidth: true
    implicitHeight: 44
    radius: 8
    color: (typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colSurfaceContainerHigh : "#222228"
    border.width: textFieldWidget.activeFocus ? 1.5 : 1
    border.color: textFieldWidget.activeFocus ? ((typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colPrimary : "#ff5252") : Qt.rgba(1, 1, 1, 0.1)

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 8

        MaterialSymbol {
            visible: root.icon !== ""
            text: root.icon
            iconSize: 18
            color: (typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colOnSurfaceVariant : "#888888"
        }

        TextField {
            id: textFieldWidget
            Layout.fillWidth: true
            color: (typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colOnSurface : "#e6e1e1"
            placeholderTextColor: (typeof Appearance !== "undefined" && Appearance && Appearance.colors) ? Appearance.colors.colOnSurfaceVariant : "#666666"
            font.family: (typeof Appearance !== "undefined" && Appearance && Appearance.font && Appearance.font.family) ? Appearance.font.family.main : "Space Grotesk"
            font.pixelSize: 13
            background: null
            verticalAlignment: Text.AlignVCenter
        }

        Loader {
            active: root.rightAction !== null
            sourceComponent: root.rightAction
        }
    }
}
