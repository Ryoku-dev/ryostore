pragma ComponentBehavior: Bound
import QtQuick
import Ryoku.PluginKit.Singletons
import "../service" as Shared
Item {
    id: root
    property var pluginApi
    property string density: "full"
    property real s: 1
    property real widthBudget: 280
    property bool active: false
    readonly property var service: Shared.Monitor
    implicitWidth: widthBudget
    implicitHeight: col.implicitHeight + 24 * s

    component Tap: Rectangle {
        id: button
        property string label
        property bool strong: false
        signal tapped()
        implicitWidth: caption.implicitWidth + 16 * root.s
        implicitHeight: 26 * root.s
        color: strong ? Theme.accent : "transparent"
        border.width: strong ? 0 : 1
        border.color: Theme.border
        Text {
            id: caption; anchors.centerIn: parent
            text: button.label; color: button.strong ? Theme.cardBot : Theme.bright
            font.family: Theme.mono; font.pixelSize: 10 * root.s
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: button.tapped() }
    }
    component Threshold: Item {
        id: control
        property string label
        property int value
        property int minimum: 1
        property int maximum: 50
        signal edited(int nextValue)
        width: col.width; height: 28 * root.s
        Text {
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            text: control.label; color: Theme.dim; font.family: Theme.font; font.pixelSize: 12 * root.s
        }
        Row {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            spacing: 7 * root.s
            Tap { label: "−"; onTapped: if (control.value > control.minimum) control.edited(control.value - 1) }
            Text {
                width: 32 * root.s; height: 26 * root.s
                text: control.value + "%"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                color: Theme.bright; font.family: Theme.mono; font.pixelSize: 11 * root.s
            }
            Tap { label: "+"; onTapped: if (control.value < control.maximum) control.edited(control.value + 1) }
        }
    }
    Column {
        id: col
        x: 12 * root.s; y: 12 * root.s
        width: root.width - 24 * root.s; spacing: 8 * root.s
        Item {
            width: parent.width; height: 22 * root.s
            Text { anchors.left: parent.left; text: qsTr("BATTERY ALERTS"); color: Theme.bright; font.family: Theme.mono; font.pixelSize: 11 * root.s; font.letterSpacing: 1 * root.s }
            Text { anchors.right: parent.right; text: root.service && root.service.percentage >= 0 ? root.service.percentage + "%" : "—"; color: Theme.accent; font.family: Theme.mono; font.pixelSize: 11 * root.s }
        }
        Threshold {
            label: qsTr("Warning"); value: root.service ? root.service.lowThreshold : 25
            minimum: root.service ? Math.max(5, root.service.criticalThreshold + 1) : 11; maximum: 50
            onEdited: (nextValue) => root.service.saveSetting("lowThreshold", nextValue)
        }
        Threshold {
            label: qsTr("Critical"); value: root.service ? root.service.criticalThreshold : 10
            maximum: root.service ? root.service.lowThreshold - 1 : 24
            onEdited: (nextValue) => root.service.saveSetting("criticalThreshold", nextValue)
        }
        Rectangle { width: parent.width; height: 1; color: Theme.border }
        Item {
            width: parent.width; height: 26 * root.s
            Tap {
                anchors.left: parent.left
                label: root.service && root.service.enabled ? qsTr("PAUSE") : qsTr("ENABLE")
                onTapped: root.service.saveSetting("enabled", !root.service.enabled)
            }
            Tap { anchors.right: parent.right; strong: true; label: qsTr("TEST ALERT"); onTapped: if (root.service) root.service.testNotification() }
        }
        Text {
            width: parent.width
            text: root.service && root.service.lastResult.length > 0 ? root.service.lastResult : qsTr("Once per level · resets on AC")
            color: Theme.dim; font.family: Theme.font; font.pixelSize: 10 * root.s; wrapMode: Text.WordWrap
        }
    }
}
