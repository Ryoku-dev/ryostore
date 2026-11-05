import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../../../../services"
import "../../../common"
import "../../../common/widgets"

ContentPage {
    id: root
    forceWidth: false
    property bool showBackButton: false
    signal goBack()

    RowLayout {
        visible: root.showBackButton
        spacing: 12

        RippleButton {
            implicitWidth: implicitHeight
            implicitHeight: 40
            topLeftRadius: Appearance.rounding.full
            topRightRadius: Appearance.rounding.full
            bottomLeftRadius: Appearance.rounding.full
            bottomRightRadius: Appearance.rounding.full
            colBackground: Appearance.colors.colSecondaryContainer
            colBackgroundHover: Appearance.colors.colSecondaryContainerHover
            colRipple: Appearance.colors.colSecondaryContainerActive

            MaterialSymbol {
                anchors.centerIn: parent
                text: "arrow_back"
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnSecondaryContainer
            }

            onClicked: root.goBack()
        }

        StyledText {
            text: Translation.tr("Alarm & Audio Controls")
            font.pixelSize: Appearance.font.pixelSize.large
            font.family: Appearance.font.family.title
            color: Appearance.colors.colOnLayer0
        }
    }

    ContentSection {
        icon: "alarm"
        title: Translation.tr("Alarm Ringing & Display")

        ConfigSwitch {
            buttonIcon: "fullscreen"
            text: Translation.tr("Fullscreen ringing popup")
            checked: Config.options.time.alarms.useFullscreenPopup
            onCheckedChanged: {
                Config.options.time.alarms.useFullscreenPopup = checked;
            }
            StyledToolTip {
                text: Translation.tr("Shows a full-screen overlay when an alarm is ringing. If disabled, a notification will be used instead.")
            }
        }

        ConfigSwitch {
            buttonIcon: "pace"
            text: Translation.tr("Show analog clock in popup")
            checked: Config.options.time.alarms.showAnalogClock
            onCheckedChanged: {
                Config.options.time.alarms.showAnalogClock = checked;
            }
            StyledToolTip {
                text: Translation.tr("Show or hide the decorative analog clock in the bar clock widget popup.")
            }
        }

        ConfigSwitch {
            buttonIcon: "public"
            text: Translation.tr("Show world clocks in popup")
            checked: Config.options.time.alarms.showWorldClocks
            onCheckedChanged: {
                Config.options.time.alarms.showWorldClocks = checked;
            }
            StyledToolTip {
                text: Translation.tr("Show or hide the world clocks section in the bar clock widget popup.")
            }
        }

        ConfigSwitch {
            buttonIcon: "notifications_active"
            text: Translation.tr("Show alarms section in popup")
            checked: Config.options.time.alarms.showAlarmsSection
            onCheckedChanged: {
                Config.options.time.alarms.showAlarmsSection = checked;
            }
            StyledToolTip {
                text: Translation.tr("Show or hide the alarms card in the bar clock widget popup.")
            }
        }
    }

}
