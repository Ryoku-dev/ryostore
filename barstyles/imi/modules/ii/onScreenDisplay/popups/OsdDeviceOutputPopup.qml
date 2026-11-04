import "../../bar/shared"
import "../../../common"
import "../../../common/widgets"
import "../../../../services"
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root

    property real contentHeight: 460

    contentItem: Item {
        implicitWidth: 320
        implicitHeight: root.contentHeight

        StyledFlickable {
            anchors.fill: parent
            anchors.margins: 12
            contentHeight: deviceColumn.implicitHeight
            clip: true

            ColumnLayout {
                id: deviceColumn
                width: parent.width
                spacing: 8

                Repeater {
                    model: Audio.outputDevices
                    delegate: OsdDeviceOutputItem {
                        required property var modelData
                        node: modelData
                    }
                }
            }
        }
    }
}
