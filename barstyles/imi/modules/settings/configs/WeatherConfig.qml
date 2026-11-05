import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../services"
import "../../../modules/common"
import "../../../modules/common/functions"
import "../../../modules/common/widgets"
import "widgets"

ContentPage {
    id: root

    forceWidth: false

    ContentSection {
        icon: "cloud"
        title: Translation.tr("Weather Service")

        WeatherLocationCard {
            Layout.fillWidth: true
        }

        ConfigSpinBox {
            icon: "av_timer"
            text: Translation.tr("Polling interval (m)")
            value: Config.options.bar.weather.fetchInterval
            from: 5
            to: 50
            stepSize: 5
            onValueChanged: {
                Config.options.bar.weather.fetchInterval = value;
            }
        }
    }

    ContentSection {
        icon: "link"
        title: Translation.tr("Related settings")

        Flow {
            Layout.fillWidth: true
            spacing: 8

            RelatedChip {
                pageId: "bar"
                label: Translation.tr("Weather bar widget")
                sectionHighlight: Translation.tr("Widgets")
            }

            RelatedChip {
                pageId: "widgets"
                label: Translation.tr("Desktop weather widget")
            }
        }
    }
}
