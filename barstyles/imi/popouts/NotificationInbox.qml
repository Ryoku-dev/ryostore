import QtQuick
import shell.barkit as Menus

Item {
    id: root

    property bool open: false
    signal closeRequested()

    implicitWidth: 340
    implicitHeight: 520

    Menus.MenuNotifications {
        id: content
        anchors.fill: parent
        anchors.margins: 12
        s: 1
        open: root.open
        onRequestClose: root.closeRequested()
    }
}
