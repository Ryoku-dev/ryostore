pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../services"
import "../../modules/common"
import "../../modules/common/widgets"

// Surfaces Config's malformed-JSON / migration / repair events inside
// Settings. Re-shown on every new event even if a previous one was
// dismissed, so a fresh problem is never silently hidden by an old click.
Loader {
    id: root
    Layout.fillWidth: true

    property bool dismissed: false
    readonly property bool severe: Config.configHealthState === "malformed"
    // bannerText guards against a state with no copy rendering as an empty box.
    // A successful schema migration is informational and should not occupy
    // the Settings layout on every load. Keep actionable health states visible.
    active: Config.configHealthState !== "ok"
        && Config.configHealthState !== "migrated"
        && root.bannerText !== ""
        && !root.dismissed
    // An inactive Loader is zero-height but still counts as a ColumnLayout
    // child, so it reserves a spacing slot above the window content. Hiding it
    // drops it out of the layout entirely.
    visible: root.active
    sourceComponent: root.severe ? warningComponent : noticeComponent

    Connections {
        target: Config
        function onConfigHealthStateChanged() {
            root.dismissed = false;
        }
    }

    readonly property string bannerText: {
        const state = Config.configHealthState;
        const keys = Array.from(Config.configHealthKeys ?? []);
        if (state === "malformed")
            return Translation.tr("config.json has invalid JSON syntax. Settings changes won't save until it's fixed — hand-edit the file, or reset it to defaults below.");
        if (state === "recovered")
            return Translation.tr("config.json is valid again — settings will save normally.");
        if (state === "repaired")
            return keys.length === 1 ? Translation.tr("A setting had an invalid value and was reset to default: %1").arg(keys[0]) : Translation.tr("%1 settings had an invalid value and were reset to default: %2").arg(keys.length).arg(keys.join(", "));
        if (state === "unknownKeys")
            return keys.length === 1 ? Translation.tr("An entry in config.json isn't recognized and will be removed the next time settings are saved: %1").arg(keys[0]) : Translation.tr("%1 entries in config.json aren't recognized and will be removed the next time settings are saved: %2").arg(keys.length).arg(keys.join(", "));
        if (state === "reset")
            return Translation.tr("config.json was reset to defaults.");
        return "";
    }

    Component {
        id: warningComponent
        WarningBox {
            Layout.fillWidth: true
            materialIcon: "error"
            text: root.bannerText

            RippleButton {
                Layout.alignment: Qt.AlignRight
                Layout.preferredHeight: 32
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colError
                colBackgroundHover: Appearance.colors.colError
                contentItem: RowLayout {
                    spacing: 6
                    MaterialSymbol {
                        Layout.alignment: Qt.AlignVCenter
                        text: "restart_alt"
                        iconSize: 16
                        color: Appearance.colors.colOnError
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignVCenter
                        text: Translation.tr("Reset to defaults")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnError
                    }
                }
                onClicked: Config.resetConfigToDefaults()
            }

            RippleButton {
                Layout.alignment: Qt.AlignRight
                Layout.preferredHeight: 32
                buttonRadius: Appearance.rounding.full
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colErrorContainer
                contentItem: StyledText {
                    text: Translation.tr("Dismiss")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnErrorContainer
                }
                onClicked: root.dismissed = true
            }
        }
    }

    Component {
        id: noticeComponent
        NoticeBox {
            Layout.fillWidth: true
            materialIcon: "info"
            text: root.bannerText

            RippleButton {
                Layout.alignment: Qt.AlignRight
                Layout.preferredHeight: 32
                buttonRadius: Appearance.rounding.full
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colTertiaryContainer
                contentItem: StyledText {
                    text: Translation.tr("Dismiss")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnTertiaryContainer
                }
                onClicked: root.dismissed = true
            }
        }
    }
}
