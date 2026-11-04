import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../services"
import "../../../modules/common"
import "../../../modules/common/widgets"
import "widgets"

ContentPage {
    id: page
    forceWidth: false

    ContentSection {
        title: Translation.tr("Popups & Behavior")
        icon: "notifications"

        ConfigSpinBox {
            icon: "timer"
            text: Translation.tr("Timeout duration (ms)")
            value: Config.options.notifications.timeout
            from: 1000
            to: 10000
            stepSize: 500
            onValueChanged: {
                Config.options.notifications.timeout = value;
            }
        }

        ConfigSpinBox {
            icon: "zoom_in"
            text: Translation.tr("Notification size (%)")
            value: Config.options.notifications.zoomPercent
            from: 50
            to: 200
            stepSize: 10
            onValueChanged: {
                Config.options.notifications.zoomPercent = value;
            }
        }

        ConfigSwitch {
            buttonIcon: "fullscreen"
            text: Translation.tr("Do not disturb when focused app is fullscreen")
            checked: Config.options.notifications.autoDndFullscreen
            onCheckedChanged: {
                Config.options.notifications.autoDndFullscreen = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "desktop_windows"
            text: Translation.tr("Force specific monitor")
            checked: Config.options.notifications.monitor.enable
            onCheckedChanged: {
                Config.options.notifications.monitor.enable = checked;
            }
        }

        ContentSubsection {
            visible: Config.options.notifications.monitor.enable
            title: Translation.tr("Target monitor")
            icon: "tv"
            Layout.fillWidth: true

            MonitorPicker {
                currentValue: Config.options.notifications.monitor.name
                onSelected: (newValue) => {
                    Config.options.notifications.monitor.name = newValue;
                }
            }
        }
    }

    ContentSection {
        title: Translation.tr("Position")
        icon: "place"

        NotificationPositionPicker {
            Layout.fillWidth: true
        }
    }

    ContentSection {
        title: Translation.tr("Status Bar Indicator")
        icon: "notifications_active"

        ConfigSwitch {
            buttonIcon: "counter_2"
            text: Translation.tr("Show unread count")
            checked: Config.options.bar.indicators.notifications.showUnreadCount
            onCheckedChanged: {
                Config.options.bar.indicators.notifications.showUnreadCount = checked;
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
                pageId: "lockScreen"
                label: Translation.tr("Lock screen")
            }

            RelatedChip {
                pageId: "dock"
                label: Translation.tr("Dock badges")
            }

            RelatedChip {
                pageId: "dynamicIsland"
                label: Translation.tr("Island notch")
            }

            RelatedChip {
                pageId: "soundAlerts"
                label: Translation.tr("Alert sounds")
            }
        }
    }
}
