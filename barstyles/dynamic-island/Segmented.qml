pragma ComponentBehavior: Bound
import QtQuick

// iOS segmented control. model: ["A","B"] or [{label, icon, value}]
Rectangle {
    id: root
    property var model: []
    property int currentIndex: 0
    property real itemHeight: 28
    property bool iconsOnly: false
    signal activated(int index)

    readonly property real segW: model.length > 0 ? (width - 4) / model.length : 0
    implicitHeight: itemHeight + 4
    implicitWidth: 240
    radius: 9
    color: Theme.fill

    Rectangle {
        y: 2
        x: 2 + root.currentIndex * root.segW
        width: root.segW
        height: root.itemHeight
        radius: 7
        color: Theme.dark ? Qt.rgba(1, 1, 1, 0.20) : "#ffffff"
        border.width: Theme.dark ? 0 : 0.5
        border.color: Qt.rgba(0, 0, 0, 0.06)
        Behavior on x { SpringAnimation { spring: 5; damping: 0.4 } }
    }
    Row {
        x: 2; y: 2
        Repeater {
            model: root.model
            Item {
                id: seg
                required property var modelData
                required property int index
                readonly property string label: typeof modelData === "string" ? modelData : (modelData.label || "")
                readonly property string icon: typeof modelData === "string" ? "" : (modelData.icon || "")
                width: root.segW
                height: root.itemHeight
                Row {
                    anchors.centerIn: parent
                    spacing: 5
                    Icon {
                        visible: seg.icon !== ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: seg.icon
                        size: 16
                        fill: root.currentIndex === seg.index ? 1 : 0
                    }
                    Txt {
                        visible: !root.iconsOnly && seg.label !== ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: seg.label
                        size: 12.5
                        weight: root.currentIndex === seg.index ? Font.DemiBold : Font.Medium
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.activated(seg.index)
                }
            }
        }
    }
}
