import "../../common"
import "../../common/widgets"
import "../../../services"
import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../../shared" as Shared
import "../../../popouts" as Popouts

Item {
    id: root
    property bool vertical: Config.options.bar.vertical
    property bool isMaterial: Config.options.bar.cornerStyle === 3

    implicitWidth: vertical ? 32 : ((contentLoader.item?.implicitWidth ?? 0) + (isMaterial ? 14 : 8))
    implicitHeight: vertical ? (contentLoader.item?.implicitHeight ?? 0) : Appearance.sizes.barHeight
    width: implicitWidth
    height: implicitHeight

    HoverHandler { id: hh }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: 11
        color: hh.hovered ? Qt.rgba(0, 0, 0, 0.18) : "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    Shared.Popout {
        target: root
        targetHovered: hh.hovered
        preferredWidth: 300
        preferredHeight: 340
        namespace: "ryoku-bar-popout"
        content: Component {
            Popouts.WeatherPopout {}
        }
    }

    Loader {
        id: contentLoader
        anchors.centerIn: parent
        sourceComponent: root.vertical ? colContent : rowContent
    }

    Component {
        id: rowContent
        RowLayout {
            spacing: 6
            Layout.alignment: Qt.AlignVCenter

            MaterialSymbol {
                fill: 0
                text: Icons.getWeatherIcon(Weather.data.wCode) ?? "sunny"
                iconSize: Appearance.font.pixelSize.large
                color: root.isMaterial ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1
                Layout.alignment: Qt.AlignVCenter
                leftPadding: 4
            }

            StyledText {
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
                color: root.isMaterial ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1
                text: Weather.data?.temp ?? "--°"
                Layout.alignment: Qt.AlignVCenter
                rightPadding: 6
            }
        }
    }

    Component {
        id: colContent
        ColumnLayout {
            spacing: 2
            MaterialSymbol {
                fill: 0
                text: Icons.getWeatherIcon(Weather.data.wCode) ?? "sunny"
                iconSize: Appearance.font.pixelSize.large
                color: root.isMaterial ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1
                Layout.alignment: Qt.AlignHCenter
            }
            StyledText {
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: root.isMaterial ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1
                text: Weather.data?.temp ?? "--°"
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
}
